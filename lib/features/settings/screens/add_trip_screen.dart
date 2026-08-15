import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/icons.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/models/saved_place_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/saved_places_repository.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../data/services/location_service.dart';
import '../../map/screens/location_picker_screen.dart';
import '../providers/trip_provider.dart';

class AddTripScreen extends ConsumerStatefulWidget {
  const AddTripScreen({super.key});

  @override
  ConsumerState<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends ConsumerState<AddTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController(text: 'Pulang Kerja');
  final _destLabelController = TextEditingController(text: 'Rumah');
  final _expectedTimeController = TextEditingController(text: '18:30');

  String _originChoice = '📍 Lokasi Saat Ini';
  LatLng? _destinationLocation;
  bool _isLoadingGps = false;

  int _radiusMeters = 150;
  final int _gracePeriodMinutes = 30;
  final List<int> _selectedActiveDays = [1, 2, 3, 4, 5, 6, 7]; // 1 = Mon, 7 = Sun
  final List<String> _selectedGuardianIds = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchRealGpsLocation();
  }

  Future<void> _fetchRealGpsLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      final locData = await LocationService.getCurrentLocation();
      if (locData != null && locData.latitude != null && locData.longitude != null) {
        final realGps = LatLng(locData.latitude!, locData.longitude!);
        setState(() {
          _destinationLocation ??= realGps;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _destLabelController.dispose();
    _expectedTimeController.dispose();
    super.dispose();
  }

  Future<void> _selectExpectedTime() async {
    HapticFeedback.selectionClick();
    TimeOfDay initial = const TimeOfDay(hour: 18, minute: 30);
    final parts = _expectedTimeController.text.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        initial = TimeOfDay(hour: h, minute: m);
      }
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox(),
        );
      },
    );

    if (picked != null) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      setState(() {
        _expectedTimeController.text = '$hh:$mm';
      });
    }
  }

  Future<void> _openMapPicker({String? autoSaveId, String? autoSaveName}) async {
    HapticFeedback.selectionClick();
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.mapPicker,
      arguments: _radiusMeters,
    );

    if (result is LocationPickerResult) {
      setState(() {
        _destinationLocation = result.location;
        if (result.labelHint != null && result.labelHint!.isNotEmpty) {
          _destLabelController.text = result.labelHint!;
        }
      });

      if (autoSaveId != null && autoSaveName != null) {
        final savedPlace = SavedPlace(
          id: autoSaveId,
          name: autoSaveName,
          iconName: autoSaveId,
          latitude: result.location.latitude,
          longitude: result.location.longitude,
          updatedAt: DateTime.now(),
        );
        await ref.read(savedPlacesRepositoryProvider).savePlace(savedPlace);
        ref.invalidate(savedPlacesProvider);
        if (mounted) {
          MekaarSnackbar.success(
            context,
            'Lokasi "$autoSaveName" berhasil disimpan secara permanen!',
          );
        }
      } else {
        if (mounted) {
          MekaarSnackbar.info(
            context,
            'Lokasi tujuan diperbarui dari peta: ${result.location.latitude.toStringAsFixed(4)}, ${result.location.longitude.toStringAsFixed(4)}',
          );
        }
      }
    }
  }

  Future<void> _handleBookmarkChipTap(
    String id,
    String name,
    Map<String, SavedPlace> savedPlacesMap,
  ) async {
    HapticFeedback.selectionClick();
    _destLabelController.text = name;

    final existingPlace = savedPlacesMap[id];
    if (existingPlace != null) {
      setState(() {
        _destinationLocation = LatLng(existingPlace.latitude, existingPlace.longitude);
      });
      MekaarSnackbar.success(
        context,
        'Koordinat tersimpan "$name" diterapkan (${existingPlace.latitude.toStringAsFixed(4)}, ${existingPlace.longitude.toStringAsFixed(4)})',
      );
    } else {
      MekaarSnackbar.info(
        context,
        'Lokasi "$name" belum memiliki titik koordinat tersimpan. Tentukan di peta.',
      );
      await _openMapPicker(autoSaveId: id, autoSaveName: name);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_destinationLocation == null) {
      MekaarSnackbar.error(context, 'Silakan pilih lokasi tujuan di peta terlebih dahulu');
      return;
    }
    if (_selectedActiveDays.isEmpty) {
      MekaarSnackbar.error(context, 'Pilih minimal 1 hari aktif rute perjalanan');
      return;
    }
    if (_selectedGuardianIds.isEmpty) {
      MekaarSnackbar.error(context, 'Pilih minimal 1 Guardian penerima Auto Check-In');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final destZone = TripZone(
        label: _destLabelController.text.trim(),
        latitude: _destinationLocation!.latitude,
        longitude: _destinationLocation!.longitude,
        radiusMeters: _radiusMeters,
      );

      final guardians = _selectedGuardianIds
          .map((id) => TripGuardianPermission(id: '', guardianId: id))
          .toList();

      await ref.read(tripRepositoryProvider).createTrip(
            title: _titleController.text.trim(),
            originLabel: _originChoice,
            destinationZone: destZone,
            expectedTime: _expectedTimeController.text.trim(),
            gracePeriodMinutes: _gracePeriodMinutes,
            activeDays: _selectedActiveDays,
            guardians: guardians,
          );

      if (mounted) {
        ref.invalidate(userTripsProvider);
        MekaarSnackbar.success(context, 'Rute perjalanan berhasil disimpan!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal menyimpan rute: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guardiansAsync = ref.watch(activeGuardiansProvider);
    final savedPlacesAsync = ref.watch(savedPlacesProvider);

    final String latStr = _destinationLocation?.latitude.toStringAsFixed(4) ?? 'Belum ditentukan';
    final String lngStr = _destinationLocation?.longitude.toStringAsFixed(4) ?? 'Belum ditentukan';

    const dayLabels = {
      1: 'Sen',
      2: 'Sel',
      3: 'Rab',
      4: 'Kam',
      5: 'Jum',
      6: 'Sab',
      7: 'Min',
    };

    return MekaarScaffold(
      flat: true,
      appBar: const CustomAppBar(
        title: 'Tambah Rute Beacon',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(MekaarSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Nama Perjalanan
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Nama Perjalanan',
                  hintText: 'Contoh: Pulang Kerja, Ke Kampus',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(SolarIconsOutline.routing, color: MekaarColors.cyan),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Nama perjalanan wajib diisi' : null,
              ),
              const SizedBox(height: MekaarSpacing.md),

              // 2. Lokasi Asal (Preset Chips Real-Time GPS)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lokasi Asal:',
                    style: MekaarTypography.bodyMD.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (_isLoadingGps)
                    Row(
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: MekaarColors.cyan),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Deteksi GPS...',
                          style: MekaarTypography.bodySM.copyWith(color: MekaarColors.cyan),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: MekaarSpacing.xs),
              Wrap(
                spacing: 8,
                children: [
                  '📍 Lokasi Saat Ini',
                  '🏢 Kantor',
                  '🏠 Rumah',
                ].map((choice) {
                  final isSelected = _originChoice == choice;
                  return ChoiceChip(
                    label: Text(choice),
                    selected: isSelected,
                    selectedColor: MekaarColors.cyan.withValues(alpha: 0.2),
                    side: BorderSide(
                      color: isSelected ? MekaarColors.cyan : MekaarColors.surface2Of(context),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        HapticFeedback.selectionClick();
                        setState(() => _originChoice = choice);
                        if (choice == '📍 Lokasi Saat Ini') {
                          _fetchRealGpsLocation();
                        }
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: MekaarSpacing.md),

              // 3. Lokasi Tujuan (Real Saved Bookmarks + Interactive Map)
              Text(
                'Label Lokasi Tujuan:',
                style: MekaarTypography.bodyMD.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: MekaarSpacing.xs),
              TextFormField(
                controller: _destLabelController,
                decoration: const InputDecoration(
                  labelText: 'Nama / Label Tujuan',
                  hintText: 'Contoh: Rumah, Kos, Kantor',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(SolarIconsOutline.mapPoint, color: MekaarColors.sosCoral),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Label tujuan wajib diisi' : null,
              ),
              const SizedBox(height: MekaarSpacing.sm),

              // Chips Bookmark Lokasi Tersimpan Asli
              savedPlacesAsync.when(
                data: (savedPlacesMap) {
                  final presets = [
                    {'id': 'home', 'name': 'Rumah', 'icon': SolarIconsOutline.home},
                    {'id': 'office', 'name': 'Kantor', 'icon': SolarIconsOutline.buildings},
                    {'id': 'campus', 'name': 'Kampus', 'icon': SolarIconsOutline.squareAcademicCap},
                  ];

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((preset) {
                      final id = preset['id'] as String;
                      final name = preset['name'] as String;
                      final icon = preset['icon'] as IconData;
                      final isSaved = savedPlacesMap.containsKey(id);

                      return ActionChip(
                        avatar: Icon(
                          isSaved ? MekaarIcons.bookmarkAdded : icon,
                          size: 16,
                          color: isSaved ? MekaarColors.cyan : MekaarColors.textMutedOf(context),
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name),
                            if (isSaved) ...[
                              const SizedBox(width: 4),
                              const Icon(MekaarIcons.checkCircle, size: 12, color: MekaarColors.cyan),
                            ],
                          ],
                        ),
                        backgroundColor: isSaved ? MekaarColors.cyan.withValues(alpha: 0.1) : null,
                        side: BorderSide(
                          color: isSaved ? MekaarColors.cyan : MekaarColors.surface2Of(context),
                        ),
                        onPressed: () => _handleBookmarkChipTap(id, name, savedPlacesMap),
                      );
                    }).toList(),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (err, stack) => const SizedBox(),
              ),
              const SizedBox(height: MekaarSpacing.md),

              // 4. Kartu Titik Lokasi Tujuan di Peta Real-Time
              CustomCard(
                padding: const EdgeInsets.all(MekaarSpacing.md),
                border: Border.all(color: MekaarColors.cyan.withValues(alpha: 0.3)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: MekaarColors.cyan.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            SolarIconsBold.mapPoint,
                            color: MekaarColors.cyan,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: MekaarSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Titik Koordinat Tujuan Physical',
                                style: MekaarTypography.bodySM.copyWith(color: MekaarColors.textMutedOf(context)),
                              ),
                              Text(
                                '$latStr, $lngStr',
                                style: MekaarTypography.bodyMD.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MekaarSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () => _openMapPicker(),
                      icon: const Icon(SolarIconsBold.mapPointSearch, color: MekaarColors.cyan, size: 18),
                      label: const Text('🗺️ Pilih Lokasi Tujuan di Peta'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MekaarColors.cyan,
                        side: const BorderSide(color: MekaarColors.cyan),
                        minimumSize: const Size.fromHeight(44),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MekaarSpacing.md),

              // 5. Radius Geofence
              Text(
                'Radius Geofence: $_radiusMeters meter',
                style: MekaarTypography.bodyMD.copyWith(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _radiusMeters.toDouble(),
                min: 100,
                max: 500,
                divisions: 8,
                label: '$_radiusMeters m',
                activeColor: MekaarColors.cyan,
                onChanged: (val) => setState(() => _radiusMeters = val.toInt()),
              ),
              const SizedBox(height: MekaarSpacing.md),

              // 6. Hari Aktif (Recurring Days)
              Text(
                'Hari Aktif Rute Perjalanan:',
                style: MekaarTypography.bodyMD.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: MekaarSpacing.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: dayLabels.entries.map((entry) {
                  final dayInt = entry.key;
                  final dayName = entry.value;
                  final isSelected = _selectedActiveDays.contains(dayInt);
                  return FilterChip(
                    label: Text(dayName),
                    selected: isSelected,
                    selectedColor: MekaarColors.cyan.withValues(alpha: 0.25),
                    checkmarkColor: MekaarColors.cyan,
                    side: BorderSide(
                      color: isSelected ? MekaarColors.cyan : MekaarColors.surface2Of(context),
                    ),
                    onSelected: (selected) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (selected) {
                          _selectedActiveDays.add(dayInt);
                        } else {
                          _selectedActiveDays.remove(dayInt);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: MekaarSpacing.md),

              // 7. Estimasi Waktu Tiba (TimePicker)
              InkWell(
                onTap: _selectExpectedTime,
                borderRadius: BorderRadius.circular(8),
                child: IgnorePointer(
                  child: TextFormField(
                    controller: _expectedTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Estimasi Waktu Tiba (WIB)',
                      hintText: '18:30',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(SolarIconsOutline.clockCircle, color: MekaarColors.cyan),
                      suffixIcon: Icon(SolarIconsOutline.altArrowDown, color: MekaarColors.cyan),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Estimasi waktu wajib diisi';
                      final parts = v.trim().split(':');
                      if (parts.length != 2) return 'Format waktu tidak valid (HH:mm)';
                      final h = int.tryParse(parts[0]);
                      final m = int.tryParse(parts[1]);
                      if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
                        return 'Waktu tidak valid';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: MekaarSpacing.md),

              // 8. Pemilih Guardian Penerima
              Text(
                'Pilih Guardian Penerima Auto Check-In:',
                style: MekaarTypography.bodyMD.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: MekaarSpacing.xs),
              guardiansAsync.when(
                data: (guardians) {
                  if (guardians.isEmpty) {
                    return Text(
                      'Belum ada Guardian aktif. Tambahkan Guardian terlebih dahulu di menu Guardian.',
                      style: MekaarTypography.bodySM.copyWith(color: MekaarColors.sosCoral),
                    );
                  }
                  return Column(
                    children: guardians.map<Widget>((g) {
                      final isSelected = _selectedGuardianIds.contains(g.guardianId);
                      return CheckboxListTile(
                        title: Text(g.name),
                        subtitle: Text(g.email.isNotEmpty ? g.email : 'Guardian'),
                        value: isSelected,
                        activeColor: MekaarColors.cyan,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedGuardianIds.add(g.guardianId);
                            } else {
                              _selectedGuardianIds.remove(g.guardianId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (err, _) => Text('Gagal memuat guardian: $err'),
              ),
              const SizedBox(height: MekaarSpacing.xl),

              // Tombol Simpan
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: MekaarColors.textOnYellow,
                    shape: const StadiumBorder(),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: MekaarColors.textOnYellow)
                      : const Text('Simpan Rute Perjalanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
