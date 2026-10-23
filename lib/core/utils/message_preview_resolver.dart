import 'dart:convert';
import '../../data/models/message_model.dart';
import 'emoji_shortcode_parser.dart';

/// Helper terpusat untuk memformat cuplikan pesan (preview) di daftar chat,
/// notifikasi, dan widget terkait secara konsisten tanpa duplikasi atau kebocoran JSON payload.
class MessagePreviewResolver {
  /// Ekstensi dokumen standar yang diklasifikasikan sebagai "Dokumen"
  static const Set<String> _recognizedDocExtensions = {
    'pdf',
    'doc', 'docx', 'txt', 'rtf', 'odt',
    'xls', 'xlsx', 'csv', 'ods',
    'ppt', 'pptx', 'odp',
    'zip', 'rar', '7z', 'tar', 'gz',
  };

  /// Memeriksa apakah ekstensi berkas atau payload content dikenali sebagai dokumen standar
  static bool isRecognizedDocument(String? fileNameOrContent) {
    if (fileNameOrContent == null || fileNameOrContent.isEmpty) return false;
    final trimmed = fileNameOrContent.trim();

    // 1. Jika berbentuk JSON payload, coba ekstrak file_name atau caption
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          final fn = decoded['file_name'] as String?;
          if (fn != null && fn.isNotEmpty) {
            return isRecognizedDocument(fn);
          }
          final caption = decoded['caption'] as String?;
          if (caption != null && caption.isNotEmpty) {
            return isRecognizedDocument(caption);
          }
          return false;
        }
      } catch (_) {}
    }

    // 2. Ambil nama berkas dari path/url jika ada slash atau parameter
    String name = trimmed.split('?').first.split('#').first;
    if (name.contains('/')) {
      name = name.split('/').last;
    }
    if (name.contains(r'\')) {
      name = name.split(r'\').last;
    }

    final dotIdx = name.lastIndexOf('.');
    if (dotIdx == -1 || dotIdx == name.length - 1) return false;
    final ext = name.substring(dotIdx + 1).toLowerCase();
    return _recognizedDocExtensions.contains(ext);
  }

  /// Format teks preview pesan untuk daftar percakapan (Chat List & Archived Chats)
  static String formatChatListPreview({
    MessageType? type,
    String? rawMsgType,
    required String? content,
    bool isUnreadFromOther = false,
    bool isStealth = false,
    bool isEncrypted = false,
  }) {
    if (isStealth) return '••••••••';
    if (content == null || content.isEmpty) return 'Mulai percakapan...';

    final trimmed = content.trim();

    // 1. Deteksi dan sanitasi payload media/berkas berbentuk JSON (misal {"key":"...", "file_name":"..."})
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          final fileName = decoded['file_name'] as String?;
          final caption = decoded['caption'] as String?;
          final hasKey = decoded.containsKey('key');

          // Pesan berkas / lampiran dokumen
          if (fileName != null || type == MessageType.file || rawMsgType == 'file') {
            if (isRecognizedDocument(fileName)) {
              return isUnreadFromOther ? '📄 Dokumen baru' : '📄 Dokumen';
            }
            // Jika jenis berkas tidak dikenali (seperti .md, .bin, dll):
            return isUnreadFromOther ? '📎 Berkas baru' : '📎 Berkas';
          }

          // Caption media
          if (caption != null && caption.trim().isNotEmpty) {
            return caption.trim();
          }

          // Media terenkripsi (gambar, video, suara)
          if (hasKey) {
            final effectiveType = type ?? (rawMsgType != null ? _parseMessageType(rawMsgType) : null);
            switch (effectiveType) {
              case MessageType.image:
                return isUnreadFromOther ? '📷 Foto baru' : '📷 Foto';
              case MessageType.video:
                return isUnreadFromOther ? '🎥 Video baru' : '🎥 Video';
              case MessageType.voice:
                return isUnreadFromOther ? '🎤 Pesan suara baru' : '🎤 Pesan Suara';
              case MessageType.file:
                return isUnreadFromOther ? '📎 Berkas baru' : '📎 Berkas';
              default:
                return isUnreadFromOther ? '📎 Berkas baru' : '📎 Berkas';
            }
          }
        }
      } catch (_) {}
    }

    // 2. Evaluasi berdasarkan tipe pesan [MessageType]
    final effectiveType = type ?? (rawMsgType != null ? _parseMessageType(rawMsgType) : null);
    if (effectiveType != null) {
      switch (effectiveType) {
        case MessageType.image:
          return isUnreadFromOther ? '📷 Foto baru' : '📷 Foto';
        case MessageType.video:
          return isUnreadFromOther ? '🎥 Video baru' : '🎥 Video';
        case MessageType.voice:
          return isUnreadFromOther ? '🎤 Pesan suara baru' : '🎤 Pesan Suara';
        case MessageType.location:
          return isUnreadFromOther ? '📍 Lokasi baru' : '📍 Lokasi';
        case MessageType.file:
          final meta = FileAttachmentMeta.fromContent(trimmed);
          if (isRecognizedDocument(meta.fileName)) {
            return isUnreadFromOther ? '📄 Dokumen baru' : '📄 Dokumen';
          }
          return isUnreadFromOther ? '📎 Berkas baru' : '📎 Berkas';
        case MessageType.system:
          return trimmed;
        case MessageType.text:
          break;
      }
    }

    // 3. Fallback pembersihan teks biasa (cegah raw JSON lolos ke UI)
    if (trimmed.startsWith('{"key":')) {
      return isUnreadFromOther ? '📎 Berkas baru' : '📎 Berkas';
    }

    return replaceCustomEmojiTokens(trimmed, (_) => '[emoji]');
  }

  /// Sanitasi cuplikan string yang sudah tersimpan di room['lastMessage']
  static String sanitizeLastMessage(String? rawLastMsg, {bool isStealth = false}) {
    if (isStealth) return '••••••••';
    if (rawLastMsg == null || rawLastMsg.isEmpty) return 'Mulai percakapan...';
    final trimmed = rawLastMsg.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          final fileName = decoded['file_name'] as String?;
          final caption = decoded['caption'] as String?;
          if (fileName != null) {
            if (isRecognizedDocument(fileName)) return '📄 Dokumen';
            return '📎 Berkas';
          }
          if (caption != null && caption.trim().isNotEmpty) {
            return caption.trim();
          }
          if (decoded.containsKey('key')) {
            return '📎 Berkas';
          }
        }
      } catch (_) {
        return '📎 Berkas';
      }
    }
    if (trimmed.startsWith('{"key":')) {
      return '📎 Berkas';
    }
    return replaceCustomEmojiTokens(trimmed, (_) => '[emoji]');
  }

  static MessageType? _parseMessageType(String typeStr) {
    try {
      return MessageType.values.byName(typeStr.toLowerCase());
    } catch (_) {
      return null;
    }
  }
}
