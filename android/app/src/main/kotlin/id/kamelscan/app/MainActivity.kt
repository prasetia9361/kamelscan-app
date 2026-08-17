package id.kamelscan.app

import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Penghitung waktu berjalan untuk watermark (Bab 8.5).
 *
 * `SystemClock.elapsedRealtime()` menghitung milidetik sejak HP menyala,
 * **termasuk saat HP tidur**, dan tidak terpengaruh sama sekali oleh perubahan
 * jam perangkat. Itulah syarat aturan Product Owner 16 Agustus 2026: waktu di
 * watermark tidak boleh dapat digeser dengan mengubah jam HP.
 *
 * 🔴 Kode native ini ada karena jalan tanpa-native sudah dicoba dan **terbukti
 * gagal di perangkat uji**. Rencana semula membaca `/proc/uptime`; pada Redmi
 * Note 9 (MIUI, 17 Agustus 2026) `/proc` dipasang dengan `hidepid=2` dan
 * aplikasi ditolak:
 *
 * ```
 * proc /proc proc rw,relatime,gid=3009,hidepid=2 0 0
 * $ run-as id.kamelscan.app cat /proc/uptime
 * cat: /proc/uptime: Permission denied
 * ```
 *
 * Hanya `/proc/sys/kernel/random/boot_id` yang lolos — itu tetap dipakai Dart
 * sebagai penanda "HP sudah dinyalakan ulang", tetapi angka waktunya harus
 * datang dari sini.
 *
 * ⚠️ Jangan menggantinya dengan `System.currentTimeMillis()`: itu jam dinding
 * yang justru sedang tidak kita percayai.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "id.kamelscan.app/monotonic"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "elapsedRealtime" -> result.success(SystemClock.elapsedRealtime())
                else -> result.notImplemented()
            }
        }
    }
}
