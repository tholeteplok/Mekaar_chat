import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';

final authRepositoryPrivacyProvider = Provider<AuthRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthRepository(supabaseService);
});

/// Provider untuk mengontrol siapa yang dapat melihat "terakhir dilihat & online".
class LastSeenPrivacyNotifier extends StateNotifier<LastSeenPrivacy> {
  final AuthRepository _repo;
  final Ref _ref;

  LastSeenPrivacyNotifier(this._repo, this._ref)
      : super(_ref.read(authProvider).profile?.lastSeenPrivacy ??
            LastSeenPrivacy.everyone);

  Future<void> setPrivacy(LastSeenPrivacy privacy) async {
    final previous = state;
    state = privacy;
    try {
      final updated = await _repo.updateLastSeenPrivacy(privacy.value);
      final current = _ref.read(authProvider).profile;
      if (current != null) {
        _ref.read(authProvider.notifier).setProfileSilently(
              current.copyWith(lastSeenPrivacy: updated.lastSeenPrivacy),
            );
      }
    } catch (e) {
      state = previous;
      rethrow;
    }
  }
}

final lastSeenPrivacyProvider =
    StateNotifierProvider<LastSeenPrivacyNotifier, LastSeenPrivacy>((ref) {
  final repo = ref.watch(authRepositoryPrivacyProvider);
  return LastSeenPrivacyNotifier(repo, ref);
});

/// Provider untuk mengontrol bukti baca (read receipts).
class ReadReceiptsNotifier extends StateNotifier<bool> {
  final AuthRepository _repo;
  final Ref _ref;

  ReadReceiptsNotifier(this._repo, this._ref)
      : super(_ref.read(authProvider).profile?.readReceiptsEnabled ?? true);

  Future<void> setEnabled(bool enabled) async {
    final previous = state;
    state = enabled;
    try {
      final updated = await _repo.updateReadReceipts(enabled);
      final current = _ref.read(authProvider).profile;
      if (current != null) {
        _ref.read(authProvider.notifier).setProfileSilently(
              current.copyWith(readReceiptsEnabled: updated.readReceiptsEnabled),
            );
      }
    } catch (e) {
      state = previous;
      rethrow;
    }
  }
}

final readReceiptsProvider =
    StateNotifierProvider<ReadReceiptsNotifier, bool>((ref) {
  final repo = ref.watch(authRepositoryPrivacyProvider);
  return ReadReceiptsNotifier(repo, ref);
});

/// Provider untuk mengontrol mode proteksi undangan chat.
class ChatInvitationModeNotifier extends StateNotifier<String> {
  final AuthRepository _repo;
  final Ref _ref;

  ChatInvitationModeNotifier(this._repo, this._ref)
      : super(_ref.read(authProvider).profile?.chatInvitationMode ??
            'approved_only');

  Future<void> setMode(String mode) async {
    final previous = state;
    state = mode;
    try {
      final updated = await _repo.updateChatInvitationMode(mode);
      final current = _ref.read(authProvider).profile;
      if (current != null) {
        _ref.read(authProvider.notifier).setProfileSilently(
              current.copyWith(chatInvitationMode: updated.chatInvitationMode),
            );
      }
    } catch (e) {
      state = previous;
      rethrow;
    }
  }
}

final chatInvitationModeProvider =
    StateNotifierProvider<ChatInvitationModeNotifier, String>((ref) {
  final repo = ref.watch(authRepositoryPrivacyProvider);
  return ChatInvitationModeNotifier(repo, ref);
});

/// Provider untuk mengontrol fitur Sembunyikan Cuplikan Pesan (Stealth Preview).
/// Mengganti cuplikan teks di daftar obrolan dengan titik-titik (••••••••) demi privasi dari intipan orang lain.
class StealthChatPreviewNotifier extends StateNotifier<bool> {
  static const String key = 'stealth_chat_preview';
  final SharedPreferences? _prefs;

  StealthChatPreviewNotifier([this._prefs]) : super(false) {
    if (_prefs != null) {
      state = _prefs.getBool(key) ?? false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(key) ?? false;
  }

  Future<void> toggle() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    state = !state;
    await prefs.setBool(key, state);
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    state = enabled;
    await prefs.setBool(key, enabled);
  }
}

final stealthChatPreviewProvider =
    StateNotifierProvider<StealthChatPreviewNotifier, bool>((ref) {
  return StealthChatPreviewNotifier();
});


/// Provider untuk mengontrol fitur Anti-IP Leak WebRTC (Selalu Reroute Panggilan via Relay).
/// Memaksa WebRTC menggunakan TURN relay server secara eksklusif agar alamat IP asli tidak bocor ke lawan bicara.
class RelayCallsOnlyNotifier extends StateNotifier<bool> {
  static const String key = 'relay_calls_only';
  final SharedPreferences? _prefs;

  RelayCallsOnlyNotifier([this._prefs]) : super(false) {
    if (_prefs != null) {
      state = _prefs.getBool(key) ?? false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(key) ?? false;
  }

  Future<void> toggle() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    state = !state;
    await prefs.setBool(key, state);
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    state = enabled;
    await prefs.setBool(key, enabled);
  }
}

final relayCallsOnlyProvider =
    StateNotifierProvider<RelayCallsOnlyNotifier, bool>((ref) {
  return RelayCallsOnlyNotifier();
});

/// Alias untuk relayCallsOnlyProvider
final relayCallsProvider = relayCallsOnlyProvider;
