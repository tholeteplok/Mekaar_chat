import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/features/chat/screens/chat_screen.dart';

void main() {
  final staleError = AsyncValue<List<Message>>.error(
    Exception('RealtimeSubscribeException(status: timedOut, details: null)'),
    StackTrace.current,
  );

  group('chatMessagesUiMode — stale-while-revalidate', () {
    test('loading murni → mode loading', () {
      expect(chatMessagesUiMode(const AsyncLoading()), ChatMessagesUiMode.loading);
    });

    test('error tanpa data (gagal pertama buka chat) → mode error', () {
      expect(chatMessagesUiMode(staleError), ChatMessagesUiMode.error);
    });

    test('data sukses → mode data', () {
      const data = AsyncValue<List<Message>>.data(<Message>[]);
      expect(chatMessagesUiMode(data), ChatMessagesUiMode.data);
    });

    test('error SETELAH data pernah termuat → tetap mode data (tidak collapse)', () {
      final staleWithData = staleError.copyWithPrevious(
        const AsyncValue<List<Message>>.data(<Message>[]),
      );
      // hasValue tetap true meski hasError true — data lama tidak hilang
      expect(staleWithData.hasValue, isTrue);
      expect(staleWithData.hasError, isTrue);
      expect(chatMessagesUiMode(staleWithData), ChatMessagesUiMode.data);
    });
  });
}