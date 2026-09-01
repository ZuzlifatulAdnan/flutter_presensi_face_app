import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_absensi_app/core/ml/face_engine_provider.dart';
import 'package:flutter_absensi_app/core/theme/app_theme.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/update_user_register_face/update_user_register_face_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/pages/attandences/face_capture_page.dart';

/// Pendaftaran wajah untuk presensi.
///
/// Pengambilan wajah ditangani [FaceCapturePage] sehingga halaman ini tidak
/// menyentuh ML Kit maupun TFLite secara langsung — itu yang membuat seluruh
/// aplikasi tetap bisa dikompilasi untuk web dan desktop.
class RegisterFacePage extends StatefulWidget {
  const RegisterFacePage({super.key});

  @override
  State<RegisterFacePage> createState() => _RegisterFacePageState();
}

class _RegisterFacePageState extends State<RegisterFacePage> {
  Uint8List? _preview;
  List<double>? _embedding;

  bool get _supported => FaceEngineProvider.isSupported;

  Future<void> _capture() async {
    final result = await Navigator.of(context).push<FaceCaptureResult>(
      MaterialPageRoute(
        builder: (_) => const FaceCapturePage(
          mode: FaceCaptureMode.register,
          title: 'Daftarkan Wajah',
        ),
      ),
    );

    if (result == null || !mounted) return;
    if (result.embedding == null || result.embedding!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data wajah gagal dibaca. Silakan ulangi.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() {
      _preview = result.bytes;
      _embedding = result.embedding;
    });
  }

  void _save() {
    final embedding = _embedding;
    if (embedding == null) return;
    context.read<UpdateUserRegisterFaceBloc>().add(
          UpdateUserRegisterFaceEvent.updateProfileRegisterFace(
            FaceEngineProvider.instance.encodeEmbedding(embedding),
            null,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Wajah')),
      body: BlocListener<UpdateUserRegisterFaceBloc,
          UpdateUserRegisterFaceState>(
        listener: (context, state) => state.mapOrNull<void>(
          success: (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Wajah berhasil didaftarkan.'),
                backgroundColor: AppTheme.success,
              ),
            );
            Navigator.of(context).pop(true);
          },
          error: (s) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(s.message),
                backgroundColor: AppTheme.danger,
              ),
            );
          },
        ),
        child: _supported ? _buildContent() : const _UnsupportedNotice(),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _PreviewCard(bytes: _preview),
        const SizedBox(height: 20),
        const _Guidelines(),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _capture,
          icon: const Icon(Icons.camera_alt_rounded),
          label: Text(_preview == null ? 'Ambil Foto Wajah' : 'Ambil Ulang'),
        ),
        const SizedBox(height: 12),
        BlocBuilder<UpdateUserRegisterFaceBloc, UpdateUserRegisterFaceState>(
          builder: (context, state) {
            final saving =
                state.maybeWhen(loading: () => true, orElse: () => false);
            return FilledButton.icon(
              onPressed: _embedding == null || saving ? null : _save,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(saving ? 'Menyimpan...' : 'Simpan Data Wajah'),
            );
          },
        ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final Uint8List? bytes;

  const _PreviewCard({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: AppTheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: bytes == null
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.face_retouching_natural_rounded,
                        size: 64, color: AppTheme.textSecondary),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada foto wajah',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              )
            : Image.memory(bytes!, fit: BoxFit.cover),
      ),
    );
  }
}

class _Guidelines extends StatelessWidget {
  const _Guidelines();

  static const List<String> _tips = [
    'Pastikan wajah terlihat jelas dan pencahayaan cukup.',
    'Lepas masker, kacamata hitam, dan penutup wajah lainnya.',
    'Hadapkan wajah lurus ke kamera, hanya satu orang di dalam frame.',
    'Kedipkan mata saat diminta untuk memastikan Anda hadir langsung.',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tips_and_updates_rounded,
                  size: 18, color: AppTheme.info),
              SizedBox(width: 8),
              Text(
                'Panduan Pengambilan Wajah',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final tip in _tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(height: 1.5)),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UnsupportedNotice extends StatelessWidget {
  const _UnsupportedNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_rounded,
                size: 56, color: AppTheme.textSecondary),
            const SizedBox(height: 14),
            Text(
              FaceEngineProvider.instance.unsupportedReason,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }
}
