import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_place_model.dart';

final savedPlacesRepositoryProvider = Provider<SavedPlacesRepository>((ref) {
  return SavedPlacesRepository();
});

class SavedPlacesRepository {
  static const String _prefKey = 'user_saved_places_v1';

  Future<Map<String, SavedPlace>> getSavedPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_prefKey);
      if (rawJson == null || rawJson.isEmpty) return {};

      final Map<String, dynamic> decoded = jsonDecode(rawJson);
      final map = <String, SavedPlace>{};
      decoded.forEach((key, value) {
        map[key] = SavedPlace.fromJson(value as Map<String, dynamic>);
      });
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<SavedPlace?> getSavedPlace(String id) async {
    final places = await getSavedPlaces();
    return places[id];
  }

  Future<void> savePlace(SavedPlace place) async {
    final places = await getSavedPlaces();
    places[place.id] = place;

    final prefs = await SharedPreferences.getInstance();
    final rawJson = jsonEncode(places.map((k, v) => MapEntry(k, v.toJson())));
    await prefs.setString(_prefKey, rawJson);
  }

  Future<void> deletePlace(String id) async {
    final places = await getSavedPlaces();
    places.remove(id);

    final prefs = await SharedPreferences.getInstance();
    final rawJson = jsonEncode(places.map((k, v) => MapEntry(k, v.toJson())));
    await prefs.setString(_prefKey, rawJson);
  }
}
