<#
.SYNOPSIS
    Build a release APK for Flick on Windows, with the Android/Rust toolchain wired up.

.DESCRIPTION
    Wraps `flutter build apk --release` with the environment the Android build needs
    on Windows. These settings cannot live in gradle.properties or in Flutter's global
    config, because Gradle and cargokit read them as process environment variables.

    What it sets, and why (details in docs/WINDOWS_BUILD.md):

      LIBCLANG_PATH              bindgen shells out to libclang; the Android NDK does
                                 not ship libclang.dll, so a standalone LLVM is needed.
      ANDROID_NDK_HOME           consumed by the copyNdkLibs task in
                                 android/app/build.gradle.kts.
      BINDGEN_EXTRA_CLANG_ARGS_* Without these, bindgen parses the C headers against
                                 the Windows host and dies on 'sys/types.h' not found.
                                 Names must be lowercase and paths forward-slashed,
                                 because bindgen splits the value with shlex.
      FLUTTER_STORAGE_BASE_URL   Where Gradle fetches the Flutter engine artifacts.

    After the build it verifies the two things that fail silently:
      1. The Rust engine .so is actually inside the APK. cargokit's run_build_tool.cmd
         does not propagate the build tool's exit code, so Gradle happily packages an
         APK with no librust_lib_flick_player.so -- an app that crashes the moment Dart
         calls into Rust.
      2. The APK is signed. Without android/key.properties the release build is left
         unsigned and cannot be installed.

.PARAMETER StorageBaseUrl
    Base URL for Flutter engine artifacts. Defaults to the official
    https://storage.googleapis.com.

    Do NOT point this at a third-party mirror unless you have to. This variable
    replaces the whole `download.flutter.io` Maven repository, not just the engine
    jars, so it is also consulted for coordinates it does not host. The official
    host answers 404 for those, and Gradle moves on to google()/mavenCentral().
    The Flutter China mirror answered 525 (Origin SSL Handshake Error) for
    androidx.test:runner's maven-metadata.xml, which Gradle treats as a hard
    failure, breaking dependency resolution outright.

.PARAMETER ChinaMirror
    Opt in to https://storage.flutter-io.cn for the engine artifacts. Useful only to
    seed the Gradle cache when the Google route stalls on the large ABI jars, which
    it did here (24 minutes with zero bytes transferred). Once the jars are cached,
    switch back to the default.

.PARAMETER SkipVerify
    Skip the post-build APK inspection.

.EXAMPLE
    pwsh -File tools/build_apk.ps1

.EXAMPLE
    pwsh -File tools/build_apk.ps1 -ChinaMirror
#>
[CmdletBinding()]
param(
    [string]$StorageBaseUrl = 'https://storage.googleapis.com',
    [switch]$ChinaMirror,
    [string]$NdkVersion = '28.2.13676358',
    [string]$LlvmBin = 'C:\Program Files\LLVM\bin',
    [string]$LlvmResourceDir = 'C:/Program Files/LLVM/lib/clang/23',
    [switch]$SkipVerify
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
if ($ChinaMirror) { $StorageBaseUrl = 'https://storage.flutter-io.cn' }

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

# ---------------------------------------------------------------- prerequisites

Write-Step "Resolving Android SDK and NDK"

$sdkRoot = $env:ANDROID_SDK_ROOT
if (-not $sdkRoot) { $sdkRoot = $env:ANDROID_HOME }
if (-not $sdkRoot) {
    $localProps = Join-Path $repoRoot 'android\local.properties'
    if (Test-Path $localProps) {
        $sdkRoot = (Get-Content $localProps |
            Where-Object { $_ -match '^sdk\.dir=' } |
            Select-Object -First 1) -replace '^sdk\.dir=', '' -replace '\\\\', '\'
    }
}
if (-not $sdkRoot -or -not (Test-Path $sdkRoot)) {
    throw "Android SDK not found. Set ANDROID_SDK_ROOT or android/local.properties sdk.dir."
}
Write-Host "    SDK : $sdkRoot"

$ndkHome = Join-Path $sdkRoot "ndk\$NdkVersion"
if (-not (Test-Path $ndkHome)) {
    $available = (Get-ChildItem (Join-Path $sdkRoot 'ndk') -Directory -ErrorAction SilentlyContinue).Name -join ', '
    throw "NDK $NdkVersion not found under $sdkRoot\ndk. Available: $available"
}
Write-Host "    NDK : $ndkHome"

$libclang = Join-Path $LlvmBin 'libclang.dll'
if (-not (Test-Path $libclang)) {
    throw "libclang.dll not found at $libclang. Install LLVM and/or pass -LlvmBin."
}
if (-not (Test-Path (Join-Path $LlvmResourceDir 'include'))) {
    throw "-LlvmResourceDir must be the directory CONTAINING include\, got: $LlvmResourceDir"
}

$sysroot = ($ndkHome -replace '\\', '/') + '/toolchains/llvm/prebuilt/windows-x86_64/sysroot'
if (-not (Test-Path ($sysroot -replace '/', '\'))) {
    throw "NDK sysroot not found: $sysroot"
}

# ------------------------------------------------------------------- environment

Write-Step "Configuring build environment"

$env:LIBCLANG_PATH = $LlvmBin
$env:ANDROID_NDK_HOME = $ndkHome
$env:FLUTTER_STORAGE_BASE_URL = $StorageBaseUrl

# Lowercase variable names and forward slashes are both load-bearing: bindgen appends
# the raw target triple to build the lookup key, and parses the value with shlex.
$bindgenTargets = [ordered]@{
    'aarch64_linux_android'   = 'aarch64-linux-android26'
    'armv7_linux_androideabi' = 'armv7-linux-androideabi26'
    'x86_64_linux_android'    = 'x86_64-linux-android26'
    'i686_linux_android'      = 'i686-linux-android26'
}
foreach ($key in $bindgenTargets.Keys) {
    $name = "BINDGEN_EXTRA_CLANG_ARGS_$key"
    Set-Item -Path "Env:$name" -Value (
        "--target=$($bindgenTargets[$key]) --sysroot=$sysroot -resource-dir=`"$LlvmResourceDir`""
    )
    Write-Host "    $name"
}
Write-Host "    LIBCLANG_PATH              = $LlvmBin"
Write-Host "    ANDROID_NDK_HOME           = $ndkHome"
Write-Host "    FLUTTER_STORAGE_BASE_URL   = $StorageBaseUrl"

$keyProps = Join-Path $repoRoot 'android\key.properties'
if (Test-Path $keyProps) {
    Write-Host "    signing                    key.properties found" -ForegroundColor Green
} else {
    Write-Warning "android/key.properties is missing - the release APK will be UNSIGNED and cannot be installed."
}

# ------------------------------------------------------------------------- build

Write-Step "Building release APK"

$logPath = Join-Path $repoRoot 'build-apk.log'
Push-Location $repoRoot
# flutter writes ordinary progress/warning text to stderr. Merging it into the success
# stream under ErrorActionPreference=Stop turns that into a terminating
# NativeCommandError, so relax the preference for the duration of the call and rely on
# the exit code instead.
$savedPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    & flutter build apk --release 2>&1 | Tee-Object -FilePath $logPath
    $buildExit = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $savedPreference
    Pop-Location
}

if ($buildExit -ne 0) {
    Write-Host ""
    Write-Error "flutter build apk failed with exit code $buildExit. Full log: $logPath"
    exit $buildExit
}

# ---------------------------------------------------------------------- verify

if ($SkipVerify) { exit 0 }

Write-Step "Verifying APK"

$apk = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) { throw "Expected APK not found: $apk" }

Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::OpenRead($apk)
try {
    $engineLibs = @($zip.Entries | Where-Object {
        $_.FullName -like 'lib/*/librust_lib_flick_player.so'
    })
} finally {
    $zip.Dispose()
}

if ($engineLibs.Count -eq 0) {
    Write-Host ""
    Write-Error @"
The APK contains NO librust_lib_flick_player.so.
cargokit does not propagate the Rust build's exit code, so Gradle reported success
while packaging an APK that will crash as soon as Dart calls into Rust.
Scroll up in $logPath for the real cargo error.
"@
    exit 1
}

Write-Host "    Rust engine present in $($engineLibs.Count) ABI(s):" -ForegroundColor Green
foreach ($entry in ($engineLibs | Sort-Object FullName)) {
    Write-Host ("      {0,-52} {1,8:N1} KB" -f $entry.FullName, ($entry.Length / 1KB))
}

$sizeMb = [math]::Round((Get-Item $apk).Length / 1MB, 2)
$sha256 = (Get-FileHash $apk -Algorithm SHA256).Hash

$apksigner = Join-Path $sdkRoot 'build-tools\36.0.0\apksigner.bat'
$signed = $false
if (Test-Path $apksigner) {
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $apksigner verify $apk *> $null
        $signed = ($LASTEXITCODE -eq 0)
    } finally {
        $ErrorActionPreference = $savedPreference
    }
}

Write-Host ""
Write-Host "APK     : $apk"
Write-Host "Size    : $sizeMb MB"
Write-Host "SHA-256 : $sha256"
if ($signed) {
    Write-Host "Signed  : yes" -ForegroundColor Green
} else {
    Write-Host "Signed  : NO - not installable" -ForegroundColor Red
}
