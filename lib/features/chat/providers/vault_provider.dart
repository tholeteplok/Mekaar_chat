import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/vault_item.dart';
import '../../../data/services/aegis_shredder_service.dart';
import '../../../data/services/aegis_stream_cipher_service.dart';
import '../../../data/services/database_key_service.dart';
import '../../../data/services/local_vault_database.dart';

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  return VaultRepository(LocalVaultDatabase.instance);
});

final vaultFilterProvider = StateProvider<VaultFileType?>((ref) => null);

final vaultItemsProvider =
    StateNotifierProvider<VaultNotifier, AsyncValue<List<VaultItem>>>((ref) {
  final repo = ref.watch(vaultRepositoryProvider);
  final filter = ref.watch(vaultFilterProvider);
  return VaultNotifier(repo, filter);
});

class VaultRepository {
  final LocalVaultDatabase _db;
  final Directory? _customVaultDir;
  static const String _vaultFolder = 'vault_files';

  VaultRepository(this._db, {Directory? vaultDir}) : _customVaultDir = vaultDir;

  /// Mendapatkan direktori privat terisolasi untuk brankas berkas.
  Future<Directory> _getVaultDirectory() async {
    final customDir = _customVaultDir;
    if (customDir != null) {
      if (!await customDir.exists()) {
        await customDir.create(recursive: true);
      }
      return customDir;
    }
    final appDocDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory('${appDocDir.path}/$_vaultFolder');
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }

  /// Menyimpan berkas fisik ke direktori terisolasi brankas dengan enkripsi streaming (Aegis Vault).
  /// Jika kunci slot aktif tersedia, berkas dienkripsi per-chunk 64KB (XChaCha20-Poly1305) menjadi `.aegis`.
  /// Opsional memusnahkan berkas sumber secara forensik (`deleteSource: true`) jika berasal dari cache sementara.
  Future<VaultItem> saveMediaToVault({
    required File sourceFile,
    required String originalMessageId,
    String? customFileName,
    VaultFileType? fileType,
    String? senderName,
    String? senderId,
    String? roomId,
    String? mimeType,
    BigInt? keySlotId,
    bool deleteSource = false,
  }) async {
    if (!await sourceFile.exists()) {
      throw Exception('Berkas sumber tidak ditemukan pada perangkat.');
    }

    final vaultDir = await _getVaultDirectory();
    final rawName = customFileName ??
        sourceFile.path.split(RegExp(r'[/\\]')).last;
    final sanitizedName = rawName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final uniquePrefix = DateTime.now().millisecondsSinceEpoch;

    final effectiveSlotId = keySlotId ?? DatabaseKeyService.instance.activeVaultKeySlotId;
    final String targetPath;
    final int size;

    if (effectiveSlotId != null) {
      // Modus Aman Aegis: Enkripsi Streaming per-chunk 64KB ke wadah biner .aegis
      targetPath = '${vaultDir.path}/${uniquePrefix}_$sanitizedName.aegis';
      final encWritten = await AegisStreamCipherService.instance.encryptFileStream(
        srcPath: sourceFile.path,
        dstPath: targetPath,
        keySlotId: effectiveSlotId,
      );
      size = encWritten.toInt();

      if (deleteSource) {
        try {
          await AegisShredderService.instance.shredFile(sourceFile.path);
        } catch (_) {}
      }
    } else {
      // Modus Fallback: Salin fisik langsung jika belum ada kunci aktif di RAM
      targetPath = '${vaultDir.path}/${uniquePrefix}_$sanitizedName';
      final copiedFile = await sourceFile.copy(targetPath);
      size = await copiedFile.length();
    }

    final resolvedType = fileType ??
        VaultFileType.fromFileNameOrMime(sanitizedName, mimeType: mimeType);

    final item = VaultItem(
      id: const Uuid().v4(),
      originalMessageId: originalMessageId,
      fileName: sanitizedName,
      fileType: resolvedType,
      localPath: targetPath,
      fileSizeBytes: size,
      mimeType: mimeType,
      senderName: senderName,
      senderId: senderId,
      roomId: roomId,
      savedAt: DateTime.now(),
    );

    await _db.insertItem(item);
    return item;
  }

  /// Mendekripsi berkas brankas (.aegis) ke file sementara di sandbox cache untuk ditampilkan.
  /// Jika berkas tidak berakhiran .aegis (file legacy), langsung mengembalikan file fisik aslinya.
  Future<File> getDecryptedMedia(VaultItem item, {BigInt? keySlotId}) async {
    final file = File(item.localPath);
    if (!item.localPath.endsWith('.aegis')) {
      return file;
    }

    final effectiveSlotId = keySlotId ?? DatabaseKeyService.instance.activeVaultKeySlotId;
    if (effectiveSlotId == null) {
      throw StateError('Brankas terkunci: Kunci dekripsi tidak tersedia di memori RAM');
    }

    return await AegisStreamCipherService.instance.decryptToTempFile(
      encryptedPath: item.localPath,
      keySlotId: effectiveSlotId,
      fileExtension: item.fileName.split('.').last,
    );
  }

  /// Mengambil daftar item brankas.
  Future<List<VaultItem>> getVaultItems({
    VaultFileType? filter,
    String? query,
  }) async {
    return await _db.getItems(filter: filter, query: query);
  }

  /// Menghapus item dari database dan menghapus berkas fisik dari storage.
  Future<bool> deleteVaultItem(String id) async {
    final item = await _db.getItemById(id);
    if (item != null) {
      try {
        await AegisShredderService.instance.shredFile(item.localPath);
      } catch (_) {}
    }
    final deletedCount = await _db.deleteItem(id);
    return deletedCount > 0;
  }

  /// Menghitung jumlah berkas di brankas.
  Future<int> countItems({VaultFileType? filter}) async {
    return await _db.countItems(filter: filter);
  }
}

class VaultNotifier extends StateNotifier<AsyncValue<List<VaultItem>>> {
  final VaultRepository _repo;
  final VaultFileType? _filter;
  String _searchQuery = '';

  VaultNotifier(this._repo, this._filter) : super(const AsyncValue.loading()) {
    loadItems();
  }

  Future<void> loadItems({String? query}) async {
    if (query != null) _searchQuery = query;
    state = const AsyncValue.loading();
    try {
      final items = await _repo.getVaultItems(
        filter: _filter,
        query: _searchQuery,
      );
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> deleteItem(String id) async {
    final success = await _repo.deleteVaultItem(id);
    if (success) {
      state.whenData((items) {
        state = AsyncValue.data(items.where((i) => i.id != id).toList());
      });
    }
    return success;
  }

  Future<void> refresh() async {
    await loadItems();
  }
}
