import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/utils/validators.dart';

void main() {
  group('normalizeEmail — celah uji coba gratis (Bab 7.5)', () {
    test('membuang alias setelah + pada semua domain', () {
      expect(
        Validators.normalizeEmail('budi+toko1@contoh.co.id'),
        'budi@contoh.co.id',
      );
    });

    test('membuang titik dan alias pada gmail', () {
      expect(
        Validators.normalizeEmail('bu.di+shopee@gmail.com'),
        'budi@gmail.com',
      );
    });

    test('googlemail.com disamakan dengan gmail.com', () {
      expect(
        Validators.normalizeEmail('Bu.Di@googlemail.com'),
        'budi@gmail.com',
      );
    });

    test('titik pada domain non-gmail dipertahankan', () {
      expect(
        Validators.normalizeEmail('bu.di@outlook.com'),
        'bu.di@outlook.com',
      );
    });
  });

  group('normalizePhone', () {
    test('0 di depan diubah menjadi 62', () {
      expect(Validators.normalizePhone('0812-3456-7890'), '6281234567890');
    });

    test('+62 dipertahankan tanpa tanda plus', () {
      expect(Validators.normalizePhone('+62 812 3456 7890'), '6281234567890');
    });
  });

  group('resiCode — aturan Bab 8.3.1', () {
    test('menerima resi alfanumerik dengan tanda hubung', () {
      expect(Validators.resiCode('SPX-1234567890'), isNull);
    });

    test('menerima tanda garis miring', () {
      expect(Validators.resiCode('JX/0099887766'), isNull);
    });

    test('menolak URL dengan pesan khusus', () {
      expect(
        Validators.resiCode('https://shopee.co.id/track?no=SPX123'),
        'validationResiNotACode',
      );
    });

    test('menolak resi lebih pendek dari 6 karakter', () {
      expect(Validators.resiCode('AB12'), 'validationResiInvalid');
    });

    test('menolak resi lebih panjang dari 50 karakter', () {
      expect(Validators.resiCode('A' * 51), 'validationResiInvalid');
    });

    test('spasi dan baris baru dari scanner dibuang', () {
      expect(Validators.normalizeResi(' spx 1234\n5678 '), 'SPX12345678');
    });
  });

  group('password', () {
    test('menolak di bawah 8 karakter', () {
      expect(Validators.password('Abc123'), 'validationPasswordTooShort');
    });

    test('menolak tanpa angka', () {
      expect(Validators.password('abcdefgh'), 'validationPasswordWeak');
    });

    test('menerima huruf + angka minimal 8 karakter', () {
      expect(Validators.password('kamel2026'), isNull);
    });
  });

  group('username — chk_username_format (Bab 5.2)', () {
    test('menerima huruf kecil, angka, titik, garis bawah', () {
      expect(Validators.username('budi.pack_01'), isNull);
    });

    test('menolak huruf besar', () {
      expect(Validators.username('BudiPack'), 'validationUsernameInvalid');
    });

    test('kosong diperbolehkan bila tidak wajib', () {
      expect(Validators.username(''), isNull);
    });
  });
}
