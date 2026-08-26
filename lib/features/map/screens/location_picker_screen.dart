import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_map_preview.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/nominatim_service.dart';

class LocationPickerResult {
  final LatLng location;
  final String? labelHint;

  const LocationPickerResult({
    required this.location,
    this.labelHint,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final int radiusMeters;
  final String title;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.radiusMeters = 150,
    this.title = 'Pilih Lokasi Tujuan di Peta',
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const String _historyKey = 'location_search_history';
  static const int _historyLimit = 5;

  late MapController _mapController;
  late LatLng _selectedLocation;
  bool _isLoadingGps = false;

  // ── Pencarian lokasi (Nominatim) + riwayat lokal ──
  final NominatimService _nominatim = NominatimService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  List<GeocodingResult> _suggestions = [];
  List<GeocodingResult> _history = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Default awal jika lokasi belum dikirim
    _selectedLocation =
        widget.initialLocation ?? const LatLng(-6.2088, 106.8456);

    // Ambil lokasi GPS fisik real-time saat layar pertama dibuka jika
    // tidak ada lokasi awal.
    if (widget.initialLocation == null) {
      _fetchCurrentGpsLocation();
    }
    _loadHistory();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nominatim.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentGpsLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      final locData = await LocationService.getCurrentLocation();
      if (locData != null &&
          locData.latitude != null &&
          locData.longitude != null) {
        final currentGps = LatLng(locData.latitude!, locData.longitude!);
        setState(() {
          _selectedLocation = currentGps;
        });
        _mapController.move(currentGps, 16.5);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedLocation = latLng;
    });
  }

  // ── Riwayat pencarian (lokal saja, cap 5, LRU) ──

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
    // Format: "label|lat|lon"
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
    // Entri terbaru di depan; buang duplikat; cap 5.
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

  // ── Pencarian Nominatim dengan debounce ──

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }
    // Debounce ≥400ms — kebijakan rate-limit Nominatim maks 1 req/detik.
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
      _selectedLocation = result.location;
      _suggestions = [];
      _searchController.clear();
    });
    _mapController.move(result.location, 16.5);
    _addToHistory(result);
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = MekaarColors.surfaceOf(context);

    return MekaarScaffold(
      flat: true,
      appBar: CustomAppBar(
        title: widget.title,
        subtitle: 'Ketuk peta atau cari nama tempat untuk menentukan lokasi',
      ),
      body: Stack(
        children: [
          // Peta interaktif: tap memindahkan pin, circle geofence ikut.
          MekaarMapPreview(
            center: _selectedLocation,
            zoom: 16,
            radiusMeters: widget.radiusMeters.toDouble(),
            interactive: true,
            onMapTap: _onMapTap,
            markerChild: Icon(
              SolarIconsBold.mapPoint,
              color: MekaarColors.accentOf(context),
              size: 44,
            ),
          ),

          // Search bar floating + riwayat / saran hasil.
          Positioned(
            top: MekaarSpacing.md,
            left: MekaarSpacing.md,
            right: MekaarSpacing.md + 56,
            child: Column(
              children: [
                CustomCard(
                  margin: EdgeInsets.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: MekaarSpacing.md),
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
                            hintText: 'Cari alamat atau nama tempat...',
                            hintStyle: MekaarTypography.bodySM.copyWith(
                              color: MekaarColors.textMutedOf(context),
                            ),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            filled: false,
                            fillColor: Colors.transparent,
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
                    margin:
                        const EdgeInsets.only(top: MekaarSpacing.xs),
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
              heroTag: 'my_location_btn',
              backgroundColor: surfaceColor,
              foregroundColor: MekaarColors.accentTextOf(context),
              onPressed: () {
                HapticFeedback.selectionClick();
                _fetchCurrentGpsLocation();
              },
              child: _isLoadingGps
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MekaarColors.accentTextOf(context)),
                    )
                  : const Icon(SolarIconsBold.gps, size: 20),
            ),
          ),

          // Floating Info & Selection Bar di bagian bawah
          Positioned(
            left: MekaarSpacing.md,
            right: MekaarSpacing.md,
            bottom: MekaarSpacing.lg,
            child: CustomCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(MekaarSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MekaarColors.accentOf(context)
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          SolarIconsBold.mapPointSearch,
                          color: MekaarColors.accentOf(context),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: MekaarSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Koordinat Dipilih',
                              style: MekaarTypography.bodySM.copyWith(
                                  color: MekaarColors.textMutedOf(context)),
                            ),
                            Text(
                              '${_selectedLocation.latitude.toStringAsFixed(5)}, ${_selectedLocation.longitude.toStringAsFixed(5)}',
                              style: MekaarTypography.bodyMD
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MekaarSpacing.sm),
                  Text(
                    'Radius Geofence: ${widget.radiusMeters} meter (ditampilkan lingkaran biru)',
                    style: MekaarTypography.bodySM.copyWith(
                        color: MekaarColors.textMutedOf(context)),
                  ),
                  const SizedBox(height: MekaarSpacing.md),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(
                          context,
                          LocationPickerResult(location: _selectedLocation),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text(
                        'Konfirmasi Lokasi Ini',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _showOverlay =>
      (_searchController.text.isEmpty && _history.isNotEmpty) ||
      _suggestions.isNotEmpty ||
      (_isSearching);

  Widget _buildSearchOverlay() {
    final isHistoryMode =
        _searchController.text.isEmpty && !_isSearching && _suggestions.isEmpty;
    final items = isHistoryMode ? _history : _suggestions;
    final showNoResults =
        !isHistoryMode && !_isSearching && items.isEmpty;

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
}
