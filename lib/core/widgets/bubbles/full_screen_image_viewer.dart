import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../data/repositories/screen_protection_repository.dart';
import '../../../data/services/aegis_shredder_service.dart';

/// Item foto untuk mode penampil album swipeable pada [FullScreenImageViewer].
class AlbumViewerItem {
  final ImageProvider imageProvider;
  final File? tempFileToPurge;
  final VoidCallback? onSaveToVault;
  final Object? heroTag;
  final String? caption;

  const AlbumViewerItem({
    required this.imageProvider,
    this.tempFileToPurge,
    this.onSaveToVault,
    this.heroTag,
    this.caption,
  });
}

/// Full-screen image viewer (photo_view) dengan perlindungan tangkapan layar,
/// dukungan transisi Hero (heroAttributes), serta mode album swipeable.
class FullScreenImageViewer extends StatefulWidget {
  final List<AlbumViewerItem> items;
  final int initialIndex;

  int get _safeInitialIndex =>
      items.isEmpty ? 0 : initialIndex.clamp(0, items.length - 1);

  ImageProvider get imageProvider => items[_safeInitialIndex].imageProvider;
  File? get tempFileToPurge =>
      items.isNotEmpty ? items[_safeInitialIndex].tempFileToPurge : null;
  VoidCallback? get onSaveToVault =>
      items.isNotEmpty ? items[_safeInitialIndex].onSaveToVault : null;
  Object? get heroTag =>
      items.isNotEmpty ? items[_safeInitialIndex].heroTag : null;

  FullScreenImageViewer({
    super.key,
    required ImageProvider imageProvider,
    File? tempFileToPurge,
    VoidCallback? onSaveToVault,
    Object? heroTag,
    String? caption,
  }) : items = [
         AlbumViewerItem(
           imageProvider: imageProvider,
           tempFileToPurge: tempFileToPurge,
           onSaveToVault: onSaveToVault,
           heroTag: heroTag,
           caption: caption,
         ),
       ],
       initialIndex = 0;

  const FullScreenImageViewer.album({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.items.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    NativeScreenProtection().setEnabled(true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Catatan: Jangan panggil setEnabled(false) di sini agar tidak mematikan
    // screen protection global milik room obrolan di bawahnya.
    for (final item in widget.items) {
      final file = item.tempFileToPurge;
      if (file != null && file.existsSync()) {
        unawaited(AegisShredderService.instance.shredFile(file.path));
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAlbum = widget.items.length > 1;
    final activeItem =
        widget.items.isNotEmpty ? widget.items[_currentIndex] : null;
    final activeCaption = activeItem?.caption?.trim() ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: isAlbum
            ? Text(
                '${_currentIndex + 1} / ${widget.items.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
        actions: [
          if (activeItem?.onSaveToVault != null)
            IconButton(
              icon: const Icon(SolarIconsOutline.safeSquare),
              tooltip: 'Simpan ke Brankas',
              onPressed: activeItem!.onSaveToVault,
            ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return PhotoView(
                imageProvider: item.imageProvider,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                heroAttributes: item.heroTag != null
                    ? PhotoViewHeroAttributes(tag: item.heroTag!)
                    : null,
              );
            },
          ),
          if (activeCaption.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                color: Colors.black.withValues(alpha: 0.65),
                child: SafeArea(
                  top: false,
                  child: Text(
                    activeCaption,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
