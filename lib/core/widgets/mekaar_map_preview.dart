import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/colors.dart';

/// Peta OSM terbungkus card — satu sumber implementasi preview lokasi.
///
/// Dipakai di:
/// - Preview titik tujuan Auto Check-In (`AddTripScreen`) — read-only,
///   tap membuka full picker, circle geofence live mengikuti slider.
/// - "Temukan Ponsel Saya" (`DeviceLostScreen`) — konteks darurat,
///   marker ikon smartphone `sosRed`, tanpa circle.
///
/// Konvensi warna sesuai design.md §7/§9: aksen `brand.blue` untuk
/// konteks rutin; warna darurat (`sos.coral`/`sosRed`) hanya via
/// [markerChild] yang dibawa pemanggil.
class MekaarMapPreview extends StatelessWidget {
  final LatLng center;
  final double zoom;

  /// Radius geofence dalam meter. Null = tidak merender [CircleLayer].
  final double? radiusMeters;

  /// Widget bebas sebagai isi marker (ikon pin / smartphone dsb).
  final Widget? markerChild;

  /// False = gesture peta dimatikan (preview read-only di dalam form),
  /// seluruh tap diteruskan ke [onTap]. True = peta interaktif penuh
  /// dan [onMapTap] menerima koordinat titik yang diketuk.
  final bool interactive;
  final VoidCallback? onTap;
  final void Function(TapPosition tapPosition, LatLng latLng)? onMapTap;

  const MekaarMapPreview({
    super.key,
    required this.center,
    this.zoom = 16,
    this.radiusMeters,
    this.markerChild,
    this.interactive = false,
    this.onTap,
    this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = MekaarColors.accentOf(context);

    Widget map = FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        // Preview read-only: matikan semua gesture peta.
        interactionOptions: interactive
            ? const InteractionOptions(flags: InteractiveFlag.all)
            : const InteractionOptions(flags: InteractiveFlag.none),
        onTap: interactive ? onMapTap : (_, _) => onTap?.call(),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.mekaar.app',
        ),
        // Atribusi OSM (kepatuhan lisensi tile) — wajib ada di semua peta.
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              '© OpenStreetMap contributors',
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
              ),
            ),
          ],
        ),
        if (radiusMeters != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: center,
                radius: radiusMeters!,
                useRadiusInMeter: true,
                color: accent.withValues(alpha: 0.12),
                borderColor: accent,
                borderStrokeWidth: 1.5,
              ),
            ],
          ),
        if (markerChild != null)
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 50,
                height: 50,
                child: markerChild!,
              ),
            ],
          ),
      ],
    );

    if (!interactive && onTap != null) {
      map = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AbsorbPointer(child: map),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(width: double.infinity, child: map),
    );
  }
}
