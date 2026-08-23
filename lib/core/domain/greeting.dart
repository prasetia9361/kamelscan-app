/// Ucapan selamat pada bilah atas (Bab 9.1).
///
/// Sengaja **murni Dart tanpa Flutter** agar keempat ambang jamnya dapat diuji
/// tanpa perangkat. Angka batas seperti ini mudah salah ketik satu digit, dan
/// kesalahannya hanya muncul pada jam tertentu — jenis cacat yang tidak akan
/// pernah tertangkap saat mencoba aplikasi di siang hari.
library;

enum Greeting {
  /// 00.00–10.59
  morning,

  /// 11.00–14.59
  afternoon,

  /// 15.00–18.59
  evening,

  /// 19.00–23.59
  night;

  /// Batas menurut Bab 9.1: 00–10 pagi, 11–14 siang, 15–18 sore, 19–23 malam.
  ///
  /// Jam di luar 0..23 tidak mungkin datang dari [DateTime.hour], tetapi tetap
  /// dijatuhkan ke [morning] alih-alih melempar — bilah atas yang mogok karena
  /// jam aneh jauh lebih buruk daripada sapaan yang keliru.
  static Greeting fromHour(int hour) {
    if (hour < 0 || hour > 23) return Greeting.morning;
    if (hour <= 10) return Greeting.morning;
    if (hour <= 14) return Greeting.afternoon;
    if (hour <= 18) return Greeting.evening;
    return Greeting.night;
  }

  /// Mengikuti **jam perangkat**, bukan waktu server.
  ///
  /// Ini satu-satunya tempat jam HP boleh dipakai apa adanya: sapaan mengikuti
  /// pagi-sore yang sedang dialami penggunanya. Bandingkan dengan watermark,
  /// yang justru tidak boleh menyentuh jam HP sama sekali (L.1).
  static Greeting now({DateTime? clock}) =>
      fromHour((clock ?? DateTime.now()).hour);

  /// Kunci l10n. Teksnya diterjemahkan di lapisan UI (Bab 9.11 poin 5).
  String get messageKey => switch (this) {
        Greeting.morning => 'homeGreetingMorning',
        Greeting.afternoon => 'homeGreetingAfternoon',
        Greeting.evening => 'homeGreetingEvening',
        Greeting.night => 'homeGreetingNight',
      };
}
