import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_map_preview.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/alarm_service.dart';
import '../../../data/services/supabase_service.dart';
import '../../settings/providers/connected_devices_provider.dart';
import '../providers/device_lost_provider.dart';

class DeviceLostScreen extends ConsumerStatefulWidget {
  const DeviceLostScreen({super.key});

  @override
  ConsumerState<DeviceLostScreen> createState() => _DeviceLostScreenState();
}

class _DeviceLostScreenState extends ConsumerState<DeviceLostScreen> {
  final _messageController = TextEditingController();
  final _contactController = TextEditingController();
  double? _lat;
  double? _lon;
  bool _isLoadingLocation = true;
  String? _locationError;
  bool _isAlarmPlaying = false;
  String? _selectedDeviceId; // null = semua perangkat / perangkat saat ini

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadLocation();
      ref.read(connectedDevicesProvider.notifier).load();
    });
    _isAlarmPlaying = AlarmService.isPlaying;

    final currentLostState = ref.read(deviceLostProvider);
    _messageController.text = currentLostState.lockMessage;
    _contactController.text = currentLostState.recoveryContact ?? '';
  }

  Future<void> _toggleAlarm() async {
    final userId = SupabaseService().currentUserId;
    final devicesState = ref.read(connectedDevicesProvider);
    final isTargetingCurrentDevice = _selectedDeviceId == null ||
        _selectedDeviceId == devicesState.currentDeviceId;

    final nextState = !_isAlarmPlaying;
    final command = nextState ? 'alarm' : 'stop_alarm';

    // Jika targetnya perangkat saat ini, jalankan lokal juga
    if (isTargetingCurrentDevice) {
      if (nextState) {
        await AlarmService.playSOSAlarm();
      } else {
        await AlarmService.stopAlarm();
      }
    }

    setState(() => _isAlarmPlaying = nextState);

    // Kirim remote command ke cloud
    if (userId != null) {
      try {
        final repo = ref.read(deviceLostRepositoryProvider);
        await repo.sendRemoteCommand(
          targetProfileId: userId,
          targetDeviceId: _selectedDeviceId,
          commandType: command,
        );
        if (mounted) {
          MekaarSnackbar.success(
            context,
            nextState
                ? (isTargetingCurrentDevice
                    ? 'Alarm berbunyi keras!'
                    : 'Perintah membunyikan alarm dikirim ke perangkat target.')
                : (isTargetingCurrentDevice
                    ? 'Alarm dimatikan.'
                    : 'Perintah menghentikan alarm dikirim ke perangkat target.'),
          );
        }
      } catch (e) {
        if (mounted && !isTargetingCurrentDevice) {
          MekaarSnackbar.error(context, 'Gagal mengirim perintah alarm: $e');
        }
      }
    }
  }

  Future<void> _loadLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
      _lat = null;
      _lon = null;
    });

    try {
      final locData = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _lat = locData?.latitude;
        _lon = locData?.longitude;
        _isLoadingLocation = false;
        _locationError = locData == null
            ? 'Lokasi tidak dapat diperoleh. Periksa izin dan koneksi GPS.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _locationError = 'Gagal memuat lokasi perangkat.';
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _openInOsm() async {
    if (_lat == null || _lon == null) {
      MekaarSnackbar.error(context, 'Lokasi tidak tersedia');
      return;
    }
    try {
      final url = LocationService.getOpenStreetMapUrl(_lat!, _lon!);
      final launched = await launchUrl(Uri.parse(url));
      if (!launched && mounted) {
        MekaarSnackbar.error(context, 'Gagal membuka OpenStreetMap');
      }
    } catch (e) {
      if (mounted) MekaarSnackbar.error(context, 'Gagal membuka OpenStreetMap');
    }
  }

  Future<void> _handleLockDevice() async {
    final msg = _messageController.text.trim();
    final contact = _contactController.text.trim();
    final userId = SupabaseService().currentUserId;
    final devicesState = ref.read(connectedDevicesProvider);
    final isTargetingCurrentDevice = _selectedDeviceId == null ||
        _selectedDeviceId == devicesState.currentDeviceId;

    // 1. Simpan lokal jika menargetkan perangkat saat ini
    if (isTargetingCurrentDevice) {
      await ref.read(deviceLostProvider.notifier).lockDevice(
            lockMessage: msg,
            recoveryContact: contact.isEmpty ? null : contact,
          );
    }

    // 2. Kirim remote command ke server
    if (userId != null) {
      try {
        final repo = ref.read(deviceLostRepositoryProvider);
        await repo.sendRemoteCommand(
          targetProfileId: userId,
          targetDeviceId: _selectedDeviceId,
          commandType: 'lock',
          payload: {
            'lockMessage': msg.isEmpty
                ? 'Ponsel ini hilang. Harap hubungi nomor darurat di layar.'
                : msg,
            'recoveryContact': contact.isEmpty ? null : contact,
          },
        );
      } catch (e) {
        if (mounted) {
          MekaarSnackbar.error(context, 'Gagal mengirim perintah kunci: $e');
        }
      }
    }

    if (!mounted) return;
    MekaarSnackbar.success(
      context,
      isTargetingCurrentDevice
          ? 'Pesan Layar Kunci disimpan. Mode Hilang Aktif!'
          : 'Perintah Kunci Layar dikirim ke perangkat target.',
    );

    if (isTargetingCurrentDevice) {
      Navigator.pushNamed(context, AppRoutes.deviceLostLock);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceLostState = ref.watch(deviceLostProvider);
    final connectedState = ref.watch(connectedDevicesProvider);

    return MekaarScaffold(
      flat: true,
      appBar: const CustomAppBar(title: 'Temukan Ponsel Saya'),
      body: Column(
        children: [
          // Peta OSM menampilkan posisi
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _isLoadingLocation
                      ? const MekaarStateView(
                          pose: MikaPose.neutral,
                          title: 'Mencari Lokasi',
                          message: 'Menentukan posisi perangkat Anda…',
                          illustrationSize: 96,
                          semanticLabel: 'Mencari lokasi perangkat',
                        )
                      : _locationError != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const MikaIllustration(
                                      pose: MikaPose.huft,
                                      size: 90,
                                      semanticLabel: 'Gagal memuat lokasi',
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _locationError!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color:
                                            MekaarColors.textSecondaryOf(context),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: _loadLocation,
                                      icon:
                                          const Icon(SolarIconsOutline.refresh),
                                      label: const Text('Coba Lagi'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Semantics(
                              label: 'Peta lokasi terakhir perangkat',
                              hint:
                                  'Menampilkan posisi lokasi pada koordinat $_lat, $_lon',
                              child: MekaarMapPreview(
                                center: LatLng(_lat!, _lon!),
                                zoom: 15,
                                interactive: true,
                                markerChild: const Icon(
                                  SolarIconsOutline.smartphone,
                                  color: MekaarColors.sosRed,
                                  size: 40,
                                ),
                              ),
                            ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _lat == null || _lon == null
                        ? 'Koordinat: -'
                        : 'Koordinat: $_lat, $_lon',
                    style: TextStyle(
                      fontSize: 12,
                      color: MekaarColors.textSecondaryOf(context),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Panel Perintah Jarak Jauh
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: MekaarColors.surfaceOf(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Perintah Jarak Jauh',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: MekaarColors.textPrimaryOf(context),
                    ),
                  ),

                  // Target Device Selector jika user memiliki > 1 device
                  if (connectedState.devices.length > 1) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: MekaarColors.surface2Of(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: MekaarColors.cardBorderOf(context)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedDeviceId,
                          isExpanded: true,
                          hint: const Text('Target: Semua Perangkat'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Semua Perangkat Terdaftar'),
                            ),
                            ...connectedState.devices.map(
                              (d) => DropdownMenuItem<String?>(
                                value: d.deviceId,
                                child: Text(
                                  '${d.deviceLabel ?? d.platform} ${d.deviceId == connectedState.currentDeviceId ? '(Perangkat ini)' : ''}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedDeviceId = val);
                          },
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(SolarIconsOutline.volumeLoud),
                          label: Text(_isAlarmPlaying
                              ? 'Matikan Alarm'
                              : 'Bunyikan Alarm'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isAlarmPlaying
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                            foregroundColor: _isAlarmPlaying
                                ? Theme.of(context).colorScheme.onError
                                : Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _toggleAlarm,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(SolarIconsOutline.map),
                      label: const Text('Buka di OpenStreetMap'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _openInOsm,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pesan Kunci Layar (Mode Hilang)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: MekaarColors.textPrimaryOf(context),
                        ),
                      ),
                      if (deviceLostState.isLocked)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: MekaarColors.sosRed.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Mode Terkunci Aktif',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: MekaarColors.sosRed,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText:
                          'Misal: Ponsel ini hilang. Hubungi 08123456789 jika menemukan.',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _contactController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText:
                          'Nomor HP Pemulihan (opsional, mis. 08123456789)',
                      prefixIcon: Icon(SolarIconsOutline.phone),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _handleLockDevice,
                          icon: const Icon(SolarIconsOutline.lockKeyhole),
                          label: Text(
                            deviceLostState.isLocked
                                ? 'Perbarui & Buka Layar Kunci'
                                : 'Kirim & Kunci Layar',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MekaarColors.sosRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      if (deviceLostState.isLocked) ...[
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.deviceLostLock,
                            );
                          },
                          icon: const Icon(SolarIconsOutline.eye),
                          tooltip: 'Tampilkan Layar Terkunci',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
