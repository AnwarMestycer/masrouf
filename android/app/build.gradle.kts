plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mestycer.masrouf"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications, which uses java.time to
        // schedule. Without it the build fails outright on checkAarMetadata.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.mestycer.masrouf"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Package native libraries only for the ABIs Flutter was asked to build.
        // Flutter's plugin sets abiFilters to every ABI it supports regardless of
        // --target-platform, so plugin libraries (sqlite3, jni, datastore) shipped
        // for armeabi-v7a and x86_64 inside an arm64-only APK. A 32-bit phone
        // would then accept the install and crash on launch for want of
        // libflutter.so. Left alone under --split-per-abi, where filters would
        // conflict with the split configuration.
        val targetAbis = (project.findProperty("target-platform") as String?)
            ?.split(",")
            ?.mapNotNull {
                when (it.trim()) {
                    "android-arm" -> "armeabi-v7a"
                    "android-arm64" -> "arm64-v8a"
                    "android-x64" -> "x86_64"
                    else -> null
                }
            }
            .orEmpty()
        if (targetAbis.isNotEmpty() && project.findProperty("split-per-abi") != "true") {
            ndk {
                abiFilters.clear()
                abiFilters.addAll(targetAbis)
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
