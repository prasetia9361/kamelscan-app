import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/domain/greeting.dart';

/// Bab 9.1 — ucapan pada bilah atas: 00–10 pagi, 11–14 siang, 15–18 sore,
/// 19–23 malam.
///
/// Diuji per jam, bukan per contoh, karena yang mudah salah justru **tepi**
/// tiap rentang — dan salahnya hanya terlihat pada jam tertentu, jenis cacat
/// yang tidak akan tertangkap saat mencoba aplikasi di siang hari.
void main() {
  group('Batas tiap rentang', () {
    test('00 sampai 10 adalah pagi', () {
      for (var h = 0; h <= 10; h++) {
        expect(Greeting.fromHour(h), Greeting.morning, reason: 'jam $h');
      }
    });

    test('11 sampai 14 adalah siang', () {
      for (var h = 11; h <= 14; h++) {
        expect(Greeting.fromHour(h), Greeting.afternoon, reason: 'jam $h');
      }
    });

    test('15 sampai 18 adalah sore', () {
      for (var h = 15; h <= 18; h++) {
        expect(Greeting.fromHour(h), Greeting.evening, reason: 'jam $h');
      }
    });

    test('19 sampai 23 adalah malam', () {
      for (var h = 19; h <= 23; h++) {
        expect(Greeting.fromHour(h), Greeting.night, reason: 'jam $h');
      }
    });
  });

  group('Tepi yang paling mudah tergeser satu jam', () {
    test('jam 10 masih pagi, jam 11 sudah siang', () {
      expect(Greeting.fromHour(10), Greeting.morning);
      expect(Greeting.fromHour(11), Greeting.afternoon);
    });

    test('jam 14 masih siang, jam 15 sudah sore', () {
      expect(Greeting.fromHour(14), Greeting.afternoon);
      expect(Greeting.fromHour(15), Greeting.evening);
    });

    test('jam 18 masih sore, jam 19 sudah malam', () {
      expect(Greeting.fromHour(18), Greeting.evening);
      expect(Greeting.fromHour(19), Greeting.night);
    });

    test('tengah malam kembali ke pagi', () {
      expect(Greeting.fromHour(23), Greeting.night);
      expect(Greeting.fromHour(0), Greeting.morning);
    });
  });

  group('Jam yang mustahil tidak boleh membuat bilah atas mogok', () {
    test('nilai di luar 0..23 jatuh ke pagi, bukan melempar', () {
      expect(Greeting.fromHour(-1), Greeting.morning);
      expect(Greeting.fromHour(24), Greeting.morning);
      expect(Greeting.fromHour(99), Greeting.morning);
    });
  });

  group('now() membaca jam yang diberikan', () {
    test('memakai jam dari clock yang disuntikkan', () {
      expect(
        Greeting.now(clock: DateTime(2026, 8, 18, 20, 30)),
        Greeting.night,
      );
      expect(
        Greeting.now(clock: DateTime(2026, 8, 18, 7)),
        Greeting.morning,
      );
    });
  });

  group('Kunci l10n', () {
    test('setiap rentang punya kunci yang berbeda', () {
      final keys = Greeting.values.map((g) => g.messageKey).toSet();
      expect(keys.length, Greeting.values.length);
      expect(keys, contains('homeGreetingMorning'));
      expect(keys, contains('homeGreetingNight'));
    });
  });
}
