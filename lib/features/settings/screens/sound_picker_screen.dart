import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../data/models/notification_preferences.dart';
import '../providers/notification_preferences_provider.dart';
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
    SoundOption('Chime Default', NotificationPreferences.defaultMessageSound),
    SoundOption('Playful Pop', 'sounds/normal_playful.mp3'),
  ];
  final List<SoundOption> _callSounds = const [
    SoundOption('Playful Ring', NotificationPreferences.defaultCallSound),
    SoundOption('Chime Ring', NotificationPreferences.defaultMessageSound),
  ];
  final List<SoundOption> _sosSounds = const [
    SoundOption('Sirine Darurat', NotificationPreferences.defaultSosSound),
    SoundOption('Klakson Ambulans', 'sounds/sos_klaxon.mp3'),
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

  Future<void> _pickCustomFile(void Function(String) onSelected) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result != null && result.files.single.path != null) {
        onSelected(result.files.single.path!);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih file: $e')),
      );
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
            : DeviceFileSource(path);
            
        await _previewPlayer.play(source);
        setState(() {
          _previewingPath = path;
          _isPlayingPreview = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memutar pratinjau: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefsState = ref.watch(notificationPreferencesProvider);

    return MekaarScaffold(
      appBar: const CustomAppBar(title: 'Nada & Suara'),
      body: prefsState.when(
        data: (prefs) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SoundPreferenceSection(
                title: 'NADA NOTIFIKASI PESAN',
                options: _messageSounds,
                selectedPath: prefs.messageSound,
                previewingPath: _previewingPath,
                previewIsPlaying: _isPlayingPreview,
                accentColor: MekaarColors.softCoral,
                enabled: prefs.messageSoundEnabled,
                canDisable: true,
                onSelected: (path) => ref.read(notificationPreferencesProvider.notifier).updateMessageSound(path),
                onPreview: _togglePreview,
                onPickCustom: () => _pickCustomFile((path) => ref.read(notificationPreferencesProvider.notifier).updateMessageSound(path)),
                onEnabledChanged: (value) => ref.read(notificationPreferencesProvider.notifier).toggleMessageSound(value),
              ),
              const SizedBox(height: 28),
              SoundPreferenceSection(
                title: 'NADA PANGGILAN',
                options: _callSounds,
                selectedPath: prefs.callSound,
                previewingPath: _previewingPath,
                previewIsPlaying: _isPlayingPreview,
                accentColor: MekaarColors.safeTeal,
                enabled: prefs.callSoundEnabled,
                canDisable: true,
                onSelected: (path) => ref.read(notificationPreferencesProvider.notifier).updateCallSound(path),
                onPreview: _togglePreview,
                onPickCustom: () => _pickCustomFile((path) => ref.read(notificationPreferencesProvider.notifier).updateCallSound(path)),
                onEnabledChanged: (value) => ref.read(notificationPreferencesProvider.notifier).toggleCallSound(value),
              ),
              const SizedBox(height: 28),
              SoundPreferenceSection(
                title: 'NADA ALARM DARURAT (SOS)',
                options: _sosSounds,
                selectedPath: prefs.sosSound,
                previewingPath: _previewingPath,
                previewIsPlaying: _isPlayingPreview,
                accentColor: MekaarColors.sosRed,
                enabled: true,
                canDisable: false,
                onSelected: (path) => ref.read(notificationPreferencesProvider.notifier).updateSosSound(path),
                onPreview: _togglePreview,
                onPickCustom: () => _pickCustomFile((path) => ref.read(notificationPreferencesProvider.notifier).updateSosSound(path)),
              ),
              const SizedBox(height: 20),
              SwitchListTile.adaptive(
                title: const Text('Haptic feedback'),
                subtitle: const Text('Getaran untuk aksi penting dan status panggilan'),
                value: prefs.hapticsEnabled,
                onChanged: (value) => ref.read(notificationPreferencesProvider.notifier).toggleHaptics(value),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
