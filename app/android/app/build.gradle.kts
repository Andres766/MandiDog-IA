plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "co.edu.ucc.mandidog"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Identificador permanente: está registrado en Firebase y en AI for Pet.
        applicationId = "co.edu.ucc.mandidog"
        // El SDK de AI for Pet requiere Android 9.0 o superior.
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // SDK de AI for Pet. Si cambias la versión, actualiza también AppConfig.aiforpetSdkVersion.
    // Trae sus propias reglas de ProGuard/R8 para las builds de release.
    implementation("io.github.aiforpet-ttcare:scansdk-lib:2.2.3")
}

flutter {
    source = "../.."
}
