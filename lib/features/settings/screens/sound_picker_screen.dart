import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../data/services/ringtone_picker_service.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/models/notification_preferences.dart';
import '../providers/notification_preferences_provider.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/sound_preference_section.dart';

class SoundPickerScreen extends ConsumerStatefulWidget {
  const SoundPickerScreen({super.key});

  @override
  ConsumerState<SoundPickerScreen> createState() => _SoundPickerScreenState();
}

class _SoundPickerScreenState extends ConsumerState<SoundPickerScreen> {
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _previewingPath;
  bool _isPlayingPreview = false;

  final List<SoundOption> _messageSounds = const [
    SoundOption('Konfirmasi Halus', NotificationPreferences.defaultMessageSound),
    SoundOption('Pop Ceria', NotificationPreferences.alternateMessageSound),
  ];
  final List<SoundOption> _callSounds = const [
    SoundOption('Dering Melodi', NotificationPreferences.defaultCallSound),
    SoundOption('Konfirmasi Dering', NotificationPreferences.alternateCallSound),
  ];
  final List<SoundOption> _sosSounds = const [
    SoundOption('Alarm Peringatan', NotificationPreferences.defaultSosSound),
    SoundOption('Sirine Taktis', NotificationPreferences.alternateSosSound),
  ];

  @override
  void initState() {
    super.initState();
    _previewPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingPreview = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickDeviceSound({
    required RingtoneType type,
    required String title,
    required void Function(String) onSelected,
  }) async {
    try {
      final result = await RingtonePickerService.pickRingtone(
        type: type,
        title: title,
      );
      if (result != null && result.path.isNotEmpty) {
        onSelected(result.path);
      }
    } catch (e) {
      if (!mounted) return;
      MekaarSnackbar.error(context, 'Gagal memilih nada suara: $e');
    }
  }

  Future<void> _togglePreview(String path) async {
    try {
      if (_isPlayingPreview && _previewingPath == path) {
        await _previewPlayer.stop();
        setState(() {
          _isPlayingPreview = false;
          _previewingPath = null;
        });
      } else {
        await _previewPlayer.stop();
        await _previewPlayer.setVolume(0.8);
        await _previewPlayer.setReleaseMode(ReleaseMode.release);
        
        final Source source = path.startsWith('sounds/')
            ? AssetSource(path)
            : (path.startsWith('http://') ||
                    path.startsWith('https://') ||
                    path.startsWith('content://'))
                ? UrlSource(path)
                : DeviceFileSource(path);
            
        await _previewPlayer.play(source);
        setState(() {
          _previewingPath = path;
          _isPlayingPreview = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      MekaarSnackbar.error(context, 'Gagal memutar pratinjau: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefsState = ref.watch(notificationPreferencesProvider);

    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsTopBar(title: 'Nada & Suara'),

            Expanded(
              child: prefsState.when(
                data: (prefs) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      SoundPreferenceSection(
                        title: 'NADA NOTIFIKASI PESAN',
                        options: _messageSounds,
                        selectedPath: prefs.messageSound,
                        previewingPath: _previewingPath,
                        previewIsPlaying: _isPlayingPreview,
                        accentColor: MekaarColors.primaryOf(context),
                        enabled: prefs.messageSoundEnabled,
                        canDisable: true,
                        onSelected: (path) => ref
                            .read(notificationPreferencesProvider.notifier)
                            .updateMessageSound(path),
                        onPreview: _togglePreview,
                        onPickCustom: () => _pickDeviceSound(
                          type: RingtoneType.notification,
                          title: 'Pilih Nada Pesan',
                          onSelected: (path) => ref
                              .read(notificationPreferencesProvider.notifier)
                              .updateMessageSound(path),
                        ),
                        onEnabledChanged: (value) => ref
                            .read(notificationPreferencesProvider.notifier)
                            .toggleMessageSound(value),
                      ),
                      const SizedBox(height: 24),
                      SoundPreferenceSection(
                        title: 'NADA PANGGILAN',
                        options: _callSounds,
                        selectedPath: prefs.callSound,
                        previewingPath: _previewingPath,
                        previewIsPlaying: _isPlayingPreview,
                        accentColor: MekaarColors.guardianTeal,
                        enabled: prefs.callSoundEnabled,
                        canDisable: true,
                        onSelected: (path) => ref
                            .read(notificationPreferencesProvider.notifier)
                            .updateCallSound(path),
                        onPreview: _togglePreview,
                        onPickCustom: () => _pickDeviceSound(
                          type: RingtoneType.ringtone,
                          title: 'Pilih Nada Panggilan',
                          onSelected: (path) => ref
                              .read(notificationPreferencesProvider.notifier)
                              .updateCallSound(path),
                        ),
                        onEnabledChanged: (value) => ref
                            .read(notificationPreferencesProvider.notifier)
                            .toggleCallSound(value),
                      ),
                      const SizedBox(height: 24),
                      SoundPreferenceSection(
                        title: 'NADA ALARM DARURAT (SOS)',
                        options: _sosSounds,
                        selectedPath: prefs.sosSound,
                        previewingPath: _previewingPath,
                        previewIsPlaying: _isPlayingPreview,
                        accentColor: MekaarColors.sosRed,
                        enabled: true,
                        canDisable: false,
                        onSelected: (path) => ref
                            .read(notificationPreferencesProvider.notifier)
                            .updateSosSound(path),
                        onPreview: _togglePreview,
                        onPickCustom: () => _pickDeviceSound(
                          type: RingtoneType.alarm,
                          title: 'Pilih Nada Alarm Darurat',
                          onSelected: (path) => ref
                              .read(notificationPreferencesProvider.notifier)
                              .updateSosSound(path),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const SettingsSectionHeader(
                        title: 'RESPONS GETAR',
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                      ),
                      CustomCard(
                        margin: EdgeInsets.zero,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: SettingsSwitchTile(
                          icon: SolarIconsOutline.smartphoneVibration,
                          iconColor: MekaarColors.purpleLight,
                          title: 'Getaran (Haptics)',
                          value: prefs.hapticsEnabled,
                          onChanged: (value) => ref
                              .read(notificationPreferencesProvider.notifier)
                              .toggleHaptics(value),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
                loading: () => const MekaarStateView(
                  pose: MikaPose.neutral,
                  title: 'Memuat Preferensi Suara',
                  message: 'Sedang mengambil pengaturan nada & suara Anda...',
                ),
                error: (err, _) => MekaarStateView(
                  pose: ErrorResolver.resolvePose(err),
                  title: 'Gagal Memuat Pengaturan',
                  message: ErrorResolver.resolve(err),
                  actionLabel: 'Coba Lagi',
                  onAction: () =>
                      ref.invalidate(notificationPreferencesProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
