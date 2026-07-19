import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/notification_preferences.dart';
import '../../../data/repositories/notification_preferences_repository.dart';

final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>((ref) {
      return NotificationPreferencesRepository();
    });

class NotificationPreferencesNotifier
    extends StateNotifier<AsyncValue<NotificationPreferences>> {
  final NotificationPreferencesRepository _repository;

  NotificationPreferencesNotifier(this._repository)
    : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.load);
  }

  Future<void> save(NotificationPreferences value) async {
    await _repository.save(value);
    state = AsyncValue.data(value);
  }

  Future<void> update(
    NotificationPreferences Function(NotificationPreferences) cb,
  ) async {
    final current = state.value;
    if (current != null) {
      final next = cb(current);
      await save(next);
    }
  }

  Future<void> updateMessageSound(String value) =>
      update((current) => current.copyWith(messageSound: value));

  Future<void> updateCallSound(String value) =>
      update((current) => current.copyWith(callSound: value));

  Future<void> updateSosSound(String value) =>
      update((current) => current.copyWith(sosSound: value));

  Future<void> toggleMessageSound(bool enabled) =>
      update((current) => current.copyWith(messageSoundEnabled: enabled));

  Future<void> toggleCallSound(bool enabled) =>
      update((current) => current.copyWith(callSoundEnabled: enabled));

  Future<void> toggleHaptics(bool enabled) =>
      update((current) => current.copyWith(hapticsEnabled: enabled));
}

final notificationPreferencesProvider =
    StateNotifierProvider<
      NotificationPreferencesNotifier,
      AsyncValue<NotificationPreferences>
    >((ref) {
      final repository = ref.watch(
        notificationPreferencesRepositoryProvider,
      );
      return NotificationPreferencesNotifier(repository);
    });
