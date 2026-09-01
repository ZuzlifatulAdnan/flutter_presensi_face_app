import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_absensi_app/core/theme/app_theme.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_precheck_model.dart';

/// Peta presensi: posisi pengguna, pin kantor, dan lingkaran radius.
///
/// Tile dan zoom awal mengikuti `map.tile_url` / `map.default_zoom` dari
/// `pre-check`, sehingga admin bisa mengganti penyedia peta tanpa rilis baru.
class AttendanceMap extends StatefulWidget {
  final AttendancePreCheck data;
  final double? userLatitude;
  final double? userLongitude;

  const AttendanceMap({
    super.key,
    required this.data,
    this.userLatitude,
    this.userLongitude,
  });

  @override
  State<AttendanceMap> createState() => _AttendanceMapState();
}

class _AttendanceMapState extends State<AttendanceMap> {
  final MapController _controller = MapController();

  @override
  void didUpdateWidget(AttendanceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ikuti pergerakan pengguna tanpa mengganggu zoom yang sedang dipakai.
    final center = _center;
    if (center == null || center == _centerOf(oldWidget)) return;

    try {
      _controller.move(center, _controller.camera.zoom);
    } catch (_) {
      // Peta belum terpasang (build pertama masih menampilkan placeholder
      // karena lokasi belum ada); posisi awal sudah diatur `initialCenter`.
    }
  }

  LatLng? get _center => _centerOf(widget);

  LatLng? _centerOf(AttendanceMap w) {
    final lat = w.userLatitude ?? w.data.userLatitude;
    final lon = w.userLongitude ?? w.data.userLongitude;
    if (lat != null && lon != null) return LatLng(lat, lon);

    final nearest = w.data.nearestLocation;
    if (nearest != null) return LatLng(nearest.latitude, nearest.longitude);

    final first = w.data.locations.isEmpty ? null : w.data.locations.first;
    if (first != null) return LatLng(first.latitude, first.longitude);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final center = _center;
    if (center == null) return const _MapPlaceholder();

    final map = widget.data.map;

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: map.defaultZoom,
        minZoom: 3,
        maxZoom: 19,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: map.tileUrl,
          userAgentPackageName: 'com.jagoflutter.hris',
          maxZoom: 19,
        ),
        CircleLayer(circles: _radiusCircles()),
        MarkerLayer(markers: _officeMarkers()),
        if (widget.userLatitude != null && widget.userLongitude != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(widget.userLatitude!, widget.userLongitude!),
                width: 30,
                height: 30,
                child: const _UserDot(),
              ),
            ],
          ),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [TextSourceAttribution(map.attribution)],
        ),
      ],
    );
  }

  /// Lingkaran radius kantor — hijau bila pengguna di dalamnya, merah bila
  /// di luar, sesuai `within_radius` dari server.
  List<CircleMarker> _radiusCircles() {
    return widget.data.locations
        .where((location) => location.radiusMeters > 0)
        .map((location) {
      final color =
          location.withinRadius ? AppTheme.success : AppTheme.danger;
      return CircleMarker(
        point: LatLng(location.latitude, location.longitude),
        radius: location.radiusMeters,
        useRadiusInMeter: true,
        color: color.withValues(alpha: 0.14),
        borderColor: color.withValues(alpha: 0.6),
        borderStrokeWidth: 2,
      );
    }).toList();
  }

  List<Marker> _officeMarkers() {
    return widget.data.locations
        .map(
          (location) => Marker(
            point: LatLng(location.latitude, location.longitude),
            width: 132,
            height: 62,
            alignment: Alignment.topCenter,
            child: _OfficePin(location: location),
          ),
        )
        .toList();
  }
}

class _OfficePin extends StatelessWidget {
  final AttendanceLocation location;

  const _OfficePin({required this.location});

  @override
  Widget build(BuildContext context) {
    final color = location.withinRadius ? AppTheme.success : AppTheme.danger;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 6),
            ],
          ),
          child: Text(
            location.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 2),
        Icon(Icons.location_on_rounded, color: color, size: 30),
      ],
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      alignment: Alignment.center,
      child: const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 56, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text(
              'Peta belum bisa ditampilkan karena lokasi Anda dan lokasi '
              'kantor belum tersedia.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
