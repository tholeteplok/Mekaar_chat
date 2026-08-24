import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/icons.dart';
import '../../../core/constants/typography.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_map_preview.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/models/saved_place_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/nominatim_service.dart';
import '../providers/trip_provider.dart';

class AddTripScreen extends ConsumerStatefulWidget {
  const AddTripScreen({super.key});

  @override
  ConsumerState<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends ConsumerState<AddTripScreen> {
  static const String _historyKey = 'location_search_history';
  static const int _historyLimit = 5;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController(text: 'Pulang Kerja');
  final _destLabelController = TextEditingController(text: 'Rumah');
  final _expectedTimeController = TextEditingController(text: '18:30');

  // ── Map & Location State ──
  late MapController _mapController;
  LatLng? _destinationLocation;
  bool _isLoadingGps = false;

  // ── Pencarian Lokasi (Nominatim) + Riwayat Lokal ──
  final NominatimService _nominatim = NominatimService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  List<GeocodingResult> _suggestions = [];
  List<GeocodingResult> _history = [];
  bool _isSearching = false;

  // ── Form Trip Configuration State ──
  String _originChoice = '📍 Lokasi Saat Ini';
  int _radiusMeters = 150;
  final int _gracePeriodMinutes = 30;
  final List<int> _selectedActiveDays = [1, 2, 3, 4, 5, 6, 7]; // 1 = Sen, 7 = Min
  final List<String> _selectedGuardianIds = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _destinationLocation = const LatLng(-6.2088, 106.8456); // Default Jakarta
    _fetchRealGpsLocation();
    _loadHistory();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nominatim.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _titleController.dispose();
    _destLabelController.dispose();
    _expectedTimeController.dispose();
    super.dispose();
  }

  Future<void> _fetchRealGpsLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      final locData = await LocationService.getCurrentLocation();
      if (locData != null &&
          locData.latitude != null &&
          locData.longitude != null) {
        final realGps = LatLng(locData.latitude!, locData.longitude!);
        setState(() {
          _destinationLocation = realGps;
        });
        _mapController.move(realGps, 16.0);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    HapticFeedback.lightImpact();
    _searchFocusNode.unfocus();
    setState(() {
      _destinationLocation = latLng;
    });
  }

  // ── Riwayat Pencarian (Lokal SharedPreferences, Cap 5) ──

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_historyKey) ?? [];
      final items = raw
          .map(_decodeHistoryEntry)
          .whereType<GeocodingResult>()
          .toList();
      if (mounted) setState(() => _history = items);
    } catch (_) {}
  }

  GeocodingResult? _decodeHistoryEntry(String entry) {
    final parts = entry.split('|');
    if (parts.length < 3) return null;
    final lat = double.tryParse(parts[1]);
    final lon = double.tryParse(parts[2]);
    if (lat == null || lon == null) return null;
    return GeocodingResult(
      label: parts[0],
      latitude: lat,
      longitude: lon,
    );
  }

  String _encodeHistoryEntry(GeocodingResult r) =>
      '${r.label}|${r.latitude}|${r.longitude}';

  Future<void> _addToHistory(GeocodingResult result) async {
    final updated = [result]
        .followedBy(_history.where((h) =>
            h.label != result.label ||
            h.latitude != result.latitude ||
            h.longitude != result.longitude))
        .take(_historyLimit)
        .toList();
    setState(() => _history = updated);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _historyKey,
        updated.map(_encodeHistoryEntry).toList(),
      );
    } catch (_) {}
  }

  Future<void> _clearHistory() async {
    setState(() => _history = []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (_) {}
  }

  // ── Pencarian Nominatim dengan Debounce ──

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearching = true);
      final results = await _nominatim.search(query);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    });
  }

  void _applySearchResult(GeocodingResult result) {
    HapticFeedback.selectionClick();
    _searchFocusNode.unfocus();
    setState(() {
      _destinationLocation = result.location;
      _destLabelController.text = result.label;
      _suggestions = [];
      _searchController.clear();
    });
    _mapController.move(result.location, 16.0);
    _addToHistory(result);
  }

  void _handleBookmarkChipTap(
    String id,
    String name,
    Map<String, SavedPlace> savedPlacesMap,
  ) {
    HapticFeedback.selectionClick();
    _destLabelController.text = name;

    final existingPlace = savedPlacesMap[id];
    if (existingPlace != null) {
      final target = LatLng(existingPlace.latitude, existingPlace.longitude);
      setState(() {
        _destinationLocation = target;
      });
      _mapController.move(target, 16.0);
      if (mounted) {
        MekaarSnackbar.success(
          context,
          'Titik koordinat "$name" dimuat dari Lokasi Tersimpan!',
        );
      }
    } else {
      if (mounted) {
        MekaarSnackbar.info(
          context,
          'Preset "$name" belum memiliki koordinat tersimpan. Ketuk peta atau cari lokasi di search bar.',
        );
      }
    }
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_destinationLocation == null) {
      MekaarSnackbar.error(
          context, 'Silakan tentukan titik lokasi tujuan terlebih dahulu pada peta!');
      return;
    }

    if (_selectedGuardianIds.isEmpty) {
      MekaarSnackbar.error(
          context, 'Pilih minimal satu Guardian penerima notifikasi!');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final destZone = TripZone(
        label: _destLabelController.text.trim().isNotEmpty
            ? _destLabelController.text.trim()
            : 'Tujuan',
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

      ref.invalidate(userTripsProvider);

      if (mounted) {
        MekaarSnackbar.success(context,
            'Rute Perjalanan "${_titleController.text.trim()}" berhasil diaktifkan!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal menyimpan rute perjalanan: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool get _showOverlay =>
      (_searchController.text.isEmpty && _history.isNotEmpty) ||
      _suggestions.isNotEmpty ||
      (_isSearching);

  Widget _buildSearchOverlay() {
    final isHistoryMode =
        _searchController.text.isEmpty && !_isSearching && _suggestions.isEmpty;
    final items = isHistoryMode ? _history : _suggestions;
    final showNoResults = !isHistoryMode && !_isSearching && items.isEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: MekaarSpacing.md, vertical: MekaarSpacing.xs),
          child: Row(
            children: [
              Text(
                isHistoryMode ? 'Pencarian Terakhir' : 'Hasil Pencarian',
                style: MekaarTypography.labelMD.copyWith(
                  color: MekaarColors.textMutedOf(context),
                ),
              ),
              const Spacer(),
              if (isHistoryMode && items.isNotEmpty)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _clearHistory,
                  child: Padding(
                    padding: const EdgeInsets.all(MekaarSpacing.xs),
                    child: Text(
                      'Hapus riwayat',
                      style: MekaarTypography.labelMD.copyWith(
                        color: MekaarColors.sosRed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ...items.map((item) => ListTile(
              dense: true,
              leading: Icon(
                isHistoryMode
                    ? SolarIconsOutline.history
                    : SolarIconsOutline.mapPoint,
                size: 20,
                color: MekaarColors.textSecondaryOf(context),
              ),
              title: Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MekaarTypography.bodySM.copyWith(
                  color: MekaarColors.textPrimaryOf(context),
                ),
              ),
              onTap: () => _applySearchResult(item),
            )),
        if (showNoResults)
          Padding(
            padding: const EdgeInsets.all(MekaarSpacing.md),
            child: Text(
              'Tidak ada hasil ditemukan.',
              style: MekaarTypography.bodySM.copyWith(
                color: MekaarColors.textMutedOf(context),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final guardiansAsync = ref.watch(activeGuardiansProvider);
    final savedPlacesAsync = ref.watch(savedPlacesProvider);
    final screenHeight = MediaQuery.of(context).size.height;

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
      appBar: const CustomAppBar(title: 'Tambah Rute Perjalanan'),
      body: Column(
        children: [
          // ── Bagian Atas: Peta Hero Interaktif + Floating Search Bar ──
          Expanded(
            child: Stack(
              children: [
                MekaarMapPreview(
                  mapController: _mapController,
                  center: _destinationLocation ?? const LatLng(-6.2088, 106.8456),
                  zoom: 15.5,
                  interactive: true,
                  borderRadius: BorderRadius.zero,
                  radiusMeters: _radiusMeters.toDouble(),
                  onMapTap: _onMapTap,
                  markerChild: Icon(
                    SolarIconsBold.mapPoint,
                    color: MekaarColors.accentOf(context),
                    size: 44,
                  ),
                ),

                // Floating Search Bar & Suggestions Overlay
                Positioned(
                  top: MekaarSpacing.md,
                  left: MekaarSpacing.md,
                  right: MekaarSpacing.md + 54,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomCard(
                        margin: EdgeInsets.zero,
                        padding: const EdgeInsets.symmetric(
                            horizontal: MekaarSpacing.md),
                        child: Row(
                          children: [
                            Icon(
                              SolarIconsOutline.magnifier,
                              size: 20,
                              color: MekaarColors.textMutedOf(context),
                            ),
                            const SizedBox(width: MekaarSpacing.sm),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                onChanged: _onSearchChanged,
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: 'Cari alamat / tempat tujuan...',
                                  hintStyle: MekaarTypography.bodySM.copyWith(
                                    color: MekaarColors.textMutedOf(context),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: MekaarTypography.bodyMD.copyWith(
                                  color: MekaarColors.textPrimaryOf(context),
                                ),
                              ),
                            ),
                            if (_isSearching)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            else if (_searchController.text.isNotEmpty)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  SolarIconsOutline.closeCircle,
                                  size: 18,
                                  color: MekaarColors.textMutedOf(context),
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              ),
                          ],
                        ),
                      ),
                      if (_showOverlay)
                        CustomCard(
                          margin: const EdgeInsets.only(top: MekaarSpacing.xs),
                          padding: const EdgeInsets.symmetric(
                              vertical: MekaarSpacing.xs),
                          child: _buildSearchOverlay(),
                        ),
                    ],
                  ),
                ),

                // Tombol Re-center GPS (Lokasi Saya)
                Positioned(
                  top: MekaarSpacing.md,
                  right: MekaarSpacing.md,
                  child: FloatingActionButton.small(
                    heroTag: 'add_trip_gps_recenter_btn',
                    backgroundColor: MekaarColors.surfaceOf(context),
                    foregroundColor: MekaarColors.accentTextOf(context),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _fetchRealGpsLocation();
                    },
                    child: _isLoadingGps
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: MekaarColors.accentTextOf(context),
                            ),
                          )
                        : const Icon(SolarIconsBold.gps, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // ── Bagian Bawah: Kartu Formulir Rute Perjalanan ──
          Container(
            decoration: BoxDecoration(
              color: MekaarColors.surfaceOf(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.52,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle indikator scroll halus
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: MekaarColors.textMutedOf(context)
                              .withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // 1. Nama Perjalanan
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Perjalanan',
                        hintText: 'Contoh: Pulang Kerja, Ke Kampus',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(SolarIconsOutline.routing,
                            color: MekaarColors.cyan),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nama perjalanan wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: MekaarSpacing.md),

                    // 2. Lokasi Asal (Preset Chips Real-Time GPS)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lokasi Asal:',
                          style: MekaarTypography.bodyMD
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (_isLoadingGps)
                          Row(
                            children: [
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: MekaarColors.cyan),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Deteksi GPS...',
                                style: MekaarTypography.bodySM
                                    .copyWith(color: MekaarColors.cyan),
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
                            color: isSelected
                                ? MekaarColors.cyan
                                : MekaarColors.surface2Of(context),
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

                    // 3. Lokasi Tujuan (Presets & Label)
                    Text(
                      'Label Lokasi Tujuan:',
                      style: MekaarTypography.bodyMD
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: MekaarSpacing.xs),
                    TextFormField(
                      controller: _destLabelController,
                      decoration: const InputDecoration(
                        labelText: 'Nama / Label Tujuan',
                        hintText: 'Contoh: Rumah, Kos, Kantor',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(SolarIconsOutline.mapPoint,
                            color: MekaarColors.cyan),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Label tujuan wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: MekaarSpacing.sm),

                    // Chips Preset Lokasi Tersimpan
                    savedPlacesAsync.when(
                      data: (savedPlacesMap) {
                        final presets = [
                          {
                            'id': 'home',
                            'name': 'Rumah',
                            'icon': SolarIconsOutline.home
                          },
                          {
                            'id': 'office',
                            'name': 'Kantor',
                            'icon': SolarIconsOutline.buildings
                          },
                          {
                            'id': 'campus',
                            'name': 'Kampus',
                            'icon': SolarIconsOutline.squareAcademicCap
                          },
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
                                color: isSaved
                                    ? MekaarColors.cyan
                                    : MekaarColors.textMutedOf(context),
                              ),
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(name),
                                  if (isSaved) ...[
                                    const SizedBox(width: 4),
                                    const Icon(MekaarIcons.checkCircle,
                                        size: 12, color: MekaarColors.cyan),
                                  ],
                                ],
                              ),
                              backgroundColor: isSaved
                                  ? MekaarColors.cyan.withValues(alpha: 0.1)
                                  : null,
                              side: BorderSide(
                                color: isSaved
                                    ? MekaarColors.cyan
                                    : MekaarColors.surface2Of(context),
                              ),
                              onPressed: () => _handleBookmarkChipTap(
                                  id, name, savedPlacesMap),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (err, stack) => const SizedBox(),
                    ),
                    const SizedBox(height: MekaarSpacing.md),

                    // 4. Radius Geofence (Live Connected ke Peta Atas)
                    Text(
                      'Radius Geofence: $_radiusMeters meter',
                      style: MekaarTypography.bodyMD
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    Slider(
                      value: _radiusMeters.toDouble(),
                      min: 100,
                      max: 500,
                      divisions: 8,
                      label: '$_radiusMeters m',
                      activeColor: MekaarColors.cyan,
                      onChanged: (val) =>
                          setState(() => _radiusMeters = val.toInt()),
                    ),
                    const SizedBox(height: MekaarSpacing.md),

                    // 5. Hari Aktif (Recurring Days)
                    Text(
                      'Hari Aktif Rute Perjalanan:',
                      style: MekaarTypography.bodyMD
                          .copyWith(fontWeight: FontWeight.bold),
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
                          selectedColor:
                              MekaarColors.cyan.withValues(alpha: 0.25),
                          checkmarkColor: MekaarColors.cyan,
                          side: BorderSide(
                            color: isSelected
                                ? MekaarColors.cyan
                                : MekaarColors.surface2Of(context),
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

                    // 6. Estimasi Waktu Tiba (TimePicker)
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
                            prefixIcon: Icon(SolarIconsOutline.clockCircle,
                                color: MekaarColors.cyan),
                            suffixIcon: Icon(SolarIconsOutline.altArrowDown,
                                color: MekaarColors.cyan),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Estimasi waktu wajib diisi';
                            }
                            final parts = v.trim().split(':');
                            if (parts.length != 2) {
                              return 'Format waktu tidak valid (HH:mm)';
                            }
                            final h = int.tryParse(parts[0]);
                            final m = int.tryParse(parts[1]);
                            if (h == null ||
                                m == null ||
                                h < 0 ||
                                h > 23 ||
                                m < 0 ||
                                m > 59) {
                              return 'Waktu tidak valid';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: MekaarSpacing.md),

                    // 7. Pemilih Guardian Penerima
                    Text(
                      'Pilih Guardian Penerima Auto Check-In:',
                      style: MekaarTypography.bodyMD
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: MekaarSpacing.xs),
                    guardiansAsync.when(
                      data: (guardians) {
                        if (guardians.isEmpty) {
                          return Text(
                            'Belum ada Guardian aktif. Tambahkan Guardian terlebih dahulu di menu Guardian.',
                            style: MekaarTypography.bodySM
                                .copyWith(color: MekaarColors.sosCoral),
                          );
                        }
                        return Column(
                          children: guardians.map<Widget>((g) {
                            final isSelected =
                                _selectedGuardianIds.contains(g.guardianId);
                            return CheckboxListTile(
                              title: Text(g.name),
                              subtitle: Text(
                                  g.email.isNotEmpty ? g.email : 'Guardian'),
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
                      error: (err, _) => Text(
                        ErrorResolver.resolve(err),
                        style: MekaarTypography.caption.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: MekaarSpacing.xl),

                    // Tombol Simpan
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: MekaarColors.textOnBlue,
                          shape: const StadiumBorder(),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: MekaarColors.textOnBlue)
                            : const Text('Simpan Rute Perjalanan',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
