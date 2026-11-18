import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Settings Copy Guardrails (MekaarCopy)', () {
    final settingsDir = Directory('lib/features/settings');

    test('lib/features/settings directory must exist', () {
      expect(settingsDir.existsSync(), isTrue,
          reason: 'Direktori lib/features/settings harus tersedia untuk diuji.');
    });

    /// File Pengaturan yang masih mengandung literal judul/subjudul hardcode.
    ///
    /// ATURAN RATCHET (ZERO NEW DEBT — sama seperti guardrail widget):
    /// 1. DILARANG menambahkan file baru ke dalam allowlist ini!
    /// 2. File baru & file di luar daftar ini WAJIB 100% bebas literal
    ///    judul/subjudul — judul wajib berasal dari MekaarCopy.
    /// 3. Ketika file di bawah selesai dimigrasikan ke MekaarCopy,
    ///    hapus jalurnya dari daftar ini agar standar semakin ketat.
    /// 4. Jumlah total literal di file allowlist TIDAK BOLEH naik di atas
    ///    baseline (lihat test 'Total literal...') — file lama pun dilarang
    ///    menambah literal baru.
    const legacyAllowlist = <String>{
      'lib/features/settings/screens/about_mekaar_screen.dart',
      'lib/features/settings/screens/add_trip_screen.dart',
      'lib/features/settings/screens/blocked_list_screen.dart',
      'lib/features/settings/screens/chat_theme_settings_screen.dart',
      'lib/features/settings/screens/connected_devices_screen.dart',
      'lib/features/settings/screens/decoy_pin_screen.dart',
      'lib/features/settings/screens/duress_pin_screen.dart',
      'lib/features/settings/screens/pin_management_screen.dart',
      'lib/features/settings/screens/profile_screen.dart',
      'lib/features/settings/screens/security_logs_screen.dart',
      'lib/features/settings/screens/sound_picker_screen.dart',
      'lib/features/settings/screens/theme_settings_screen.dart',
      'lib/features/settings/screens/trip_arrival_confirm_screen.dart',
      'lib/features/settings/screens/trip_list_screen.dart',
      'lib/features/settings/screens/two_factor_setup_screen.dart',
    };

    // Baseline literal judul/subjudul yang terukur.
    // settings_screen.dart dan account_snippet_card.dart telah 100% dimigrasikan ke MekaarCopy!
    // advanced_privacy_settings_screen.dart telah dihapus (dead code cleanup).
    const baselineLiteralLines = 119;

    // Regex pendeteksi literal judul/subjudul hardcode (per baris):
    final titleLiteralRegex = RegExp(r"title:\s*'[^']+'");
    final subtitleLiteralRegex = RegExp(r"subtitle:\s*'[^']+'");
    final titleTextLiteralRegex =
        RegExp(r"title:\s*(?:const\s+)?Text\(\s*'[^']+'");
    final subtitleTextLiteralRegex =
        RegExp(r"subtitle:\s*(?:const\s+)?Text\(\s*'[^']+'");

    bool isCopyLiteral(String line) {
      final trimmed = line.trim();
      if (trimmed.startsWith('//') || trimmed.startsWith('/*')) {
        return false;
      }
      return titleLiteralRegex.hasMatch(line) ||
          subtitleLiteralRegex.hasMatch(line) ||
          titleTextLiteralRegex.hasMatch(line) ||
          subtitleTextLiteralRegex.hasMatch(line);
    }

    List<File> settingsFiles() => settingsDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    int countLiterals(File file) {
      var count = 0;
      for (final line in file.readAsLinesSync()) {
        if (isCopyLiteral(line)) count++;
      }
      return count;
    }

    test(
      'FILE BARU & NON-LEGACY WAJIB MekaarCopy: Dilarang literal judul/subjudul hardcode',
      () {
        final violations = <String>[];

        for (final file in settingsFiles()) {
          final normalizedPath = file.path.replaceAll('\\', '/');

          // Skip file yang terdaftar di legacy allowlist.
          if (legacyAllowlist.contains(normalizedPath)) {
            continue;
          }

          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            if (isCopyLiteral(lines[i])) {
              violations.add(
                '[$normalizedPath:${i + 1}] DILARANG literal judul/subjudul hardcode.\n'
                '   Snippet: ${lines[i].trim()}\n'
                '   Solusi: Daftarkan copy-nya di MekaarCopy '
                '(lib/core/constants/strings.dart) lalu rujuk dari sana.\n',
              );
            }
          }
        }

        if (violations.isNotEmpty) {
          final summary = StringBuffer();
          summary.writeln(
            '\n❌ DITEMUKAN ${violations.length} LITERAL COPY HARDCODE DI FILE PENGATURAN BARU/AKTIF:\n',
          );
          for (final violation in violations) {
            summary.writeln(violation);
          }
          summary.writeln(
            'WAJIB: Judul & subjudul Pengaturan berasal dari MekaarCopy.\n',
          );

          fail(summary.toString());
        }
      },
    );

    test(
      'RATCHET TOTAL: Literal di file legacy tidak boleh bertambah (baseline $baselineLiteralLines)',
      () {
        var total = 0;
        final perFile = <String, int>{};

        for (final file in settingsFiles()) {
          final normalizedPath = file.path.replaceAll('\\', '/');
          if (!legacyAllowlist.contains(normalizedPath)) continue;
          final count = countLiterals(file);
          if (count > 0) perFile[normalizedPath] = count;
          total += count;
        }

        expect(
          total,
          lessThanOrEqualTo(baselineLiteralLines),
          reason:
              'Literal judul/subjudul di Pengaturan naik dari $baselineLiteralLines '
              'menjadi $total — ada literal BARU di file legacy. Daftarkan copy-nya '
              'di MekaarCopy, atau turunkan baseline hanya bila satu file selesai '
              'dibersihkan dan dicabut dari allowlist.\n'
              'Per file: $perFile',
        );
      },
    );

    test('Allowlist Ratchet Hygiene: File legacy yang sudah bersih harus dicabut dari allowlist', () {
      final cleanlyRefactored = <String>[];

      for (final legacyPath in legacyAllowlist) {
        final file = File(legacyPath);
        if (!file.existsSync()) {
          cleanlyRefactored.add('$legacyPath (File sudah dihapus/dipindah)');
          continue;
        }
        if (countLiterals(file) == 0) {
          cleanlyRefactored.add(legacyPath);
        }
      }

      if (cleanlyRefactored.isNotEmpty) {
        // ignore: avoid_print
        print(
          '💡 [RATCHET INFO] File berikut sudah 100% bersih dari literal judul/subjudul dan dapat dihapus dari legacyAllowlist:\n'
          '${cleanlyRefactored.join('\n')}',
        );
      }
    });
  });
}
