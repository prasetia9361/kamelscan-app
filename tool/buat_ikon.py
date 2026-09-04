# -*- coding: utf-8 -*-
"""Ikon aplikasi KamelScan dari mark desainer.

Sumbernya `landing/img/icon-512.png` — mark yang sama yang sudah dipakai
landing page, jadi ikon aplikasi dan halaman depan tidak pernah berbeda.

🔴 Marknya berlatar TRANSPARAN dan menyentuh tepi kanvas. Keduanya harus
ditangani, dan masing-masing punya aturan sendiri:

  - Latar transparan pada ikon peluncur Android digambar hitam oleh sebagian
    peluncur dan putih oleh sebagian yang lain. Karena itu latarnya dipatok.
  - Seni yang menyentuh tepi akan TERPOTONG pada ikon adaptif: Android
    memotongnya jadi lingkaran, kotak bulat, atau bentuk lain sesuai peluncur.
    Yang dijamin selamat hanya lingkaran 66dp di tengah kanvas 108dp.
"""
import os
from PIL import Image, ImageDraw

SUMBER = 'landing/img/icon-512.png'
PUTIH = (255, 255, 255, 255)

seni = Image.open(SUMBER).convert('RGBA')


def rapatkan(im):
    """Membuang pinggiran transparan supaya penskalaan terukur dari seninya."""
    kotak = im.getbbox()
    return im.crop(kotak) if kotak else im


SENI = rapatkan(seni)


def tempel(kanvas_px, porsi, latar=None, bulat=0):
    """Satu ikon: seni diskalakan ke [porsi] dari kanvas, di tengah.

    [latar] None berarti transparan. [bulat] radius sudut dalam piksel.
    """
    im = Image.new('RGBA', (kanvas_px, kanvas_px), (0, 0, 0, 0))

    if latar is not None:
        alas = Image.new('RGBA', (kanvas_px, kanvas_px), latar)
        if bulat:
            topeng = Image.new('L', (kanvas_px, kanvas_px), 0)
            ImageDraw.Draw(topeng).rounded_rectangle(
                [0, 0, kanvas_px - 1, kanvas_px - 1], radius=bulat, fill=255)
            im.paste(alas, (0, 0), topeng)
        else:
            im.paste(alas, (0, 0))

    muat = int(kanvas_px * porsi)
    w, h = SENI.size
    skala = min(muat / w, muat / h)
    baru = SENI.resize((max(1, int(w * skala)), max(1, int(h * skala))),
                       Image.LANCZOS)
    im.alpha_composite(baru, ((kanvas_px - baru.width) // 2,
                              (kanvas_px - baru.height) // 2))
    return im


def simpan(im, jalur, buang_alpha=False):
    os.makedirs(os.path.dirname(jalur), exist_ok=True)
    if buang_alpha:
        # 🔴 iOS MENOLAK ikon bersaluran alpha. App Store menolaknya saat
        # unggah, bukan saat membangun — kegagalan yang datang paling akhir.
        alas = Image.new('RGB', im.size, (255, 255, 255))
        alas.paste(im, (0, 0), im)
        alas.save(jalur, 'PNG')
    else:
        im.save(jalur, 'PNG')
    print('  %-62s %dx%d' % (jalur, im.width, im.height))


# =====================================================================
# Android — ikon warisan (API < 26)
# =====================================================================
# Sudahnya dibulatkan sendiri karena Android lama TIDAK memberi topeng apa
# pun; kotak putih bersudut tajam terlihat seperti ikon yang belum jadi.
print('Android warisan (ic_launcher.png):')
for folder, px in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                   ('xxhdpi', 144), ('xxxhdpi', 192)]:
    simpan(tempel(px, 0.74, latar=PUTIH, bulat=int(px * 0.22)),
           'android/app/src/main/res/mipmap-%s/ic_launcher.png' % folder)

# =====================================================================
# Android — ikon adaptif (API 26+)
# =====================================================================
# ⚠️ Porsinya 0.52, jauh lebih kecil daripada yang terasa benar saat melihat
# berkasnya sendiri — dan angkanya DIUKUR, bukan dikira-kira.
#
# 🔴 Percobaan pertama memakai 0.56 dengan alasan "zona amannya 66 dari 108dp,
# jadi 61% aman". Alasan itu salah: 61% berlaku untuk PANJANG SISI, sedangkan
# yang memotong adalah LINGKARAN. Seni selebar 60dp masih punya sudut yang
# berjarak 40dp dari pusat, dan lingkarannya hanya berjari-jari 36dp.
#
# Terlihat saat mensimulasikan pemotongannya: ujung centang terpotong rapi
# sekali, dan tanpa disimulasikan tidak akan ketahuan sampai ikonnya terpasang
# di HP.
#
# Angka di bawah dihitung dari piksel buram terjauh mark ini (323,7 px dari
# pusat pada kanvas 512x415): porsi <= (36/108) x 512 / 323,7 = 0,527.
print('Android adaptif (ic_launcher_foreground.png):')
for folder, px in [('mdpi', 108), ('hdpi', 162), ('xhdpi', 216),
                   ('xxhdpi', 324), ('xxxhdpi', 432)]:
    simpan(tempel(px, 0.52),
           'android/app/src/main/res/mipmap-%s/ic_launcher_foreground.png'
           % folder)

# =====================================================================
# Web — favicon & PWA
# =====================================================================
print('Web:')
# Favicon lama 16x16 dan sudah kabur pada layar rapat.
simpan(tempel(32, 0.92), 'web/favicon.png')
for px in (192, 512):
    simpan(tempel(px, 0.88), 'web/icons/Icon-%d.png' % px)
# ⚠️ Maskable dipotong peluncur dengan aturan yang sama, jadi porsinya ikut
# memakai angka terukur itu dan latarnya wajib rata — bukan transparan.
for px in (192, 512):
    simpan(tempel(px, 0.52, latar=PUTIH), 'web/icons/Icon-maskable-%d.png' % px)

# =====================================================================
# iOS — belum dirilis, tetapi berkasnya sudah ada di repositori
# =====================================================================
print('iOS:')
ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for nama, px in [
    ('Icon-App-20x20@1x', 20), ('Icon-App-20x20@2x', 40),
    ('Icon-App-20x20@3x', 60), ('Icon-App-29x29@1x', 29),
    ('Icon-App-29x29@2x', 58), ('Icon-App-29x29@3x', 87),
    ('Icon-App-40x40@1x', 40), ('Icon-App-40x40@2x', 80),
    ('Icon-App-40x40@3x', 120), ('Icon-App-60x60@2x', 120),
    ('Icon-App-60x60@3x', 180), ('Icon-App-76x76@1x', 76),
    ('Icon-App-76x76@2x', 152), ('Icon-App-83.5x83.5@2x', 167),
    ('Icon-App-1024x1024@1x', 1024),
]:
    simpan(tempel(px, 0.82, latar=PUTIH), '%s/%s.png' % (ios, nama),
           buang_alpha=True)

print('\nSelesai.')
