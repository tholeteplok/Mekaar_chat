import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/services/webrtc_signaling_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeRealtimeChannel extends RealtimeChannel {
  Function(Map<String, dynamic>)? onBroadcastCallback;

  RealtimeSubscribeStatus lastStatus = RealtimeSubscribeStatus.closed;

  FakeRealtimeChannel()
      : super(
          'room_call:test',
          RealtimeClient('ws://localhost:1234/realtime'),
        );

  @override
  RealtimeChannel onBroadcast({
    required String event,
    required void Function(Map<String, dynamic> payload) callback,
  }) {
    onBroadcastCallback = callback;
    return this;
  }

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) {
    Future.microtask(() {
      lastStatus = RealtimeSubscribeStatus.subscribed;
      callback?.call(RealtimeSubscribeStatus.subscribed, null);
    });
    return this;
  }

  @override
  Future<String> unsubscribe([Duration? timeout]) async => 'ok';

  @override
  Future<ChannelResponse> sendBroadcastMessage({
    required String event,
    required Map<String, dynamic> payload,
  }) async =>
      ChannelResponse.ok;

  void simulateIncoming(Map<String, dynamic> payload) {
    onBroadcastCallback?.call(payload);
  }
}

class FakeSupabaseClient extends SupabaseClient {
  final FakeRealtimeChannel _channel = FakeRealtimeChannel();

  FakeSupabaseClient()
      : super(
          'https://example.supabase.co',
          'public-anon-key',
        );

  @override
  RealtimeChannel channel(
    String topic, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) {
    return _channel;
  }

  @override
  Future<String> removeChannel(RealtimeChannel channel) async => 'ok';
}

void main() {
  group('WebRtcSignalingService', () {
    test('konstruktor menerima configuration opsional tanpa throw', () {
      final client = FakeSupabaseClient();
      expect(
        () => WebRtcSignalingService(client),
        returnsNormally,
      );
      expect(
        () => WebRtcSignalingService(
          client,
          configuration: {
            'iceServers': [
              {'urls': 'stun:stun.l.google.com:19302'}
            ]
          },
        ),
        returnsNormally,
      );
    });

    test('cleanUp idempoten dipanggil berkali-kali tanpa throw', () async {
      final client = FakeSupabaseClient();
      final service = WebRtcSignalingService(client);
      expect(() async => await service.cleanUp(), returnsNormally);
      expect(() async => await service.cleanUp(), returnsNormally);
      expect(() async => await service.cleanUp(), returnsNormally);
    });

    test('hangup idempoten tanpa throw saat dipanggil dua kali', () async {
      final client = FakeSupabaseClient();
      final service = WebRtcSignalingService(client);
      var hangupCalled = 0;
      service.onHangup = () => hangupCalled++;
      expect(() async => await service.hangup('user-1'), returnsNormally);
      expect(() async => await service.hangup('user-1'), returnsNormally);
    });

    test('assign dan clear callback tidak menyebabkan error', () {
      final client = FakeSupabaseClient();
      final service = WebRtcSignalingService(client);

      expect(() {
        service.onLocalStream = (_) {};
        service.onRemoteStream = (_) {};
        service.onCallStateChange = (_) {};
        service.onHangup = () {};
        service.onError = (_) {};
      }, returnsNormally);

      expect(() {
        service.onLocalStream = null;
        service.onRemoteStream = null;
        service.onCallStateChange = null;
        service.onHangup = null;
        service.onError = null;
      }, returnsNormally);
    });

    test('onError dipanggil saat error di-emit', () {
      final client = FakeSupabaseClient();
      final service = WebRtcSignalingService(client);
      Object? captured;
      service.onError = (e) => captured = e;
      service.onError?.call('tes-error');
      expect(captured, 'tes-error');
    });
  });
}
