allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// ---------------------------------------------------------------------------
// Naikkan paksa versi bahasa Kotlin pada plugin pihak ketiga.
//
// Sebagian plugin (terpantau: sentry_flutter) masih menyetel
// languageVersion/apiVersion = 1.6 demi kompatibilitas mundur. Kotlin 2.3.20
// yang dipakai proyek ini menolaknya:
//
//   e: Language version 1.6 is no longer supported; use version 2.0 or greater
//
// Ini murni masalah plugin, bukan kode kita, dan tidak bisa diperbaiki dari
// pubspec.
//
// ⚠️ Nilainya HARUS 2.0, jangan dinaikkan ke 2.1. Sudah dicoba dan gagal:
// pada apiVersion 2.1 penghentian `String.toUpperCase(Locale)` di stdlib naik
// status dari peringatan menjadi ERROR, sehingga `sentry_flutter` — yang masih
// memakainya di SentryFlutter.kt — tidak bisa dikompilasi sama sekali.
// Sebaliknya, 2.0 memang memunculkan peringatan "Language version 2.0 is
// deprecated", tetapi tetap berhasil dikompilasi. Peringatan lebih baik
// daripada build gagal.
//
// Batasan ini bisa dicabut begitu sentry_flutter naik ke versi yang tidak lagi
// memakai API usang tersebut.
//
// Hanya berlaku untuk subproyek plugin — modul :app tetap memakai versi bahasa
// bawaan Kotlin yang terpasang.
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Naikkan compileSdk plugin pihak ketiga yang tertinggal.
//
// Beberapa plugin memakukan compileSdk-nya sendiri pada versi lama (terpantau:
// sentry_flutter di 34), sementara plugin lain menuntut konsumennya dikompilasi
// terhadap 36 ke atas (terpantau: package_info_plus). Akibatnya
// `:sentry_flutter:checkDebugAarMetadata` gagal:
//
//   Dependency ':package_info_plus' requires ... version 36 or later
//   :sentry_flutter is currently compiled against android-34
//
// Dipakai 36, bukan 37: direktori `platforms/android-36` ada apa adanya,
// sedangkan 37 hanya tersedia sebagai `android-37.0` sehingga butuh
// `compileSdkMinor` — dan itu hanya disetel pada modul :app yang memang
// membutuhkannya. Menaikkan compileSdk aman: sifatnya mundur-kompatibel dan
// tidak mengubah minSdk maupun targetSdk.
// ---------------------------------------------------------------------------
subprojects {
    if (project.name == "app") return@subprojects

    project.afterEvaluate {
        val android = project.extensions
            .findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?: return@afterEvaluate

        val current = android.compileSdk
        if (current != null && current < 36) {
            android.compileSdk = 36
        }
    }
}

subprojects {
    if (project.name == "app") return@subprojects

    project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
        .configureEach {
            compilerOptions {
                languageVersion.set(
                    org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0,
                )
                apiVersion.set(
                    org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0,
                )
            }
        }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
