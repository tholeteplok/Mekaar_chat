/// Kebijakan retry untuk re-subscribe stream Realtime (murni, bisa diuji unit).
///
/// Delay berjenjang eksponensial: percobaan 1 → 1 detik, 2 → 2 detik,
/// 3 → 4 detik, dst, dengan cap 8 detik. Maksimal [maxAttempts] percobaan
/// otomatis sebelum benar-benar menyerah dan propagate error ke UI.
class ReconnectPolicy {
  const ReconnectPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 8),
  });

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;

  /// Delay yang dipakai untuk percobaan ke-[attempt] (1-indexed).
  Duration delayForAttempt(int attempt) {
    final shifted = baseDelay.inMilliseconds * (1 << (attempt - 1));
    final capped = shifted > maxDelay.inMilliseconds
        ? maxDelay.inMilliseconds
        : shifted;
    return Duration(milliseconds: capped);
  }
}