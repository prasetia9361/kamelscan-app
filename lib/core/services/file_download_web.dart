import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Memicu unduhan berkas di peramban.
///
/// 🔴 Lewat **Blob**, bukan `data:` URI. Chrome memblokir navigasi tingkat atas
/// ke `data:` sejak 2018, sehingga `url_launcher` dengan `data:text/csv,...`
/// tidak melakukan apa pun — tanpa galat, tanpa jendela, tanpa berkas. Gejala
/// yang paling sulit dilaporkan: tombol ditekan dan tidak terjadi apa-apa.
///
/// ⚠️ [isi] dikodekan UTF-8 di sini. Tanda urutan byte (BOM) yang membuat Excel
/// membaca aksen dengan benar sudah menempel di depan [isi] dari `CsvExport`,
/// dan ia ikut terbawa apa adanya — jangan menambahkannya lagi di sini.
void unduhTeks({
  required String namaBerkas,
  required String isi,
  String mime = 'text/csv',
}) {
  final bytes = utf8.encode(isi);

  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: '$mime;charset=utf-8'),
  );

  final url = web.URL.createObjectURL(blob);
  final tautan = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = namaBerkas
    ..style.display = 'none';

  // Harus menempel di dokumen sebelum diklik: Firefox mengabaikan klik pada
  // elemen yang tidak pernah masuk ke pohon DOM.
  web.document.body!.appendChild(tautan);
  tautan.click();
  tautan.remove();

  // 🔴 Tanpa `revokeObjectURL`, setiap ekspor menahan salinan berkasnya di
  // memori tab sampai halamannya ditutup. Pada riwayat besar yang diekspor
  // berulang kali, tabnya membengkak sampai kehabisan memori.
  web.URL.revokeObjectURL(url);
}
