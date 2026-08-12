plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "id.kamelscan.app"

    // flutter_secure_storage 11 dan permission_handler_android 13 mewajibkan
    // compile terhadap SDK 37. SDK Platform 37 kini memakai skema versi minor
    // (`AndroidVersion.ApiLevel=37.0`, direktori `platforms/android-37.0`),
    // sehingga `compileSdk = 37` saja akan dicari sebagai `android-37` dan
    // gagal. `compileSdkMinor` melengkapinya menjadi `android-37.0`.
    compileSdk = 37
    compileSdkMinor = 0

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // Diwajibkan oleh flutter_local_notifications: pustakanya memakai API
        // java.time yang baru ada di Android 8+, sedangkan minSdk kita di
        // bawah itu. Desugaring menambal API tersebut ke perangkat lama.
        // Tanpa ini `:app:checkDebugAarMetadata` menolak build.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // 🔴 PERMANEN. Setelah aplikasi terbit di Play Store, nilai ini tidak
        // dapat diubah tanpa kehilangan seluruh pemasangan yang sudah ada.
        // Disetujui Product Owner 12 Agustus 2026.
        applicationId = "id.kamelscan.app"
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Pasangan wajib dari `isCoreLibraryDesugaringEnabled` di atas.
    // Versi 2.1.4 dipilih karena sudah tersedia di cache Gradle lokal,
    // sehingga tidak perlu unduhan baru.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
