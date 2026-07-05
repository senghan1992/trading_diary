plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // TODO: Replace this placeholder with YOUR reverse-domain Application ID
    // (must match the package name registered in Google Play Console).
    // Example: namespace = "com.yourcompany.tradingdiary"
    // Apple and Google both REJECT `com.example.*` namespace in store submissions.
    namespace = "com.yourcompany.tradingdiary"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Replace this placeholder with the SAME reverse-domain Application ID
        // as the `namespace` above (the two values must stay in sync).
        // Google Play treats this as the unique package identifier and will refuse
        // release builds with `com.example.*`.
        applicationId = "com.yourcompany.tradingdiary"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Production signing setup.
    //
    // To release-build this app:
    //   1. Generate a release keystore, e.g.
    //        keytool -genkey -v -keystore android/app/keystore/trading-diary-release.jks \
    //                -keyalg RSA -keysize 2048 -validity 10000 -alias trading-diary
    //   2. Provide the credentials as Gradle properties or environment vars so
    //      they never enter source control:
    //        ~/.gradle/gradle.properties:
    //          RELEASE_STORE_PASSWORD=...
    //          RELEASE_KEY_ALIAS=trading-diary
    //          RELEASE_KEY_PASSWORD=...
    //        or as environment variables with the same names.
    //   3. Commit this file as-is; the conditional below activates the
    //      production signing config only when the keystore file is present,
    //      so `flutter run --release` keeps working locally.
    signingConfigs {
        create("release") {
            val ksFile = file("keystore/trading-diary-release.jks")
            if (ksFile.exists()) {
                storeFile = ksFile
                storePassword = providers.gradleProperty("RELEASE_STORE_PASSWORD").orNull
                    ?: System.getenv("RELEASE_STORE_PASSWORD")
                keyAlias = providers.gradleProperty("RELEASE_KEY_ALIAS").orNull
                    ?: System.getenv("RELEASE_KEY_ALIAS")
                keyPassword = providers.gradleProperty("RELEASE_KEY_PASSWORD").orNull
                    ?: System.getenv("RELEASE_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (file("keystore/trading-diary-release.jks").exists()) {
                signingConfigs.getByName("release")
            } else {
                // No keystore found — fall back to debug keys so `flutter run
                // --release` continues to work for local testing. Never ship
                // this configuration to the store.
                signingConfigs.getByName("debug")
            }
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
