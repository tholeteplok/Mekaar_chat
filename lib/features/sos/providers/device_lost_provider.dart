import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/device_lost_repository.dart';
import '../../auth/providers/auth_provider.dart';

final deviceLostRepositoryProvider = Provider<DeviceLostRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return DeviceLostRepository(supabaseService);
});
