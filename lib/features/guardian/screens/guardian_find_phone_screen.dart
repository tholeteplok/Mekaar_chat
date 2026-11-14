import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_banner.dart';
import '../../../core/widgets/mekaar_map_preview.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_top_bar.dart';
import '../../../data/models/guardian_model.dart';
import '../../../data/services/supabase_service.dart';
import '../../sos/providers/device_lost_provider.dart';

/// Layar penuh kontrol pemulihan perangkat bagi Guardian (Borderless Canvas-First).
///
/// Memungkinkan Guardian untuk:
/// 1. Membunyikan sirine hardware secara jarak jauh (menembus Silent & DND).
/// 2. Mengirimkan pesan layar kunci dan kontak pemulihan.
/// 3. Meminta dan melihat koordinat lokasi GPS terakhir ponsel korban.
class GuardianFindPhoneScreen extends ConsumerStatefulWidget {
  final Guardian guardian;
  final String targetUserId;

  const GuardianFindPhoneScreen({
    super.key,
    required this.guardian,
    required this.targetUserId,
  });

  @override
  ConsumerState<GuardianFindPhoneScreen> createState() =>
      _GuardianFindPhoneScreenState();
}

class _GuardianFindPhoneScreenState
    extends ConsumerState<GuardianFindPhoneScreen> {
  final _messageController = TextEditingController();
  final _contactController = TextEditingController();

  bool _isSendingAlarm = false;
  bool _isAlarmActive = false;
  bool _isSendingLock = false;
  bool _isRequestingLocation = false;

  double? _targetLat;
  double? _targetLon;
  DateTime? _locatedAt;

  Timer? _statusPollTimer;

  @override
  void initState() {
    super.initState();
    _messageController.text =
        'Ponsel ini tertinggal. Harap hubungi nomor darurat di layar.';
    _loadLatestStatus();
    _startPolling();
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    _messageController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _statusPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _loadLatestStatus();
    });
  }

  Future<void> _loadLatestStatus() async {
    if (!SupabaseService.isInitialized) return;
    try {
      final client = SupabaseService().client;
      final rows = await client
          .from('device_commands')
          .select('command_type, status, payload, executed_at, created_at')
          .eq('target_profile_id', widget.targetUserId)
          .order('created_at', ascending: false)
          .limit(5);

      if (!mounted) return;

      for (final r in (rows as List)) {
        final type = r['command_type'] as String?;
        final status = r['status'] as String?;
        final payload = r['payload'] as Map<String, dynamic>?;

        if (type == 'alarm' && status != 'failed' && status != 'expired') {
          final createdAt = DateTime.tryParse(r['created_at'] ?? '');
          if (createdAt != null &&
              DateTime.now().difference(createdAt).inMinutes < 3) {
            if (!_isAlarmActive) {
              setState(() => _isAlarmActive = true);
            }
          }
        }

        if (type == 'stop_alarm') {
          final stopTime = DateTime.tryParse(r['created_at'] ?? '');
          if (stopTime != null &&
              DateTime.now().difference(stopTime).inMinutes < 3) {
            if (_isAlarmActive) {
              setState(() => _isAlarmActive = false);
            }
          }
        }

        if (type == 'locate' && payload != null) {
          final lat = (payload['latitude'] as num?)?.toDouble();
          final lon = (payload['longitude'] as num?)?.toDouble();
          final locTimeStr = payload['located_at'] as String?;
          if (lat != null && lon != null) {
            setState(() {
              _targetLat = lat;
              _targetLon = lon;
              if (locTimeStr != null) {
                _locatedAt = DateTime.tryParse(locTimeStr);
              }
            });
            break;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleAlarm() async {
    HapticService.trigger(MekaarHapticIntent.emergency);
    final repo = ref.read(deviceLostRepositoryProvider);
    final nextAlarm = !_isAlarmActive;

    setState(() => _isSendingAlarm = true);

    try {
      if (nextAlarm) {
        await repo.sendRemoteCommand(
          targetProfileId: widget.targetUserId,
          commandType: 'alarm',
          payload: {
            'recoveryContact': _contactController.text.trim(),
            'senderName': widget.guardian.name,
            'lockMessage':
                '⚠️ PERINGATAN PEMULIHAN PONSEL\nGuardian Anda (${widget.guardian.name}) membunyikan sirine untuk membantu menemukan perangkat ini.',
          },
        );
        if (mounted) {
          setState(() {
            _isAlarmActive = true;
            _isSendingAlarm = false;
          });
          MekaarSnackbar.success(
            context,
            'Perintah sirine berhasil dikirim ke ponsel ${widget.guardian.name}.',
          );
        }
      } else {
        await repo.sendRemoteCommand(
          targetProfileId: widget.targetUserId,
          commandType: 'stop_alarm',
        );
        if (mounted) {
          setState(() {
            _isAlarmActive = false;
            _isSendingAlarm = false;
          });
          MekaarSnackbar.success(
            context,
            'Perintah menghentikan sirine telah dikirim.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingAlarm = false);
        MekaarSnackbar.error(
          context,
          'Gagal mengirim perintah sirine: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  Future<void> _sendLockCommand() async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final message = _messageController.text.trim();
    final contact = _contactController.text.trim();

    if (contact.isEmpty) {
      MekaarSnackbar.error(
        context,
        'Harap masukkan nomor kontak pemulihan yang bisa dihubungi penemu ponsel.',
      );
      return;
    }

    setState(() => _isSendingLock = true);

    try {
      final repo = ref.read(deviceLostRepositoryProvider);
      await repo.sendRemoteCommand(
        targetProfileId: widget.targetUserId,
        commandType: 'lock',
        payload: {
          'lockMessage': message.isNotEmpty
              ? message
              : 'Ponsel ini tertinggal. Harap hubungi nomor darurat di layar.',
          'recoveryContact': contact,
          'senderName': widget.guardian.name,
        },
      );

      if (mounted) {
        setState(() => _isSendingLock = false);
        MekaarSnackbar.success(
          context,
          'Pesan layar kunci & kontak pemulihan berhasil disiarkan ke ponsel ${widget.guardian.name}.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingLock = false);
        MekaarSnackbar.error(
          context,
          'Gagal mengirim perintah kunci layar: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  Future<void> _requestLocation() async {
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() => _isRequestingLocation = true);

    try {
      final repo = ref.read(deviceLostRepositoryProvider);
      await repo.sendRemoteCommand(
        targetProfileId: widget.targetUserId,
        commandType: 'locate',
      );

      if (mounted) {
        MekaarSnackbar.info(
          context,
          'Permintaan koordinat GPS telah dikirim. Menunggu respons perangkat...',
        );
      }

      for (var i = 0; i < 5; i++) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        await _loadLatestStatus();
        if (_targetLat != null && _targetLon != null) break;
      }

      if (mounted) {
        setState(() => _isRequestingLocation = false);
        if (_targetLat != null && _targetLon != null) {
          MekaarSnackbar.success(
            context,
            'Koordinat GPS terkini berhasil diterima!',
          );
        } else {
          MekaarSnackbar.info(
            context,
            'Perintah telah terkirim. Lokasi akan otomatis diperbarui saat ponsel menerima sinyal.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRequestingLocation = false);
        MekaarSnackbar.error(
          context,
          'Gagal meminta lokasi: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  Future<void> _openInMaps(double lat, double lon) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal membuka aplikasi peta.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MekaarColors.isDarkContext(context);
    final isGpsPermitted = widget.guardian.permissions['gps'] ?? false;

    return MekaarScaffold(
      flat: true,
      appBar: const MekaarTopBar(title: 'Bantu Temukan Ponsel'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ──── Banner Edukasi Zero-2FA Recovery ────
            MekaarBanner(
              color: MekaarColors.primaryOf(context),
              icon: SolarIconsOutline.shieldCheck,
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(14),
              content: Text(
                'Aksi pemulihan dikirim melalui kanal data berprioritas tinggi. '
                'Sirine akan menembus mode Hening/DND dan otomatis berhenti setelah 3 menit demi keselamatan baterai.',
                style: MekaarTypography.bodySM.copyWith(
                  color: MekaarColors.textSecondaryOf(context),
                  height: 1.4,
                ),
              ),
            ),

            // ──── Seksi 1: Bunyikan Sirine Jarak Jauh ────
            _buildSectionContainer(
              context: context,
              isDark: isDark,
              highlightColor: _isAlarmActive
                  ? MekaarColors.sosRed.withValues(alpha: 0.12)
                  : null,
              borderColor: _isAlarmActive
                  ? MekaarColors.sosRed.withValues(alpha: 0.4)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _isAlarmActive
                            ? SolarIconsBold.bellBing
                            : SolarIconsOutline.volumeLoud,
                        color: MekaarColors.sosRed,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isAlarmActive
                                  ? 'Sirine Sedang Berbunyi'
                                  : 'Bunyikan Sirine Jarak Jauh',
                              style: MekaarTypography.labelLG.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _isAlarmActive
                                    ? MekaarColors.sosRed
                                    : MekaarColors.textPrimaryOf(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Memutar alarm darurat pada volume 100% di level perangkat keras untuk menemukan ponsel yang terselip/tertinggal.',
                              style: MekaarTypography.bodySM.copyWith(
                                color: MekaarColors.textSecondaryOf(context),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAlarmActive
                            ? MekaarColors.surface2Of(context)
                            : MekaarColors.sosRed,
                        foregroundColor: _isAlarmActive
                            ? MekaarColors.sosRed
                            : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MekaarRadius.md),
                          side: _isAlarmActive
                              ? const BorderSide(
                                  color: MekaarColors.sosRed,
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                      ),
                      onPressed: _isSendingAlarm ? null : _toggleAlarm,
                      icon: _isSendingAlarm
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isAlarmActive
                                  ? SolarIconsOutline.stopCircle
                                  : SolarIconsOutline.bell,
                              size: 20,
                            ),
                      label: Text(
                        _isAlarmActive
                            ? 'Hentikan Sirine'
                            : 'Bunyikan Sirine Sekarang',
                        style: MekaarTypography.labelLG.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ──── Seksi 2: Kunci Layar & Kontak Pemulihan ────
            _buildSectionContainer(
              context: context,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        SolarIconsOutline.lockPassword,
                        color: MekaarColors.warnAmber,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kunci Layar & Kontak Pemulihan',
                              style: MekaarTypography.labelLG.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Siarkan notifikasi persisten di layar kunci dengan tombol telepon langsung ke nomor Anda.',
                              style: MekaarTypography.bodySM.copyWith(
                                color: MekaarColors.textSecondaryOf(context),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contactController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Nomor Kontak Anda (Guardian)',
                      hintText: 'Contoh: 081234567890',
                      prefixIcon: const Icon(SolarIconsOutline.phone, size: 20),
                      filled: true,
                      fillColor: MekaarColors.surface2Of(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MekaarRadius.md),
                        borderSide: BorderSide(
                          color: MekaarColors.borderOf(context),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MekaarRadius.md),
                        borderSide: BorderSide(
                          color: MekaarColors.borderOf(context),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MekaarRadius.md),
                        borderSide: BorderSide(
                          color: MekaarColors.primaryOf(context),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _messageController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Pesan untuk Penemu Ponsel',
                      hintText: 'Ponsel tertinggal...',
                      prefixIcon: const Icon(SolarIconsOutline.notes, size: 20),
                      filled: true,
                      fillColor: MekaarColors.surface2Of(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MekaarRadius.md),
                        borderSide: BorderSide(
                          color: MekaarColors.borderOf(context),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MekaarRadius.md),
                        borderSide: BorderSide(
                          color: MekaarColors.borderOf(context),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MekaarRadius.md),
                        borderSide: BorderSide(
                          color: MekaarColors.primaryOf(context),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MekaarColors.primaryOf(context),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MekaarRadius.md),
                        ),
                      ),
                      onPressed: _isSendingLock ? null : _sendLockCommand,
                      icon: _isSendingLock
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              SolarIconsOutline.shieldKeyhole,
                              size: 20,
                            ),
                      label: Text(
                        'Kirim Kunci Layar & Kontak',
                        style: MekaarTypography.labelLG.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ──── Seksi 3: Permintaan & Preview Lokasi GPS Terkini ────
            _buildSectionContainer(
              context: context,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        SolarIconsOutline.mapPointWave,
                        color: MekaarColors.info,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Titik Lokasi GPS Terkini',
                              style: MekaarTypography.labelLG.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isGpsPermitted
                                  ? 'Minta koordinat GPS langsung dari perangkat target.'
                                  : 'Izin GPS dari ${widget.guardian.name} saat ini belum aktif.',
                              style: MekaarTypography.bodySM.copyWith(
                                color: MekaarColors.textSecondaryOf(context),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_targetLat != null && _targetLon != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                      child: SizedBox(
                        height: 180,
                        child: MekaarMapPreview(
                          center: LatLng(_targetLat!, _targetLon!),
                          zoom: 16,
                          markerChild: const Icon(
                            SolarIconsOutline.smartphone,
                            size: 30,
                            color: MekaarColors.sosRed,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _locatedAt != null
                              ? 'Diterima: ${_locatedAt!.hour.toString().padLeft(2, '0')}:${_locatedAt!.minute.toString().padLeft(2, '0')}'
                              : 'Koordinat: ${_targetLat!.toStringAsFixed(4)}, ${_targetLon!.toStringAsFixed(4)}',
                          style: MekaarTypography.labelSM.copyWith(
                            color: MekaarColors.textMutedOf(context),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () =>
                              _openInMaps(_targetLat!, _targetLon!),
                          icon: const Icon(
                            SolarIconsOutline.mapArrowSquare,
                            size: 16,
                          ),
                          label: const Text('Buka Maps'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MekaarColors.textPrimaryOf(context),
                        side: BorderSide(
                          color: MekaarColors.borderOf(context),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MekaarRadius.md),
                        ),
                      ),
                      onPressed:
                          _isRequestingLocation ? null : _requestLocation,
                      icon: _isRequestingLocation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(SolarIconsOutline.gps, size: 20),
                      label: Text(
                        _targetLat != null
                            ? 'Perbarui Titik Lokasi'
                            : 'Minta Koordinat GPS Sekarang',
                        style: MekaarTypography.labelLG.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContainer({
    required BuildContext context,
    required bool isDark,
    required Widget child,
    Color? highlightColor,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlightColor ?? MekaarColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(MekaarRadius.lg),
        border: Border.all(
          color: borderColor ?? MekaarColors.borderOf(context),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}
