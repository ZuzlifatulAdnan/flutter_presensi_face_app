import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_absensi_app/core/config/app_config.dart';
import 'package:flutter_absensi_app/core/theme/app_theme.dart';

/// Peta satu titik — dipakai untuk melihat lokasi absen dari riwayat.
///
/// Memakai `flutter_map` dengan tile yang dikonfigurasi admin lewat
/// `/api/app-settings` (`map.tile_url`), sehingga berjalan di Android, iOS,
/// dan web tanpa API key Google Maps.
class LocationPage extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final String? title;
  final String? address;

  const LocationPage({
    super.key,
    this.latitude,
    this.longitude,
    this.title,
    this.address,
  });

  @override
  Widget build(BuildContext context) {
    final lat = latitude;
    final lon = longitude;

    if (lat == null || lon == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title ?? 'Lokasi')),
        body: const _EmptyLocation(),
      );
    }

    final settings = AppConfig.map;
    final point = LatLng(lat, lon);

    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Lokasi Presensi')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: settings.defaultZoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: settings.tileUrl,
                userAgentPackageName: 'com.jagoflutter.hris',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 44,
                    height: 44,
                    child: const _LocationPin(),
                  ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(settings.attribution),
                ],
              ),
            ],
          ),
          if (address != null && address!.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _AddressCard(
                address: address!,
                latitude: lat,
                longitude: lon,
              ),
            ),
        ],
      ),
    );
  }
}

class _LocationPin extends StatelessWidget {
  const _LocationPin();

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
            color: color.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.person_pin_circle_rounded,
          color: Colors.white, size: 22),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final String address;
  final double latitude;
  final double longitude;

  const _AddressCard({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.place_rounded,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${latitude.toStringAsFixed(6)}, '
                    '${longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLocation extends StatelessWidget {
  const _EmptyLocation();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_rounded,
                size: 56, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text(
              'Koordinat presensi ini tidak tersedia.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
