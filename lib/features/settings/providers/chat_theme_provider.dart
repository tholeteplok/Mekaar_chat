import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/chat_theme_model.dart';

class ChatThemeNotifier extends StateNotifier<AsyncValue<ChatThemePreference>> {
  ChatThemeNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  static const String _key = 'mekaar_chat_theme_pref';

  Future<void> _load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> json = jsonDecode(raw);
        return ChatThemePreference.fromJson(json);
      }
      return const ChatThemePreference();
    });
  }

  Future<void> _save(ChatThemePreference pref) async {
    state = AsyncValue.data(pref);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(pref.toJson()));
    } catch (_) {}
  }

  Future<void> applyPreset(ChatThemePreset preset) async {
    switch (preset) {
      case ChatThemePreset.dynamicTime:
        await _save(ChatThemePreference.dynamicTime);
        break;
      case ChatThemePreset.neonCyberpunk:
        await _save(ChatThemePreference.neonCyberpunk);
        break;
      case ChatThemePreset.comicPopArt:
        await _save(ChatThemePreference.comicPopArt);
        break;
      case ChatThemePreset.neumorphism:
        await _save(ChatThemePreference.neumorphism);
        break;
      case ChatThemePreset.glassmorphism:
        await _save(ChatThemePreference.glassmorphism);
        break;
      case ChatThemePreset.pixelGarden:
        await _save(ChatThemePreference.pixelGarden);
        break;
      case ChatThemePreset.isometric3d:
        await _save(ChatThemePreference.isometric3d);
        break;
      case ChatThemePreset.retroY2K:
        await _save(ChatThemePreference.retroY2K);
        break;
      case ChatThemePreset.swissMinimalist:
        await _save(ChatThemePreference.swissMinimalist);
        break;
      case ChatThemePreset.solarpunk:
        await _save(ChatThemePreference.solarpunk);
        break;
      case ChatThemePreset.fireflyNight:
        await _save(ChatThemePreference.fireflyNight);
        break;
      case ChatThemePreset.diary:
        await _save(ChatThemePreference.diary);
        break;
      case ChatThemePreset.custom:
        final current = state.valueOrNull ?? const ChatThemePreference();
        await _save(current.copyWith(preset: ChatThemePreset.custom));
        break;
    }
  }

  Future<void> setWallpaper(WallpaperType type, {String? value}) async {
    final current = state.valueOrNull ?? const ChatThemePreference();
    await _save(current.copyWith(
      preset: ChatThemePreset.custom,
      wallpaperType: type,
      wallpaperValue: value,
    ));
  }

  Future<void> setBubbleStyle(ChatBubbleStyle style) async {
    final current = state.valueOrNull ?? const ChatThemePreference();
    await _save(current.copyWith(
      preset: ChatThemePreset.custom,
      bubbleStyle: style,
    ));
  }

  Future<void> setBubbleColor(ChatBubbleColorPreset colorPreset) async {
    final current = state.valueOrNull ?? const ChatThemePreference();
    await _save(current.copyWith(
      preset: ChatThemePreset.custom,
      bubbleColorPreset: colorPreset,
    ));
  }

  Future<void> setTextScale(double scale) async {
    final current = state.valueOrNull ?? const ChatThemePreference();
    await _save(current.copyWith(
      preset: ChatThemePreset.custom,
      textScale: scale,
    ));
  }

  Future<void> resetToDefault() async {
    await _save(const ChatThemePreference());
  }
}

final chatThemeProvider = StateNotifierProvider<ChatThemeNotifier, AsyncValue<ChatThemePreference>>((ref) {
  return ChatThemeNotifier();
});
