import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../settings/providers/block_provider.dart';

class ContactSettingsScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String chatName;
  final String chatAvatar;
  final String otherUserId;
  final bool isGuardian;

  const ContactSettingsScreen({
    super.key,
    required this.roomId,
    required this.chatName,
    required this.chatAvatar,
    required this.otherUserId,
    this.isGuardian = false,
  });

  @override
  ConsumerState<ContactSettingsScreen> createState() => _ContactSettingsScreenState();
}

class _ContactSettingsScreenState extends ConsumerState<ContactSettingsScreen> {
  bool _isMuted = false;
  int? _disappearingOverrideHours;
  bool _isLoading = true;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final repo = ref.read(chatRepositoryProvider);
    final prefs = await repo.getRoomPreferences(widget.roomId);
    final blocked = await ref.read(blockRepositoryProvider).isBlocked(widget.otherUserId);
    if (!mounted) return;
    setState(() {
      _isMuted = prefs?.isMuted ?? false;
      _disappearingOverrideHours = prefs?.disappearingOverrideHours;
      _isBlocked = blocked;
      _isLoading = false;
    });
  }

  Future<void> _toggleMute(bool muted) async {
    setState(() => _isMuted = muted);
    await ref.read(chatRepositoryProvider).updateRoomMute(widget.roomId, muted);
  }

  Future<void> _setDisappearing(int? hours) async {
    setState(() => _disappearingOverrideHours = hours);
    await ref.read(chatRepositoryProvider).updateRoomDisappearingOverride(widget.roomId, hours);
  }

  Future<void> _toggleBlock() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MekaarColors.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _isBlocked ? 'Buka Blokir?' : 'Blokir ${widget.chatName}?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          _isBlocked
              ? 'Anda akan menerima pesan dari ${widget.chatName} lagi.'
              : 'Blokir ${widget.chatName}? Anda tidak akan menerima pesan dari kontak ini.',
          style: const TextStyle(color: MekaarColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: MekaarColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (_isBlocked) {
                await ref.read(blockProvider.notifier).unblockUser(widget.otherUserId);
              } else {
                await ref.read(blockProvider.notifier).blockUser(widget.otherUserId);
              }
              if (!mounted) return;
              setState(() => _isBlocked = !_isBlocked);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isBlocked ? MekaarColors.guardianTeal : MekaarColors.sosRed,
              foregroundColor: Colors.white,
            ),
            child: Text(_isBlocked ? 'Buka Blokir' : 'Blokir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MekaarScaffold(
      appBar: AppBar(
        title: const Text('Info Kontak'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                // Avatar & Nama
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: MekaarColors.softCoral.withValues(alpha: 0.15),
                        child: Text(
                          widget.chatAvatar.isNotEmpty ? widget.chatAvatar : widget.chatName[0],
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: MekaarColors.softCoral,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.chatName,
                        style: MekaarTypography.headingMD.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (widget.isGuardian) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(SolarIconsOutline.shieldUser, size: 14, color: MekaarColors.guardianTeal),
                            const SizedBox(width: 4),
                            const Text('Guardian', style: TextStyle(color: MekaarColors.guardianTeal, fontSize: 12)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Pengaturan Privasi
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Pengaturan Privasi',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: MekaarColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Mute
                _buildSwitchTile(
                  icon: SolarIconsOutline.bellOff,
                  title: 'Bisukan Notifikasi',
                  subtitle: 'Nonaktifkan suara notifikasi dari chat ini',
                  value: _isMuted,
                  onChanged: _toggleMute,
                ),

                // Disappearing messages
                _buildDisappearingTile(),

                const Divider(height: 40, indent: 20, endIndent: 20),

                // Tindakan
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Tindakan',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: MekaarColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Hapus Chat
                ListTile(
                  leading: const Icon(SolarIconsOutline.trashBinTrash, color: MekaarColors.sosRed),
                  title: const Text('Hapus Chat'),
                  titleTextStyle: const TextStyle(color: MekaarColors.sosRed),
                  onTap: () {
                    MekaarDialog.showConfirmation<void>(
                      context: context,
                      title: 'Hapus Chat?',
                      message: 'Obrolan akan hilang dari daftar chat Anda.',
                      isDestructive: true,
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Batal'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MekaarColors.sosRed,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            await ref.read(chatRepositoryProvider).deleteChat(widget.roomId);
                            if (mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: const Text('Hapus'),
                        ),
                      ],
                    );
                  },
                ),

                // Blokir
                ListTile(
                  leading: Icon(
                    SolarIconsOutline.dangerTriangle,
                    color: _isBlocked ? MekaarColors.guardianTeal : MekaarColors.sosCoral,
                  ),
                  title: Text(_isBlocked ? 'Buka Blokir Kontak' : 'Blokir Kontak'),
                  onTap: _toggleBlock,
                ),
              ],
            ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: MekaarColors.warnAmber),
      title: Text(title, style: MekaarTypography.labelLG),
      subtitle: Text(subtitle, style: MekaarTypography.bodySM),
      value: value,
      activeTrackColor: MekaarColors.guardianTeal,
      onChanged: onChanged,
    );
  }

  Widget _buildDisappearingTile() {
    final profile = ref.watch(authProvider).profile;
    final globalHours = profile?.autoDeleteDefaultHours ?? 0;
    final current = _disappearingOverrideHours;
    final label = current != null
        ? _formatDuration(current)
        : (globalHours > 0 ? 'Global (${_formatDuration(globalHours)})' : 'Nonaktif');

    return ListTile(
      leading: const Icon(SolarIconsOutline.clockCircle, color: MekaarColors.info),
      title: const Text('Pesan Menghilang'),
      subtitle: Text(label, style: MekaarTypography.bodySM),
      trailing: const Icon(SolarIconsOutline.altArrowRight, size: 18, color: MekaarColors.textMuted),
      onTap: () => _showDisappearingPicker(),
    );
  }

  void _showDisappearingPicker() {
    final profile = ref.read(authProvider).profile;
    final globalHours = profile?.autoDeleteDefaultHours ?? 0;
    final current = _disappearingOverrideHours;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MekaarColors.surfaceOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: MekaarColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Pesan Menghilang Chat Ini', style: MekaarTypography.headingSM),
            const SizedBox(height: 4),
            Text(
              'Mengganti pengaturan global (${globalHours > 0 ? _formatDuration(globalHours) : "nonaktif"})',
              style: MekaarTypography.bodySM.copyWith(color: MekaarColors.textMuted),
            ),
            const SizedBox(height: 16),
            if (globalHours > 0)
              _pickerOption(ctx, 'Gunakan Global (${_formatDuration(globalHours)})', null, current == null),
            _pickerOption(ctx, 'Nonaktif', 0, current == 0),
            _pickerOption(ctx, '1 Jam', 1, current == 1),
            _pickerOption(ctx, '24 Jam', 24, current == 24),
            _pickerOption(ctx, '7 Hari', 168, current == 168),
            _pickerOption(ctx, '30 Hari', 720, current == 720),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _pickerOption(BuildContext ctx, String label, int? hours, bool selected) {
    return ListTile(
      title: Text(label, style: MekaarTypography.labelLG),
      trailing: selected ? const Icon(SolarIconsOutline.checkCircle, color: MekaarColors.guardianTeal) : null,
      onTap: () {
        Navigator.pop(ctx);
        _setDisappearing(hours);
      },
    );
  }

  String _formatDuration(int hours) {
    if (hours <= 0) return 'Nonaktif';
    if (hours < 24) return '$hours jam';
    if (hours < 168) return '${hours ~/ 24} hari';
    return '${hours ~/ 24} hari';
  }
}
