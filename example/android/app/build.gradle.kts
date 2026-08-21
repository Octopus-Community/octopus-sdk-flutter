plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Reads google-services.json and generates the Firebase init resources.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.octopuscommunity.sdk.flutter.sample"
    compileSdk = flutter.compileSdkVersion
    // Pinned to Flutter 3.44.5's default (what `flutter.ndkVersion` resolves to:
    // 28.2.13676358), instead of tracking `flutter.ndkVersion` directly. The
    // self-hosted CI runners don't auto-provision NDKs, and when the matching
    // strip tool is missing AGP silently skips stripping debug symbols instead
    // of failing — which then makes `flutter build appbundle --release` fail
    // with "Release app bundle failed to strip debug symbols from native
    // libraries." main.yml installs this exact version when it's missing.
    // Keep this in sync with `flutter.ndkVersion` when upgrading Flutter.
    ndkVersion = "28.2.13676358"

    compileOptions {
        // Required by flutter_local_notifications (used to render Octopus pushes).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.octopuscommunity.sdk.flutter.sample"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing reads from environment variables so CI (main.yml) can inject a real
    // keystore without committing one. KEYSTORE_FILE is an absolute path to a decoded
    // keystore (CI: base64-decoded from the KEYSTORE_BASE64 secret into a temp file).
    // Locally none of these are set, so `release` falls back to the debug signing config
    // below — this is what keeps `flutter run --release` / local release builds working.
    val keystoreFile = System.getenv("KEYSTORE_FILE")

    signingConfigs {
        if (keystoreFile != null) {
            create("release") {
                storeFile = file(keystoreFile)
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEYSTORE_KEY_ALIAS")
                keyPassword = System.getenv("KEYSTORE_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Real signing only when CI (or a developer) exported the env vars above;
            // otherwise sign with the debug keys, same as the original Flutter template.
            signingConfig = if (keystoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring runtime — required by flutter_local_notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
