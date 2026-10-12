plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.io.File
import java.util.Properties

val keystoreProperties = Properties()
val keystoreFile = rootProject.file("key.properties")
if (keystoreFile.exists()) {
    keystoreFile.inputStream().use { keystoreProperties.load(it) }
}

// key.properties and the keystore are gitignored. Registering a release signing
// config without them makes AGP abort before any task runs, so only do it when
// the file it points at actually exists.
val hasReleaseSigning =
    keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it).exists() } == true

android {
    namespace = "com.mossapps.spark"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    defaultConfig {
        applicationId = "com.mossapps.spark"
        // cpal/oboe needs API 21+; Flick's feature set settled on 26 and this app
        // inherits that floor.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            // x86 (i686) is deliberately absent: Flutter no longer ships Android x86
            // release artifacts, so requesting it makes AGP ask for an engine jar that
            // does not exist (which stalls resolution) and yields an APK that claims
            // native-code 'x86' while carrying no engine for it. x86_64 covers
            // emulators; the two ARM ABIs cover every real device.
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }

        externalNativeBuild {
            cmake {
                arguments += "-DANDROID_STL=c++_shared"
            }
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            pickFirsts += listOf("**/libc++_shared.so")
        }
    }

    buildTypes {
        release {
            // Without a keystore AGP would fail configuration, so fall back to the
            // debug key. That keeps `flutter build apk --release` producing an
            // installable (debug-signed) APK until android/key.properties exists.
            signingConfig =
                if (hasReleaseSigning) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

// The Rust engine links against the NDK's shared libc++, and rust/.cargo/config.toml
// passes -lc++_shared for every Android target. Nothing ships that library for us, so
// copy it out of the NDK before the packages are assembled.
tasks.register("copyNdkLibs") {
    description = "Copy libc++_shared.so from the Android NDK into jniLibs"
    doLast {
        fun llvmStripFromPath(): String? {
            val executableName =
                if (System.getProperty("os.name").lowercase().contains("win")) {
                    "llvm-strip.exe"
                } else {
                    "llvm-strip"
                }

            return (System.getenv("PATH") ?: "")
                .split(File.pathSeparatorChar)
                .asSequence()
                .map { File(it, executableName) }
                .firstOrNull { it.isFile && it.canExecute() }
                ?.absolutePath
        }

        fun ndkHomeFromLocalProperties(): String? {
            val propsFile = rootProject.file("local.properties")
            if (!propsFile.exists()) return null

            val props = Properties()
            propsFile.inputStream().use { props.load(it) }

            props.getProperty("ndk.dir")?.takeIf { it.isNotBlank() }?.let { return it }

            val sdkDir = props.getProperty("sdk.dir") ?: return null
            val ndkRoot = File(sdkDir, "ndk")
            if (!ndkRoot.exists()) return null

            return ndkRoot.listFiles()
                ?.filter { it.isDirectory }
                ?.maxByOrNull { it.name }
                ?.absolutePath
        }

        val ndkHome =
            System.getenv("ANDROID_NDK_HOME")
                ?: System.getenv("ANDROID_NDK_ROOT")
                ?: ndkHomeFromLocalProperties()
                ?: throw GradleException(
                    "ANDROID_NDK_HOME/ANDROID_NDK_ROOT is not set and no NDK could be resolved from local.properties",
                )

        val abiToArch = mapOf(
            "arm64-v8a" to "aarch64-linux-android",
            "armeabi-v7a" to "arm-linux-androideabi",
            "x86_64" to "x86_64-linux-android",
        )

        val jniLibsDir = project.file("src/main/jniLibs")
        val llvmStrip = llvmStripFromPath()
        val prebuiltRoots = listOf(
            "toolchains/llvm/prebuilt/windows-x86_64",
            "toolchains/llvm/prebuilt/linux-x86_64",
            "toolchains/llvm/prebuilt/darwin-x86_64",
            "toolchains/llvm/prebuilt/darwin-arm64",
        )

        abiToArch.forEach { (abi, arch) ->
            val abiOutDir = File(jniLibsDir, abi)
            abiOutDir.mkdirs()

            val candidates = mutableListOf<File>()
            prebuiltRoots.forEach { root ->
                candidates += File(ndkHome, "$root/sysroot/usr/lib/$arch/libc++_shared.so")
                candidates += File(ndkHome, "$root/sysroot/usr/lib/$abi/libc++_shared.so")
            }
            candidates += File(ndkHome, "sources/cxx-stl/llvm-libc++/libs/$abi/libc++_shared.so")

            val sourceLib = candidates.firstOrNull { it.exists() }
            if (sourceLib != null) {
                val outputLib = File(abiOutDir, "libc++_shared.so")
                sourceLib.copyTo(outputLib, overwrite = true)

                if (llvmStrip != null) {
                    val sizeBeforeBytes = outputLib.length()
                    val stripResult =
                        project.exec {
                            executable = llvmStrip
                            args("--strip-debug", outputLib.absolutePath)
                            isIgnoreExitValue = true
                        }
                    if (stripResult.exitValue == 0) {
                        logger.lifecycle(
                            "Stripped libc++_shared.so for $abi: ${sizeBeforeBytes / 1024} KB -> ${outputLib.length() / 1024} KB",
                        )
                    } else {
                        logger.warn("Warning: failed to strip libc++_shared.so for $abi")
                    }
                } else {
                    logger.warn("Warning: llvm-strip not found on PATH; leaving libc++_shared.so unstripped for $abi")
                }
            } else {
                logger.warn("Warning: libc++_shared.so not found for $abi in NDK $ndkHome")
            }
        }
    }
}

tasks.named("preBuild") {
    dependsOn("copyNdkLibs")
}

dependencies {
    // Storage Access Framework document handling in MainActivity (DocumentFile.fromTreeUri …).
    implementation("androidx.documentfile:documentfile:1.1.0")
    // MediaSessionCompat / PlaybackStateCompat / MediaMetadataCompat for the
    // playback notification, and the media-style NotificationCompat used to build it.
    implementation("androidx.media:media:1.7.0")
}
