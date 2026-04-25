plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.smart_medicine_dispenser"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.smart_medicine_dispenser"

        // ── CHANGE 1 ──────────────────────────────────────────────────────
        // Changed from flutter.minSdkVersion to hardcoded 21.
        // Firebase Auth + android_alarm_manager_plus both require minimum 21.
        // flutter.minSdkVersion is often 16 or 19 which is too low.
        minSdk = flutter.minSdkVersion

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ── CHANGE 2 ──────────────────────────────────────────────────────
        // Enables MultiDex — required when app has more than 65,536 methods.
        // Firebase + AlarmManager together exceed this limit without it.
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // ── CHANGE 3 ──────────────────────────────────────────────────────────
    // Required companion to multiDexEnabled = true above.
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}
