import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de release: android/key.properties (fuera de git) apunta al keystore de subida.
// Sin ese archivo se firma con la clave de depuración, que solo sirve para pruebas.
// Ver docs/publicacion.md.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "co.edu.ucc.mandidog"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
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

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseKey) {
                    signingConfigs.getByName("release")
                } else {
                    logger.warn("android/key.properties no existe: el release se firma con la clave de depuración.")
                    signingConfigs.getByName("debug")
                }
        }
    }
}

// Kotlin 2.4 (requerido por firebase-auth 25) ya no acepta kotlinOptions.jvmTarget.
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
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
