import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../../data/models/nearby_friend_model.dart';
import '../../../data/repositories/nearby_repository.dart';
import '../../../data/services/location_service.dart';

class NearbyFriendsState {
  final bool isEnabled;
  final String visibilityMode; // 'contacts_only' or 'everyone'
  final bool isLoading;
  final List<NearbyFriendModel> friends;
  final DateTime? lastFetchedAt;
  final String? errorMessage;

  const NearbyFriendsState({
    this.isEnabled = false,
    this.visibilityMode = 'contacts_only',
    this.isLoading = false,
    this.friends = const [],
    this.lastFetchedAt,
    this.errorMessage,
  });

  List<NearbyFriendModel> get filteredFriends {
    if (visibilityMode == 'contacts_only') {
      return friends.where((f) => f.isContact).toList();
    }
    return friends;
  }

  NearbyFriendsState copyWith({
    bool? isEnabled,
    String? visibilityMode,
    bool? isLoading,
    List<NearbyFriendModel>? friends,
    DateTime? lastFetchedAt,
    String? errorMessage,
  }) {
    return NearbyFriendsState(
      isEnabled: isEnabled ?? this.isEnabled,
      visibilityMode: visibilityMode ?? this.visibilityMode,
      isLoading: isLoading ?? this.isLoading,
      friends: friends ?? this.friends,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      errorMessage: errorMessage,
    );
  }
}

final nearbyFriendsProvider =
    StateNotifierProvider<NearbyFriendsNotifier, NearbyFriendsState>((ref) {
  final repository = ref.watch(nearbyRepositoryProvider);
  return NearbyFriendsNotifier(repository);
});

class NearbyFriendsNotifier extends StateNotifier<NearbyFriendsState> {
  final NearbyRepository _repository;
  final Future<bool> Function()? _requestPermission;
  final Future<({double latitude, double longitude})?> Function()? _getLocation;
  final Logger _logger = Logger();
  DateTime? _lastFetchTime;
  static const Duration _throttleDuration = Duration(seconds: 15);

  NearbyFriendsNotifier(
    this._repository, {
    Future<bool> Function()? requestPermission,
    Future<({double latitude, double longitude})?> Function()? getLocation,
  })  : _requestPermission = requestPermission,
        _getLocation = getLocation,
        super(const NearbyFriendsState()) {
    loadPreferences();
  }

  /// Memuat preferensi awal dari database
  Future<void> loadPreferences() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await _repository.getPreferences();
      state = state.copyWith(
        isEnabled: prefs.enabled,
        visibilityMode: prefs.visibilityMode,
        isLoading: false,
      );

      if (prefs.enabled) {
        unawaited(refreshNearby(force: true));
      }
    } catch (e, st) {
      _logger.e('loadPreferences error: $e', error: e, stackTrace: st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat preferensi Teman Sekitar.',
      );
    }
  }

  /// Mengaktifkan atau menonaktifkan fitur Teman Sekitar
  Future<bool> toggleSharing(bool enabled, {String? visibilityMode}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      if (enabled) {
        // Minta izin lokasi terlebih dahulu
        final hasPermission = _requestPermission != null
            ? await _requestPermission()
            : await LocationService.requestPermission();

        if (!hasPermission) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Izin lokasi diperlukan untuk mengaktifkan Teman Sekitar.',
          );
          return false;
        }
      }

      final targetVisibilityMode = visibilityMode ?? state.visibilityMode;
      final prefs = await _repository.updatePreferences(
        enabled: enabled,
        visibilityMode: targetVisibilityMode,
      );

      state = state.copyWith(
        isEnabled: prefs.enabled,
        visibilityMode: prefs.visibilityMode,
        isLoading: false,
        friends: enabled ? state.friends : const [],
      );

      if (enabled) {
        await refreshNearby(force: true);
      }

      return true;
    } catch (e, st) {
      _logger.e('toggleSharing error: $e', error: e, stackTrace: st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memperbarui status Teman Sekitar.',
      );
      return false;
    }
  }

  /// Mengubah mode visibilitas (contacts_only vs everyone) dan memperbarui database serta list
  Future<void> setVisibilityMode(String mode) async {
    if (state.visibilityMode == mode) return;
    await toggleSharing(state.isEnabled, visibilityMode: mode);
  }

  /// Mengambil lokasi saat ini dan memperbarui daftar teman sekitar
  Future<void> refreshNearby({bool force = false}) async {
    if (!state.isEnabled) return;

    final now = DateTime.now();
    if (!force &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!) < _throttleDuration) {
      return;
    }

    _lastFetchTime = now;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      double? lat;
      double? lon;

      if (_getLocation != null) {
        final loc = await _getLocation();
        lat = loc?.latitude;
        lon = loc?.longitude;
      } else {
        final locationData = await LocationService.getCurrentLocation();
        lat = locationData?.latitude;
        lon = locationData?.longitude;
      }

      if (lat == null || lon == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Tidak dapat memperoleh koordinat lokasi terkini.',
        );
        return;
      }

      final nearbyList = await _repository.updateLocationAndFetchNearby(
        latitude: lat,
        longitude: lon,
      );

      state = state.copyWith(
        isLoading: false,
        friends: nearbyList,
        lastFetchedAt: DateTime.now(),
      );
    } catch (e, st) {
      _logger.e('refreshNearby error: $e', error: e, stackTrace: st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal menyegarkan teman sekitar.',
      );
    }
  }
}
