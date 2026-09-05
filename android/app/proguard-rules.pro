# ---------------------------------------------------------------------------
# Aturan R8 untuk build rilis KamelScan.
#
# R8 menyala lewat `isMinifyEnabled`/`isShrinkResources` di build.gradle.kts.
# Sebagian besar pustaka sudah membawa consumer-rules sendiri; yang ditulis di
# sini hanya yang TIDAK membawanya, atau yang memakai refleksi sehingga R8
# tidak dapat melihat pemakaiannya dari kode.
#
# Bila aplikasi crash HANYA di mode rilis, hampir pasti ada kelas yang ikut
# terbuang di sini. Cara membacanya: jalankan `flutter build apk --release`,
# pasang, ambil stack trace lewat `adb logcat`, lalu de-obfuscate dengan
# build/app/outputs/mapping/release/mapping.txt.
# ---------------------------------------------------------------------------

# --- Flutter engine & entrypoint ------------------------------------------
# Dipanggil dari sisi C++ engine, bukan dari Java/Kotlin, sehingga R8 tidak
# melihat pemakaiannya.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Split-install Play Core hanya dipakai bila aplikasi memakai deferred
# components. Kita tidak memakainya, jadi cukup dibungkam agar R8 tidak
# menggagalkan build karena kelasnya tidak ada di classpath.
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.**

# --- FFmpeg (ffmpeg_kit_flutter_new) --------------------------------------
# Seluruh jembatan JNI-nya dipanggil dari native; nama kelas & method tidak
# boleh berubah.
-keep class com.arthenica.** { *; }
-keep class com.arthenica.ffmpegkit.** { *; }
-dontwarn com.arthenica.**

# --- Google ML Kit (google_mlkit_barcode_scanning) -------------------------
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**
# Model barcode diunduh lewat Play Services; API-nya dipanggil reflektif.
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**

# --- CameraX (camera_android_camerax) --------------------------------------
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# --- flutter_local_notifications -------------------------------------------
# Menyimpan jadwal notifikasi sebagai JSON lewat Gson; kelas modelnya
# di-instansiasi reflektif saat perangkat menyala ulang.
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.models.** { <fields>; }

# --- Gson (dipakai beberapa plugin di atas) --------------------------------
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# --- WorkManager (workmanager) ---------------------------------------------
# Worker di-instansiasi lewat refleksi dari nama kelas yang disimpan di DB.
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.ListenableWorker { public <init>(...); }
-keep class androidx.work.impl.** { *; }
-keep class be.tramckrijte.workmanager.** { *; }
-keep class dev.fluttercommunity.workmanager.** { *; }

# --- Google Sign-In ---------------------------------------------------------
-keep class com.google.android.gms.auth.** { *; }
-dontwarn com.google.android.gms.auth.**

# --- flutter_secure_storage -------------------------------------------------
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# --- image_cropper (uCrop) --------------------------------------------------
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# --- sqlite3 / drift --------------------------------------------------------
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.**

# --- Jaringan (OkHttp/Conscrypt lewat dio & cached_network_image) ----------
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# --- Kotlin coroutines ------------------------------------------------------
-dontwarn kotlinx.coroutines.**
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }

# --- Umum -------------------------------------------------------------------
# Method native tidak boleh di-rename.
-keepclasseswithmembernames class * {
    native <methods>;
}
# Enum dibaca reflektif oleh valueOf() di beberapa plugin.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
# Parcelable CREATOR dibaca reflektif oleh framework.
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
# Nomor baris tetap ada agar stack trace rilis masih bisa dibaca.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
