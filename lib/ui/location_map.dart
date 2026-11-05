import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

class LocationMap extends StatefulWidget {
  final LatLng? point;
  final ValueChanged<LatLng>? onSelect;
  final double height;
  const LocationMap({super.key, this.point, this.onSelect, this.height = 270});
  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  final controller = MapController();
  bool ready = false, tileError = false;
  int tileVersion = 0;
  @override
  void didUpdateWidget(covariant LocationMap old) {
    super.didUpdateWidget(old);
    if (ready && widget.point != old.point && widget.point != null) {
      controller.move(widget.point!, 16);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          Semantics(
            label: widget.onSelect != null
                ? 'Peta lokasi. Ketuk peta untuk memilih titik laporan.'
                : 'Peta titik lokasi laporan',
            child: FlutterMap(
              mapController: controller,
              options: MapOptions(
                initialCenter: widget.point ?? const LatLng(-2, 118),
                initialZoom: widget.point == null ? 4 : 16,
                minZoom: 3,
                maxZoom: 19,
                onMapReady: () => ready = true,
                onTap: widget.onSelect == null
                    ? null
                    : (_, point) => widget.onSelect!(point),
              ),
              children: [
                TileLayer(
                  key: ValueKey(tileVersion),
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'id.bilcode.siklus',
                  maxNativeZoom: 19,
                  errorTileCallback: (_, _, _) {
                    if (!tileError) {
                      Future.microtask(() {
                        if (mounted) setState(() => tileError = true);
                      });
                    }
                  },
                ),
                if (widget.point != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.point!,
                        width: 46,
                        height: 52,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_on,
                          color: forest,
                          size: 44,
                          semanticLabel: 'Titik laporan dipilih',
                        ),
                      ),
                    ],
                  ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (tileError)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Material(
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Peta gagal dimuat. Periksa internet.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Muat ulang peta',
                        onPressed: () => setState(() {
                          tileError = false;
                          tileVersion++;
                        }),
                        icon: const Icon(Icons.refresh, size: 19),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            right: 10,
            bottom: 40,
            child: Column(
              children: [
                _zoom(Icons.add, 1, 'Perbesar peta'),
                const SizedBox(height: 8),
                _zoom(Icons.remove, -1, 'Perkecil peta'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _zoom(IconData icon, int delta, String label) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(8),
    child: IconButton(
      tooltip: label,
      onPressed: () => controller.move(
        controller.camera.center,
        (controller.camera.zoom + delta).clamp(3, 19),
      ),
      icon: Icon(icon),
    ),
  );
}
