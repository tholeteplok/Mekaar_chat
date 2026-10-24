import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../data/repositories/screen_protection_repository.dart';

/// Full-screen image viewer (photo_view) dengan perlindungan tangkapan layar
class FullScreenImageViewer extends StatefulWidget {
  final ImageProvider imageProvider;
  final File? tempFileToPurge;
  final VoidCallback? onSaveToVault;

  const FullScreenImageViewer({
    super.key,
    required this.imageProvider,
    this.tempFileToPurge,
    this.onSaveToVault,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  @override
  void initState() {
    super.initState();
    NativeScreenProtection().setEnabled(true);
  }

  @override
  void dispose() {
    // Catatan: Jangan panggil setEnabled(false) di sini agar tidak mematikan
    // screen protection global milik room obrolan di bawahnya.
    final file = widget.tempFileToPurge;
    if (file != null && file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.onSaveToVault != null)
            IconButton(
              icon: const Icon(SolarIconsOutline.safeSquare),
              tooltip: 'Simpan ke Brankas',
              onPressed: widget.onSaveToVault,
            ),
        ],
      ),
      body: PhotoView(
        imageProvider: widget.imageProvider,
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}
