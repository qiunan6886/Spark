pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// Versions are pinned to what is already in this machine's Gradle cache and is
// proven to build the Rust/cargokit toolchain (Flick uses the same triple).
// flutter create's defaults (Gradle 9.3.1 / AGP 9.1.0 / Kotlin 2.4.0) are not
// cached, so Gradle has to fetch them from plugins-artifacts.gradle.org, which
// fails here with "(certificate_unknown) PKIX path building failed" -- TLS to
// that CDN is not trusted on this network. Staying on cached versions keeps the
// build entirely offline and reproducible.
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.20" apply false
}

include(":app")
