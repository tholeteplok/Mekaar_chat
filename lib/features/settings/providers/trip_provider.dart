import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/guardian_model.dart';
import '../../../data/models/saved_place_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/saved_places_repository.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../guardian/providers/guardian_provider.dart';

/// Provider terpusat untuk mengambil seluruh rute pengguna
final userTripsProvider = FutureProvider.autoDispose<List<UserTrip>>((ref) async {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.getUserTrips();
});

/// Provider terpusat untuk mengambil daftar Guardian aktif milik pengguna
final activeGuardiansProvider = FutureProvider.autoDispose<List<Guardian>>((ref) async {
  final repo = ref.watch(guardianRepositoryProvider);
  return repo.getMyGuardians();
});

/// Provider terpusat untuk mengambil lokasi bookmark tersimpan (Rumah, Kantor, Kampus)
final savedPlacesProvider = FutureProvider.autoDispose<Map<String, SavedPlace>>((ref) async {
  final repo = ref.watch(savedPlacesRepositoryProvider);
  return repo.getSavedPlaces();
});
