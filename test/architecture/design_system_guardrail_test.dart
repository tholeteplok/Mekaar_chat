import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Design System Guardrails (lib/features UI Centralization)', () {
    final featuresDir = Directory('lib/features');

    test('lib/features directory must exist', () {
      expect(featuresDir.existsSync(), isTrue,
          reason: 'Direktori lib/features harus tersedia untuk diuji.');
    });

    /// Daftar file legacy yang masih dalam proses migrasi ke Clean Core UI.
    ///
    /// ATURAN RATCHET (ZERO NEW DEBT):
    /// 1. DILARANG menambahkan file baru ke dalam allowlist ini!
    /// 2. Setiap fitur baru WAJIB 100% bebas dari raw Scaffold, AppBar, Card, AlertDialog.
    /// 3. Ketika file legacy di bawah selesai direfaktor ke komponen sentral,
    ///    hapus jalurnya dari daftar ini agar standar semakin ketat.
    const legacyAllowlist = <String>{
      'lib/features/auth/screens/pin_screen.dart',
      'lib/features/chat/dialogs/chat_deletion_dialogs.dart',
      'lib/features/chat/screens/call_screen.dart',
      'lib/features/chat/screens/chat_list_screen.dart',
      'lib/features/chat/screens/contact_list_screen.dart',
      'lib/features/chat/screens/contact_settings_screen.dart',
      'lib/features/chat/screens/create_group_details_screen.dart',
      'lib/features/chat/screens/create_group_select_members_screen.dart',
      'lib/features/chat/screens/emoji_store_screen.dart',
      'lib/features/chat/screens/group_details_screen.dart',
      'lib/features/chat/screens/incoming_call_screen.dart',
      'lib/features/chat/screens/message_search_screen.dart',
      'lib/features/chat/screens/new_chat_screen.dart',
      'lib/features/chat/screens/unified_camera_screen.dart',
      'lib/features/chat/screens/vault_screen.dart',
      'lib/features/chat/widgets/document_send_preview_sheet.dart',
      'lib/features/chat/widgets/image_send_preview_sheet.dart',
      'lib/features/guardian/screens/guardian_list_screen.dart',
      'lib/features/guardian/screens/guardian_tracking_screen.dart',
      'lib/features/guardian/screens/sos_viewer_screen.dart',
      'lib/features/map/screens/location_map_screen.dart',
      'lib/features/settings/screens/decoy_pin_screen.dart',
      'lib/features/settings/screens/pin_management_screen.dart',
      'lib/features/settings/screens/security_logs_screen.dart',
      'lib/features/settings/screens/settings_screen.dart',
      'lib/features/sos/screens/sos_drill_screen.dart',
      'lib/features/sos/screens/video_emergency_screen.dart',
    };

    // Regex pendeteksi komponen mentah bawaan Flutter:
    final rawAppBarRegex = RegExp(r'(?<![A-Za-z0-9_])AppBar\s*\(');
    final rawCardRegex = RegExp(r'(?<![A-Za-z0-9_])Card\s*\(');
    final rawScaffoldRegex = RegExp(r'(?<![A-Za-z0-9_])Scaffold\s*\(');
    final rawAlertDialogRegex = RegExp(r'(?<![A-Za-z0-9_])AlertDialog\s*\(');

    test(
      'FITUR BARU & NON-LEGACY WAJIB SENTRALISASI: Dilarang raw AppBar, Card, Scaffold, AlertDialog',
      () {
        final violations = <String>[];

        final dartFiles = featuresDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'));

        for (final file in dartFiles) {
          final normalizedPath = file.path.replaceAll('\\', '/');

          // Skip file yang terdaftar di legacy allowlist
          if (legacyAllowlist.contains(normalizedPath)) {
            continue;
          }

          final lines = file.readAsLinesSync();

          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            final trimmed = line.trim();

            if (trimmed.startsWith('//') || trimmed.startsWith('/*')) {
              continue;
            }

            if (rawAppBarRegex.hasMatch(line)) {
              violations.add(
                '[$normalizedPath:${i + 1}] DILARANG memakai raw AppBar.\n'
                '   Snippet: $trimmed\n'
                '   Solusi: Gunakan CustomAppBar / MekaarTopBar dari lib/core/widgets/. '
                'Lihat docs/DESIGN_SYSTEM_CATALOG.md\n',
              );
            }

            if (rawCardRegex.hasMatch(line)) {
              violations.add(
                '[$normalizedPath:${i + 1}] DILARANG memakai raw Card.\n'
                '   Snippet: $trimmed\n'
                '   Solusi: Gunakan CustomCard dari lib/core/widgets/custom_card.dart. '
                'Lihat docs/DESIGN_SYSTEM_CATALOG.md\n',
              );
            }

            if (rawScaffoldRegex.hasMatch(line)) {
              violations.add(
                '[$normalizedPath:${i + 1}] DILARANG memakai raw Scaffold.\n'
                '   Snippet: $trimmed\n'
                '   Solusi: Gunakan MekaarScaffold dari lib/core/widgets/mekaar_scaffold.dart. '
                'Lihat docs/DESIGN_SYSTEM_CATALOG.md\n',
              );
            }

            if (rawAlertDialogRegex.hasMatch(line)) {
              violations.add(
                '[$normalizedPath:${i + 1}] DILARANG memakai raw AlertDialog.\n'
                '   Snippet: $trimmed\n'
                '   Solusi: Gunakan MekaarDialog.showConfirmation(...) dari lib/core/widgets/mekaar_dialog.dart. '
                'Lihat docs/DESIGN_SYSTEM_CATALOG.md\n',
              );
            }
          }
        }

        if (violations.isNotEmpty) {
          final summary = StringBuffer();
          summary.writeln(
            '\n❌ DITEMUKAN ${violations.length} PELANGGARAN DESAIN SISTEM DI FILE BARU/AKTIF:\n',
          );
          for (final violation in violations) {
            summary.writeln(violation);
          }
          summary.writeln(
            'WAJIB: Seluruh fitur baru di MEKAAR 3.0 harus tersentralisasi. Dilarang membuat UI ad-hoc.\n'
            'Jika butuh komponen baru, perbarui lib/core/ terlebih dahulu sesuai protokol AGENTS.md.\n',
          );

          fail(summary.toString());
        }
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

        final lines = file.readAsLinesSync();
        var hasViolation = false;

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('/*')) continue;

          if (rawAppBarRegex.hasMatch(line) ||
              rawCardRegex.hasMatch(line) ||
              rawScaffoldRegex.hasMatch(line) ||
              rawAlertDialogRegex.hasMatch(line)) {
            hasViolation = true;
            break;
          }
        }

        if (!hasViolation) {
          cleanlyRefactored.add(legacyPath);
        }
      }

      if (cleanlyRefactored.isNotEmpty) {
        // ignore: avoid_print
        print(
          '💡 [RATCHET INFO] File berikut sudah 100% bersih dan dapat dihapus dari legacyAllowlist:\n'
          '${cleanlyRefactored.join('\n')}',
        );
      }
    });
  });
}
