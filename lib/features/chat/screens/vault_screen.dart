import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_top_bar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/models/vault_item.dart';
import '../../../data/services/aegis_shredder_service.dart';
import '../../../data/services/database_key_service.dart';
import '../../../data/services/local_vault_database.dart';
import '../providers/vault_provider.dart';

/// Layar antarmuka Brankas Berkas Mekaar.
///
/// Menyediakan tempat penyimpanan rahasia yang terproteksi PIN untuk berkas media,
/// foto, video, rekaman suara, dan dokumen yang disimpan dari percakapan obrolan.
class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final FocusNode _searchFocusNode;
  Timer? _searchDebounceTimer;
  bool _isSearchActive = false;
  String _searchQuery = '';
  AudioPlayer? _audioPlayer;
  String? _currentlyPlayingId;
  bool _isPlayingAudio = false;
  String? _currentTempAudioPath;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        final query = _searchController.text.trim();
        if (query != _searchQuery) {
          setState(() => _searchQuery = query);
          ref.read(vaultItemsProvider.notifier).loadItems(query: query);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchFocusNode.dispose();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    if (_currentTempAudioPath != null) {
      unawaited(AegisShredderService.instance.shredFile(_currentTempAudioPath!));
      _currentTempAudioPath = null;
    }
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    LocalVaultDatabase.instance.close();
    DatabaseKeyService.instance.lockVault();
    super.dispose();
  }

  Future<void> _togglePlayAudio(VaultItem item) async {
    HapticService.trigger(MekaarHapticIntent.selection);
    try {
      _audioPlayer ??= AudioPlayer();

      if (_currentlyPlayingId == item.id && _isPlayingAudio) {
        await _audioPlayer!.pause();
        if (mounted) setState(() => _isPlayingAudio = false);
        return;
      }

      await _audioPlayer!.stop();
      _audioPlayer!.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
            _currentlyPlayingId = null;
          });
        }
      });

      if (_currentTempAudioPath != null && _currentTempAudioPath != item.localPath) {
        unawaited(AegisShredderService.instance.shredFile(_currentTempAudioPath!));
        _currentTempAudioPath = null;
      }

      final repo = ref.read(vaultRepositoryProvider);
      final playFile = await repo.getDecryptedMedia(item);
      if (playFile.path != item.localPath) {
        _currentTempAudioPath = playFile.path;
      }

      await _audioPlayer!.play(DeviceFileSource(playFile.path));
      if (mounted) {
        setState(() {
          _currentlyPlayingId = item.id;
          _isPlayingAudio = true;
        });
      }
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Tidak dapat memutar rekaman suara.');
      }
    }
  }

  Future<void> _openImageViewer(VaultItem item) async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final repo = ref.read(vaultRepositoryProvider);
    final File displayFile;
    try {
      displayFile = await repo.getDecryptedMedia(item);
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal mendekripsi berkas gambar dari brankas.');
      }
      return;
    }

    if (!displayFile.existsSync()) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Berkas fisik sudah tidak ditemukan.');
      }
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              item.fileName,
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              IconButton(
                icon: const Icon(SolarIconsOutline.trashBinTrash),
                tooltip: 'Hapus dari Brankas',
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDeleteItem(item);
                },
              ),
            ],
          ),
          body: Center(
            child: PhotoView(
              imageProvider: FileImage(displayFile),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3.0,
            ),
          ),
        ),
      ),
    );

    // Musnahkan berkas dekripsi sementara setelah penampil ditutup
    if (displayFile.path != item.localPath) {
      unawaited(AegisShredderService.instance.shredFile(displayFile.path));
    }
  }

  void _confirmDeleteItem(VaultItem item) {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Hapus dari Brankas?',
      message:
          'Berkas "${item.fileName}" akan dihapus permanen dari brankas penyimpanan rahasia.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: MekaarColors.sosRed,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            Navigator.pop(context);
            if (_currentlyPlayingId == item.id) {
              await _audioPlayer?.stop();
            }
            final success =
                await ref.read(vaultItemsProvider.notifier).deleteItem(item.id);
            if (!mounted) return;
            if (success) {
              MekaarSnackbar.success(
                context,
                'Berkas berhasil dihapus dari Brankas',
              );
            } else {
              MekaarSnackbar.error(
                context,
                'Gagal menghapus berkas dari Brankas.',
              );
            }
          },
          child: const Text('Hapus'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedFilter = ref.watch(vaultFilterProvider);
    final vaultItemsState = ref.watch(vaultItemsProvider);

    return MekaarScaffold(
      appBar: MekaarTopBar(
        title: 'Brankas Berkas',
        actions: [
          IconButton(
            icon: Icon(
              _isSearchActive
                  ? SolarIconsOutline.closeCircle
                  : SolarIconsOutline.magnifier,
              color: MekaarColors.primaryOf(context),
            ),
            tooltip: _isSearchActive ? 'Tutup Pencarian' : 'Cari Berkas',
            onPressed: () {
              setState(() {
                _isSearchActive = !_isSearchActive;
                if (!_isSearchActive) {
                  _searchDebounceTimer?.cancel();
                  _searchFocusNode.unfocus();
                  _searchController.clear();
                  _searchQuery = '';
                  ref.read(vaultItemsProvider.notifier).loadItems(query: '');
                } else {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _searchFocusNode.canRequestFocus) {
                      _searchFocusNode.requestFocus();
                    }
                  });
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Bar Pencarian jika aktif
          if (_isSearchActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                key: const ValueKey('vault_search_input'),
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari nama berkas atau pengirim...',
                  prefixIcon: const Icon(SolarIconsOutline.magnifier),
                  filled: true,
                  fillColor: MekaarColors.surface2Of(context),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

          // Chips Kategori
          _buildCategoryChips(selectedFilter),

          // Daftar Berkas
          Expanded(
            child: vaultItemsState.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Center(
                child: MekaarStateView(
                  illustration: ErrorResolver.resolveIllustration(e),
                  stateIcon: ErrorResolver.resolveIllustration(e) == null
                      ? ErrorResolver.resolveIcon(e)
                      : null,
                  stateIconColor: ErrorResolver.resolveIconColor(e, context),
                  title: 'Gagal Memuat Brankas',
                  message: ErrorResolver.resolve(e),
                  actionLabel: 'Coba Lagi',
                  onAction: () =>
                      ref.read(vaultItemsProvider.notifier).refresh(),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: MekaarStateView(
                      illustration: _searchQuery.isNotEmpty
                          ? MikaIllustrationType.emptySearch
                          : MikaIllustrationType.emptyVault,
                      title: _searchQuery.isNotEmpty
                          ? 'Berkas Tidak Ditemukan'
                          : 'Brankas Terkunci & Aman',
                      message: _searchQuery.isNotEmpty
                          ? 'Tidak ada berkas yang cocok dengan "$_searchQuery".'
                          : 'Simpan foto, rekaman suara, video, atau dokumen dari obrolan untuk menyimpannya dengan aman di sini.',
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(vaultItemsProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildVaultItemTile(context, item);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(VaultFileType? selectedFilter) {
    final categories = <({String label, VaultFileType? type, IconData icon})>[
      (label: 'Semua', type: null, icon: SolarIconsOutline.folder),
      (label: 'Gambar', type: VaultFileType.image, icon: SolarIconsOutline.gallery),
      (label: 'Video', type: VaultFileType.video, icon: SolarIconsOutline.videocamera),
      (label: 'Audio', type: VaultFileType.audio, icon: SolarIconsOutline.microphone),
      (label: 'Dokumen', type: VaultFileType.document, icon: SolarIconsOutline.document),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: categories.map((cat) {
          final isSelected = selectedFilter == cat.type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                cat.icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : MekaarColors.primaryOf(context),
              ),
              label: Text(cat.label),
              selected: isSelected,
              selectedColor: MekaarColors.primaryOf(context),
              backgroundColor: MekaarColors.surface2Of(context),
              labelStyle: MekaarTypography.caption.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : MekaarColors.textPrimaryOf(context),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? MekaarColors.primaryOf(context)
                      : Colors.transparent,
                ),
              ),
              onSelected: (_) {
                HapticService.trigger(MekaarHapticIntent.selection);
                ref.read(vaultFilterProvider.notifier).state = cat.type;
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVaultItemTile(BuildContext context, VaultItem item) {
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(item.savedAt);
    final isPlayingThis =
        _currentlyPlayingId == item.id && _isPlayingAudio;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CustomCard(
        padding: const EdgeInsets.all(12),
        borderRadius: 16.0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (item.fileType == VaultFileType.image) {
              _openImageViewer(item);
            } else if (item.fileType == VaultFileType.audio) {
              _togglePlayAudio(item);
            } else {
              MekaarSnackbar.info(
                context,
                'Lokasi berkas: ${item.localPath}',
              );
            }
          },
          child: Row(
            children: [
              // Thumbnail / Icon
              _buildItemThumbnail(item, isPlayingThis),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      style: MekaarTypography.bodyMD.copyWith(
                        fontWeight: FontWeight.w600,
                        color: MekaarColors.textPrimaryOf(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.formattedFileSize} • $dateStr',
                      style: MekaarTypography.caption.copyWith(
                        color: MekaarColors.textSecondaryOf(context),
                      ),
                    ),
                    if (item.senderName != null &&
                        item.senderName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Dari: ${item.senderName}',
                        style: MekaarTypography.caption.copyWith(
                          color: MekaarColors.primaryOf(context),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Opsi Menu
              PopupMenuButton<String>(
                icon: Icon(
                  SolarIconsOutline.menuDots,
                  color: MekaarColors.textSecondaryOf(context),
                  size: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                color: MekaarColors.surfaceOf(context),
                onSelected: (val) {
                  if (val == 'open') {
                    if (item.fileType == VaultFileType.image) {
                      _openImageViewer(item);
                    } else if (item.fileType == VaultFileType.audio) {
                      _togglePlayAudio(item);
                    } else {
                      MekaarSnackbar.info(
                        context,
                        'Lokasi: ${item.localPath}',
                      );
                    }
                  } else if (val == 'delete') {
                    _confirmDeleteItem(item);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'open',
                    child: Row(
                      children: [
                        Icon(
                          SolarIconsOutline.eye,
                          color: MekaarColors.primaryOf(context),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        const Text('Buka Berkas'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          SolarIconsOutline.trashBinTrash,
                          color: MekaarColors.sosRed,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Hapus dari Brankas',
                          style: TextStyle(color: MekaarColors.sosRed),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemThumbnail(VaultItem item, bool isPlayingAudio) {
    if (item.fileType == VaultFileType.image && item.existsOnDisk() && !item.localPath.endsWith('.aegis')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(item.localPath),
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) => _buildFallbackIcon(item),
        ),
      );
    }

    if (item.fileType == VaultFileType.audio) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isPlayingAudio
              ? MekaarColors.primaryOf(context)
              : MekaarColors.primaryOf(context).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isPlayingAudio
              ? SolarIconsOutline.pause
              : SolarIconsOutline.play,
          color: isPlayingAudio ? Colors.white : MekaarColors.primaryOf(context),
          size: 24,
        ),
      );
    }

    return _buildFallbackIcon(item);
  }

  Widget _buildFallbackIcon(VaultItem item) {
    IconData icon;
    Color color;

    switch (item.fileType) {
      case VaultFileType.image:
        icon = SolarIconsOutline.gallery;
        color = AppColors.blue;
        break;
      case VaultFileType.video:
        icon = SolarIconsOutline.videocamera;
        color = Colors.purple;
        break;
      case VaultFileType.audio:
        icon = SolarIconsOutline.microphone;
        color = Colors.teal;
        break;
      case VaultFileType.document:
        icon = SolarIconsOutline.document;
        color = Colors.orange;
        break;
      case VaultFileType.other:
        icon = SolarIconsOutline.file;
        color = Colors.grey;
        break;
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }
}
