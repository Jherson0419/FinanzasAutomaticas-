plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Nota (Fase 27): a propósito NO se tocó — cambiarlo exige mover
    // `android/app/src/main/kotlin/com/finanzasautomaticas/finanzas_automaticas/
    // MainActivity.kt` a un directorio que calce con el nuevo namespace (si no,
    // `android:name=".MainActivity"` del manifest deja de resolver), el mismo
    // tipo de renombre de paquete interno que el encargo pidió evitar para
    // Dart. `applicationId` (abajo) es el identificador de cara a la Play
    // Store/el dispositivo — ese sí se actualizó.
    namespace = "com.finanzasautomaticas.finanzas_automaticas"
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
        applicationId = "com.finzoapp.movil"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
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

flutter {
    source = "../.."
}
