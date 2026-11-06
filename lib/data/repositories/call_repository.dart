import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/call_model.dart';
import '../services/local_message_database.dart';
import '../services/push_notification_service.dart';
import '../../features/auth/providers/auth_provider.dart';

class CallRepository {
  final SupabaseClient _client;

  static final Map<String, Set<String>> _cachedHiddenCallIds = {};
  static final Map<String, DateTime> _cachedHistoryClearedAt = {};
  static final Map<String, int> _cachedDisappearingHours = {};

  static Set<String> getCachedHiddenCallIds(String roomId) =>
      _cachedHiddenCallIds[roomId] ?? const <String>{};

  CallRepository(this._client);

  /// Catat baris panggilan baru dengan status 'ringing'
  /// Memverifikasi hubungan chat sebelum mengizinkan panggilan
  Future<Map<String, dynamic>> createCall({
    required String roomId,
    required String callerId,
    required String receiverId,
    required String callType,
  }) async {
    // Verifikasi izin chat & keanggotaan room sebelum panggilan
    final isApproved = await _isChatApprovedForCall(
      callerId,
      receiverId,
      roomId: roomId,
    );
    if (!isApproved) {
      throw Exception(
        'Chat belum disetujui atau bukan partisipan room yang sah.',
      );
    }

    Map<String, dynamic> response;
    try {
      final res = await _client
          .from('calls')
          .insert({
            'room_id': roomId,
            'caller_id': callerId,
            'receiver_id': receiverId,
            'call_type': callType,
            'status': 'calling',
          })
          .select()
          .single();
      response = Map<String, dynamic>.from(res);
    } catch (e) {
      debugPrint(
        '[CallRepository] createCall dengan status "calling" gagal, fallback ke "ringing": $e',
      );
      final res = await _client
          .from('calls')
          .insert({
            'room_id': roomId,
            'caller_id': callerId,
            'receiver_id': receiverId,
            'call_type': callType,
            'status': 'ringing',
          })
          .select()
          .single();
      response = Map<String, dynamic>.from(res);
    }

    // Dual-dispatch fallback push notification ke penerima panggilan
    unawaited(
      PushNotificationService.dispatchPushFallback(
        type: 'call',
        record: response,
      ),
    );

    // Simpan panggilan ke cache lokal seketika
    try {
      final callObj = CallModel.fromJson(response);
      unawaited(LocalMessageDatabase.instance.saveCall(callObj));
    } catch (_) {}

    return response;
  }

  /// Cek internal apakah relasi chat sah untuk melakukan panggilan
  Future<bool> _isChatApprovedForCall(
    String userId,
    String otherUserId, {
    String? roomId,
  }) async {
    try {
      // 1. Jika roomId tersedia, cek apakah kedua pengguna adalah partisipan sah di room tersebut
      if (roomId != null && roomId.isNotEmpty) {
        final participants = await _client
            .from('room_participants')
            .select('profile_id')
            .eq('room_id', roomId)
            .inFilter('profile_id', [userId, otherUserId]);

        final matchedIds = (participants as List)
            .map((p) => p['profile_id'] as String?)
            .whereType<String>()
            .toSet();

        if (matchedIds.contains(userId) && matchedIds.contains(otherUserId)) {
          return true;
        }
      }

      // 2. Cek relasi Guardian aktif (Guardian selalu berhak memanggil / dipanggil)
      final guardianRow = await _client
          .from('guardians')
          .select('id')
          .or(
            'and(user_id.eq.$userId,guardian_id.eq.$otherUserId),and(user_id.eq.$otherUserId,guardian_id.eq.$userId)',
          )
          .eq('status', 'active')
          .maybeSingle();
      if (guardianRow != null) return true;

      // 3. Cek mode proteksi target user
      final profileResponse = await _client
          .from('public_profiles')
          .select('chat_invitation_mode')
          .eq('id', otherUserId)
          .maybeSingle();

      final mode =
          profileResponse?['chat_invitation_mode'] as String? ??
          'approved_only';
      if (mode == 'everyone') return true;

      // 4. Mode approved_only — cek chat_requests yang disetujui
      final response = await _client
          .from('chat_requests')
          .select('status')
          .or(
            'and(sender_id.eq.$userId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$userId)',
          )
          .eq('status', 'accepted')
          .maybeSingle();

      return response != null;
    } catch (e, st) {
      debugPrint('CallRepository._isChatApprovedForCall warning: $e\n$st');
      // Fallback: Jika query pengecekan client-side gagal tapi roomId valid,
      // izinkan inisiasi agar hak akses divalidasi oleh RLS database server.
      return roomId != null && roomId.isNotEmpty;
    }
  }

  /// Perbarui status panggilan ('answered', 'declined', 'busy', 'missed', 'ended', 'failed')
  Future<void> updateCallStatus(
    String callId,
    String status, {
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) async {
    final Map<String, dynamic> updates = {
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (startedAt != null) updates['started_at'] = startedAt.toIso8601String();
    if (endedAt != null) updates['ended_at'] = endedAt.toIso8601String();
    if (durationSeconds != null) updates['duration_seconds'] = durationSeconds;

    await _client.from('calls').update(updates).eq('id', callId);
  }

  /// Konfirmasi dari perangkat penerima bahwa layar panggilan aktif dan sedang berdering
  Future<void> markCallRinging(String callId) async {
    try {
      await updateCallStatus(callId, 'ringing');
    } catch (e) {
      debugPrint('[CallRepository] Gagal memperbarui status ke ringing: $e');
    }
  }

  /// Mengakhiri panggilan dan mencatat durasi secara otomatis
  Future<void> endCall(String callId, {DateTime? startedAt}) async {
    final now = DateTime.now();
    int duration = 0;
    if (startedAt != null) {
      duration = now.difference(startedAt).inSeconds;
      if (duration < 0) duration = 0;
    }
    await updateCallStatus(
      callId,
      'ended',
      startedAt: startedAt,
      endedAt: now,
      durationSeconds: duration,
    );
  }

  /// Ambil detail panggilan berdasarkan ID
  Future<Map<String, dynamic>?> getCall(String callId) async {
    final response = await _client
        .from('calls')
        .select()
        .eq('id', callId)
        .maybeSingle();
    if (response == null) return null;
    return Map<String, dynamic>.from(response);
  }

  /// Ambil panggilan aktif terbaru yang ditujukan ke receiverId (dalam kurun waktu tertentu, default 45 detik)
  Future<Map<String, dynamic>?> getPendingIncomingCall(
    String receiverId, {
    Duration window = const Duration(seconds: 45),
  }) async {
    final threshold =
        DateTime.now().toUtc().subtract(window).toIso8601String();
    try {
      final response = await _client
          .from('calls')
          .select()
          .eq('receiver_id', receiverId)
          .inFilter('status', ['calling', 'ringing'])
          .gte('created_at', threshold)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('[CallRepository] getPendingIncomingCall gagal: $e');
      return null;
    }
  }

  /// Ambil riwayat panggilan tak terjawab terbaru yang terjadi dalam kurun waktu tertentu (offline mitigation)
  Future<List<Map<String, dynamic>>> getRecentMissedCalls(
    String receiverId, {
    Duration window = const Duration(minutes: 10),
  }) async {
    final threshold =
        DateTime.now().toUtc().subtract(window).toIso8601String();
    try {
      final response = await _client
          .from('calls')
          .select()
          .eq('receiver_id', receiverId)
          .eq('status', 'missed')
          .gte('created_at', threshold)
          .order('created_at', ascending: false)
          .limit(5);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[CallRepository] getRecentMissedCalls gagal: $e');
      return [];
    }
  }

  /// Stream riwayat panggilan untuk room tertentu secara offline-first (0 ms) & realtime
  Stream<List<CallModel>> streamCalls(String roomId) {
    final controller = StreamController<List<CallModel>>();
    StreamSubscription? streamSubscription;
    final Map<String, CallModel> callPool = {};

    // Helper untuk memancarkan cache dari SQLite lokal seketika (0 ms)
    Future<void> emitLocalCache({
      DateTime? historyCleared,
      Set<String>? hiddenIds,
      int? disappearingHours,
    }) async {
      try {
        final localCalls = await LocalMessageDatabase.instance.getCallsForRoom(
          roomId,
          historyClearedAt: historyCleared,
          hiddenCallIds: hiddenIds,
        );
        final nowUtc = DateTime.now().toUtc();
        final effectiveHidden = hiddenIds ?? _cachedHiddenCallIds[roomId];
        final effectiveCleared = historyCleared ?? _cachedHistoryClearedAt[roomId];
        final effectiveDisappearing = disappearingHours ?? _cachedDisappearingHours[roomId] ?? 0;

        callPool.clear();
        for (final c in localCalls) {
          if (effectiveHidden != null && effectiveHidden.contains(c.id)) continue;
          if (effectiveCleared != null && !c.createdAt.toUtc().isAfter(effectiveCleared)) continue;
          if (effectiveDisappearing > 0 &&
              c.createdAt.toUtc().add(Duration(hours: effectiveDisappearing)).isBefore(nowUtc)) {
            continue;
          }
          callPool[c.id] = c;
        }

        if (!controller.isClosed) {
          final sorted = callPool.values.toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          controller.add(sorted);
        }
      } catch (_) {}
    }

    Future<void> initStream() async {
      // 1. 0ms Offline-First Anti-Flicker: Render dari SQLite menggunakan filter cache yang sudah diketahui
      await emitLocalCache(
        historyCleared: _cachedHistoryClearedAt[roomId],
        hiddenIds: _cachedHiddenCallIds[roomId],
        disappearingHours: _cachedDisappearingHours[roomId],
      );

      // Zero-Leak Decoy: Jangan jalankan query jaringan atau streaming Supabase
      if (LocalMessageDatabase.instance.isDecoy) {
        return;
      }

      final userId = _client.auth.currentUser?.id;
      if (userId == null || controller.isClosed) return;

      // 2. Ambil stempel waktu pembersihan obrolan (history_cleared_at) & disappearing_hours dari room
      DateTime? historyClearedAt = _cachedHistoryClearedAt[roomId];
      int disappearingHours = _cachedDisappearingHours[roomId] ?? 0;
      try {
        final results = await Future.wait([
          _client
              .from('room_participants')
              .select('history_cleared_at')
              .eq('room_id', roomId)
              .eq('profile_id', userId)
              .maybeSingle()
              .timeout(const Duration(seconds: 4)),
          _client
              .from('chat_rooms')
              .select('disappearing_hours')
              .eq('id', roomId)
              .maybeSingle()
              .timeout(const Duration(seconds: 4)),
        ]);

        final p = results[0];
        if (p != null && p['history_cleared_at'] != null) {
          historyClearedAt =
              DateTime.tryParse(p['history_cleared_at'] as String)?.toUtc();
          if (historyClearedAt != null) {
            _cachedHistoryClearedAt[roomId] = historyClearedAt;
            unawaited(LocalMessageDatabase.instance.deleteCallsBefore(roomId, historyClearedAt));
          }
        }

        final roomData = results[1];
        if (roomData != null && roomData['disappearing_hours'] != null) {
          disappearingHours = (roomData['disappearing_hours'] as num).toInt();
          _cachedDisappearingHours[roomId] = disappearingHours;
          if (disappearingHours > 0) {
            unawaited(LocalMessageDatabase.instance.deleteExpiredCalls(roomId, disappearingHours));
          }
        }
      } catch (_) {}

      // 3. Ambil ID panggilan yang disembunyikan (hidden_calls) dengan timeout aman
      final hiddenCallIds = Set<String>.from(_cachedHiddenCallIds[roomId] ?? <String>{});
      try {
        final rows = await _client
            .from('hidden_calls')
            .select('call_id')
            .eq('profile_id', userId)
            .timeout(const Duration(seconds: 4));
        for (final r in rows as List) {
          final cid = r['call_id'] as String?;
          if (cid != null) {
            hiddenCallIds.add(cid);
            unawaited(LocalMessageDatabase.instance.deleteCall(cid));
          }
        }
        _cachedHiddenCallIds[roomId] = hiddenCallIds;
      } catch (_) {}

      // Perbarui tampilan cache lokal jika filter jaringan berhasil didapatkan
      await emitLocalCache(
        historyCleared: historyClearedAt,
        hiddenIds: hiddenCallIds,
        disappearingHours: disappearingHours,
      );

      if (controller.isClosed) return;

      // Helper pemrosesan batch panggilan (digunakan oleh REST dan Realtime)
      void processCallBatch(List<CallModel> serverCalls) {
        final nowUtc = DateTime.now().toUtc();
        final serverCallIds = serverCalls.map((c) => c.id).toSet();

        // 1. Rekonsiliasi Server-to-Local:
        // Eviksi panggilan di callPool dan SQLite yang sudah terhapus di backend (misal via scheduled wipe atau burn on exit)
        final poolIds = callPool.keys.toList();
        for (final pId in poolIds) {
          if (!serverCallIds.contains(pId)) {
            callPool.remove(pId);
            unawaited(LocalMessageDatabase.instance.deleteCall(pId));
          }
        }

        // 2. Filter ketat sebelum simpan: Jangan pernah menyimpan kembali baris yang disembunyikan/dibersihkan
        final validCallsToSave = <CallModel>[];
        for (final c in serverCalls) {
          final isHidden = hiddenCallIds.contains(c.id);
          final isCleared = historyClearedAt != null && !c.createdAt.toUtc().isAfter(historyClearedAt);
          final isExpired = disappearingHours > 0 &&
              c.createdAt.toUtc().add(Duration(hours: disappearingHours)).isBefore(nowUtc);

          if (isHidden || isCleared || isExpired) {
            callPool.remove(c.id);
            unawaited(LocalMessageDatabase.instance.deleteCall(c.id));
          } else {
            callPool[c.id] = c;
            validCallsToSave.add(c);
          }
        }

        if (validCallsToSave.isNotEmpty) {
          unawaited(LocalMessageDatabase.instance.saveCalls(validCallsToSave));
        }

        if (!controller.isClosed) {
          final sorted = callPool.values.toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          controller.add(sorted);
        }
      }

      // 4. REST fetch cepat untuk inisialisasi awal (stale-while-revalidate)
      try {
        final rows = await _client
            .from('calls')
            .select()
            .eq('room_id', roomId)
            .order('created_at', ascending: true)
            .limit(50)
            .timeout(const Duration(seconds: 4));
        final calls =
            (rows as List).map((r) => CallModel.fromJson(r)).toList();
        processCallBatch(calls);
      } catch (_) {}

      if (controller.isClosed) return;

      // 5. Berlangganan Supabase Realtime stream
      try {
        streamSubscription = _client
            .from('calls')
            .stream(primaryKey: ['id'])
            .eq('room_id', roomId)
            .order('created_at', ascending: true)
            .listen(
              (rows) {
                final calls =
                    rows.map((r) => CallModel.fromJson(r)).toList();
                processCallBatch(calls);
              },
              onError: (_) {},
            );
      } catch (_) {}
    }

    controller.onListen = () {
      initStream();
    };

    controller.onCancel = () {
      streamSubscription?.cancel();
      controller.close();
    };

    return controller.stream;
  }

  /// Menyembunyikan panggilan tertentu secara permanen di database cloud & lokal
  Future<void> hideCalls(Set<String> callIds, {String? roomId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || callIds.isEmpty) return;

    for (final cid in callIds) {
      unawaited(LocalMessageDatabase.instance.deleteCall(cid));
    }

    if (roomId != null) {
      final existingHidden = _cachedHiddenCallIds[roomId] ?? <String>{};
      existingHidden.addAll(callIds);
      _cachedHiddenCallIds[roomId] = existingHidden;
    }

    final records = callIds
        .map((cid) => {
              'profile_id': userId,
              'call_id': cid,
            })
        .toList();

    try {
      await _client
          .from('hidden_calls')
          .upsert(records, onConflict: 'profile_id,call_id');
    } catch (_) {}
  }
}

final callRepositoryProvider = Provider<CallRepository>((ref) {
  final supabase = ref.read(supabaseServiceProvider);
  return CallRepository(supabase.client);
});
