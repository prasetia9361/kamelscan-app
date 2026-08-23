import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/session_provider.dart';
import '../../../core/widgets/app_state_views.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/profile_avatar.dart';
import 'edit_profile_view_model.dart';

/// Edit Profil (Bab 9.6 butir 1) — nama, nomor HP, username, dan foto.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _nama = TextEditingController();
  final _hp = TextEditingController();
  final _username = TextEditingController();
  bool _terisi = false;

  EditProfileViewModel get _vm =>
      ref.read(editProfileViewModelProvider.notifier);

  @override
  void dispose() {
    _nama.dispose();
    _hp.dispose();
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final async = ref.watch(editProfileViewModelProvider);

    // Isi awal disalin sekali saja; menyalinnya tiap build akan memindahkan
    // kursor ke awal setiap kali satu huruf diketik.
    final data = async.value;
    if (data != null && !_terisi) {
      _nama.text = data.fullName;
      _hp.text = data.phone;
      _username.text = data.username;
      _terisi = true;
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.accountEditProfile)),
      body: switch (async) {
        AsyncValue(:final value?) => _Form(
            data: value,
            nama: _nama,
            hp: _hp,
            username: _username,
            onNama: _vm.setFullName,
            onHp: _vm.setPhone,
            onUsername: _vm.setUsername,
            onFoto: _pilihFoto,
            onSimpan: _simpan,
          ),
        AsyncError(:final error) => AppErrorView(
            failure: error,
            onRetry: () => ref.invalidate(editProfileViewModelProvider),
          ),
        _ => const AppListSkeleton(itemCount: 3),
      },
    );
  }

  /// Ambil foto, potong menjadi persegi, lalu unggah.
  ///
  /// 🔴 Dipotong dan dikecilkan **di perangkat** sebelum diunggah. Kamera HP
  /// modern menghasilkan berkas 3–5 MB; foto profil yang tampil selebar 44 dp
  /// tidak memerlukan seperseratusnya, dan bucket `avatars` sendiri menolak
  /// berkas di atas 2 MB (migrasi 23).
  Future<void> _pilihFoto(ImageSource source) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: t.accountPhotoCrop,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(title: t.accountPhotoCrop, aspectRatioLockEnabled: true),
      ],
    );
    if (cropped == null) return;

    final Uint8List bytes = await cropped.readAsBytes();
    final failure = await _vm.uploadPhoto(bytes);
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? t.accountPhotoUploaded
              : context.failureMessage(failure),
        ),
      ),
    );
  }

  Future<void> _simpan() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final failure = await _vm.save();
    if (!mounted) return;

    if (failure != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.failureMessage(failure))),
      );
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(t.accountProfileSaved)));
    navigator.pop();
  }
}

class _Form extends ConsumerWidget {
  const _Form({
    required this.data,
    required this.nama,
    required this.hp,
    required this.username,
    required this.onNama,
    required this.onHp,
    required this.onUsername,
    required this.onFoto,
    required this.onSimpan,
  });

  final EditProfileData data;
  final TextEditingController nama;
  final TextEditingController hp;
  final TextEditingController username;
  final ValueChanged<String> onNama;
  final ValueChanged<String> onHp;
  final ValueChanged<String> onUsername;
  final Future<void> Function(ImageSource) onFoto;
  final Future<void> Function() onSimpan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final session = ref.watch(sessionProvider).value;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ProfileAvatar(
                      initials: session?.user.initials ?? '?',
                      seed: session?.user.id ?? '',
                      avatarUrl: data.avatarUrl,
                      size: 104,
                    ),
                    if (data.uploadingPhoto)
                      const Positioned.fill(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      Material(
                        color: Theme.of(context).colorScheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _pilihSumber(context),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.photo_camera_rounded,
                                size: 20, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: nama,
                onChanged: onNama,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: t.accountFieldName,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: hp,
                onChanged: onHp,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: t.accountFieldPhone,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: username,
                onChanged: onUsername,
                decoration: InputDecoration(
                  labelText: t.accountFieldUsername,
                  helperText: t.accountFieldUsernameHelp,
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // Email tidak dapat diubah dari sini — ia identitas login dan
              // penggantiannya menuntut verifikasi ulang (Bab 6). Ditampilkan
              // agar pengguna tidak mencarinya di tempat lain.
              TextField(
                enabled: false,
                controller:
                    TextEditingController(text: session?.user.email ?? ''),
                decoration: InputDecoration(
                  labelText: t.authEmail,
                  helperText: t.accountEmailLocked,
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.mail_outline_rounded),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: data.isBusy ? null : onSimpan,
                child: data.saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(t.commonSave),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pilihSumber(BuildContext context) async {
    final t = context.l10n;

    final sumber = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t.accountPhotoCamera),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t.accountPhotoGallery),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (sumber != null) await onFoto(sumber);
  }
}
