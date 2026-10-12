<#
.SYNOPSIS
    Fast Rust-only type check for Spark's Android targets.

.DESCRIPTION
    `flutter build apk` is the authoritative check, but it rebuilds the whole
    Flutter/Gradle pipeline. This runs `cargo check` for one Android target
    with the same environment cargokit would set up, so a Rust error surfaces in
    seconds instead of minutes.

    Two layers of environment are required, and skipping either produces a
    misleading failure from a *dependency's* build script rather than from our
    code:
      * bindgen needs LIBCLANG_PATH plus the per-target clang args, or
        wavpack-sys / opus-sys die on a missing 'sys/types.h'.
      * C dependencies (ring, soundtouch-sys, ...) need the NDK clang/clang++
        wrappers via the cc crate's CC_/CXX_/AR_ variables, or the build fails
        with "failed to find tool clang++.exe".

.PARAMETER Target
    Android Rust target triple. Defaults to x86_64-linux-android (the fastest
    to iterate on and the one the emulator uses).

.EXAMPLE
    pwsh -File tools/rust_check.ps1
#>
[CmdletBinding()]
param(
    [string]$Target = 'x86_64-linux-android',
    [string]$NdkVersion = '28.2.13676358',
    [string]$LlvmBin = 'C:\Program Files\LLVM\bin',
    [string]$LlvmResourceDir = 'C:/Program Files/LLVM/lib/clang/23'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$rustDir = Join-Path $repoRoot 'rust'

$sdkRoot = $env:ANDROID_SDK_ROOT
if (-not $sdkRoot) { $sdkRoot = $env:ANDROID_HOME }
if (-not $sdkRoot) { throw 'ANDROID_SDK_ROOT / ANDROID_HOME is not set.' }

$ndk = Join-Path $sdkRoot "ndk\$NdkVersion"
if (-not (Test-Path $ndk)) { throw "NDK not found: $ndk" }
$tc = Join-Path $ndk 'toolchains\llvm\prebuilt\windows-x86_64\bin'
$sysroot = ($ndk -replace '\\', '/') + '/toolchains/llvm/prebuilt/windows-x86_64/sysroot'

$env:LIBCLANG_PATH = $LlvmBin
$env:ANDROID_NDK_HOME = $ndk

# bindgen: names must be lowercase and paths forward-slashed (bindgen splits the
# value with shlex, and appends the raw target triple to build the lookup key).
$clangArgs = [ordered]@{
    'aarch64_linux_android'   = 'aarch64-linux-android26'
    'armv7_linux_androideabi' = 'armv7-linux-androideabi26'
    'x86_64_linux_android'    = 'x86_64-linux-android26'
    'i686_linux_android'      = 'i686-linux-android26'
}
foreach ($key in $clangArgs.Keys) {
    Set-Item -Path "Env:BINDGEN_EXTRA_CLANG_ARGS_$key" -Value (
        "--target=$($clangArgs[$key]) --sysroot=$sysroot -resource-dir=`"$LlvmResourceDir`""
    )
}

# cc crate toolchain for the single requested target.
# Derived from the triple, e.g. x86_64-linux-android -> x86_64-linux-android26-clang
$arch = $Target -replace '-linux-androideabi$', '-linux-android'
$api = 26
$clangName = if ($Target -eq 'armv7-linux-androideabi') {
    'armv7a-linux-androideabi26-clang'
} else {
    "$arch$api-clang"
}
$clang = Join-Path $tc "$clangName.cmd"
$clangxx = Join-Path $tc "$clangName++.cmd"
$ar = Join-Path $tc 'llvm-ar.exe'

if (-not (Test-Path $clang)) { throw "NDK clang wrapper not found: $clang" }
if (-not (Test-Path $clangxx)) { throw "NDK clang++ wrapper not found: $clangxx" }

$underscored = $Target -replace '-', '_'
foreach ($n in @("CC_$underscored", "CC_$Target")) { Set-Item -Path "Env:$n" -Value $clang }
foreach ($n in @("CXX_$underscored", "CXX_$Target")) { Set-Item -Path "Env:$n" -Value $clangxx }
foreach ($n in @("AR_$underscored", "AR_$Target")) { Set-Item -Path "Env:$n" -Value $ar }
Set-Item -Path "Env:CARGO_TARGET_$(($Target -replace '-', '_').ToUpper())_LINKER" -Value $clang
Set-Item -Path "Env:CFLAGS_$underscored" -Value "--sysroot=$sysroot"
Set-Item -Path "Env:CXXFLAGS_$underscored" -Value "--sysroot=$sysroot -std=c++17"

Write-Host "==> cargo check --target $Target --features uac2" -ForegroundColor Cyan
Push-Location $rustDir
try {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    # cargo writes ordinary progress to stderr; merging it under Stop turns that
    # into a terminating NativeCommandError.
    & cargo check --target $Target --features uac2 2>&1 |
        Where-Object { $_ -match '^error|^warning: unused|-->|^\s+\||^\s+=|error\[' }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $saved
} finally {
    Pop-Location
}

if ($code -eq 0) {
    Write-Host "Rust check passed for $Target." -ForegroundColor Green
} else {
    Write-Host "Rust check FAILED for $Target (exit $code)." -ForegroundColor Red
}
exit $code
