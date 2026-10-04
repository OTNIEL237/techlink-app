import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';

// =========================================================================
// ÉCRAN DE LA CARTE DE LOCALISATION DU CLIENT
// =========================================================================
// Permet au technicien de visualiser la position du client sur la carte, 
// de voir sa propre position, et de lancer la navigation GPS.

class ClientLocationMapScreen extends StatefulWidget {
  final double clientLat;
  final double clientLng;
  final String clientName;
  final String missionCategory;

  const ClientLocationMapScreen({
    super.key,
    required this.clientLat,
    required this.clientLng,
    required this.clientName,
    required this.missionCategory,
  });

  @override
  State<ClientLocationMapScreen> createState() =>
      _ClientLocationMapScreenState();
}

class _ClientLocationMapScreenState extends State<ClientLocationMapScreen> {
  final MapController _mapController = MapController();
  Position? _techPosition;
  bool _loadingLocation = true;
  double _currentZoom = 15.0;

  @override
  void initState() {
    super.initState();
    _fetchTechPosition();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchTechPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      if (mounted) setState(() => _techPosition = pos);
    } catch (_) {}
    if (mounted) setState(() => _loadingLocation = false);
  }

  Future<void> _openGoogleMaps() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${widget.clientLat},${widget.clientLng}'
      '&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir Google Maps'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  double _distanceKm() {
    if (_techPosition == null) return -1;
    final d = Geolocator.distanceBetween(
      _techPosition!.latitude,
      _techPosition!.longitude,
      widget.clientLat,
      widget.clientLng,
    );
    return d / 1000;
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(3.0, 19.0);
      _mapController.move(
        LatLng(widget.clientLat, widget.clientLng),
        _currentZoom,
      );
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(3.0, 19.0);
      _mapController.move(
        LatLng(widget.clientLat, widget.clientLng),
        _currentZoom,
      );
    });
  }

  void _centerOnClient() {
    _mapController.move(
      LatLng(widget.clientLat, widget.clientLng),
      15.0,
    );
    setState(() => _currentZoom = 15.0);
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final clientLatLng = LatLng(widget.clientLat, widget.clientLng);
    final dist = _distanceKm();

    final markers = <Marker>[
      // 📍 Marker client (rouge)
      Marker(
        point: clientLatLng,
        width: 56,
        height: 68,
        child: _ClientMarker(name: widget.clientName),
      ),
      // 🔵 Marker technicien (bleu) si GPS disponible
      if (_techPosition != null)
        Marker(
          point: LatLng(_techPosition!.latitude, _techPosition!.longitude),
          width: 44,
          height: 44,
          child: const _TechMarker(),
        ),
    ];

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        backgroundColor: tc.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Localisation du client',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tc.textPrimary),
            ),
            Text(
              widget.missionCategory,
              style: TextStyle(
                  fontSize: 12, color: tc.textSecondary),
            ),
          ],
        ),
        actions: [
          // Recentrer sur client
          IconButton(
            icon: Icon(Icons.my_location, color: tc.textPrimary),
            onPressed: _centerOnClient,
            tooltip: 'Centrer sur le client',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── CARTE ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: clientLatLng,
              initialZoom: _currentZoom,
              minZoom: 3,
              maxZoom: 19,
            ),
            children: [
              // Tuiles OpenStreetMap (gratuit, pas de clé API)
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.techlink.app',
                maxZoom: 19,
              ),
              MarkerLayer(markers: markers),
              // Ligne entre tech et client si les deux positions sont connues
              if (_techPosition != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        LatLng(_techPosition!.latitude,
                            _techPosition!.longitude),
                        clientLatLng,
                      ],
                      color: AppColors.primary.withOpacity(0.5),
                      strokeWidth: 3,
                      pattern: StrokePattern.dashed(
                        segments: const [6, 4],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── BOUTONS ZOOM ──
          Positioned(
            right: 12,
            top: 80,
            child: Column(
              children: [
                _ZoomButton(icon: Icons.add, onTap: _zoomIn, tc: tc),
                const SizedBox(height: 4),
                _ZoomButton(icon: Icons.remove, onTap: _zoomOut, tc: tc),
              ],
            ),
          ),

          // ── PANNEAU D'INFO + BOUTON NAVIGATION ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: tc.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Poignée
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tc.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Infos client
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            widget.clientName.isNotEmpty
                                ? widget.clientName[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.clientName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: tc.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: AppColors.error, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.clientLat.toStringAsFixed(5)}, ${widget.clientLng.toStringAsFixed(5)}',
                                  style: TextStyle(
                                    color: tc.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Badge distance
                      if (dist >= 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.route,
                                  color: AppColors.primary, size: 16),
                              const SizedBox(height: 2),
                              Text(
                                dist < 1
                                    ? '${(dist * 1000).toStringAsFixed(0)}m'
                                    : '${dist.toStringAsFixed(1)}km',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Légende
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LegendDot(color: AppColors.error, label: 'Client', tc: tc),
                      const SizedBox(width: 20),
                      _LegendDot(
                          color: AppColors.primary,
                          label: 'Votre position', tc: tc),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Bouton démarrer navigation
                  ElevatedButton.icon(
                    onPressed: _openGoogleMaps,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.navigation_outlined, size: 22),
                    label: const Text(
                      'Démarrer la navigation GPS',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── CHARGEMENT GPS ──
          if (_loadingLocation)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: tc.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text('Détection de votre position...',
                          style: TextStyle(fontSize: 12, color: tc.textPrimary)),
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

// ── Widget : Marker client ──
class _ClientMarker extends StatelessWidget {
  final String name;
  const _ClientMarker({required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withOpacity(0.4),
                blurRadius: 6,
              ),
            ],
          ),
          child: Text(
            name.split(' ').first,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Icon(Icons.location_pin, color: AppColors.error, size: 32),
      ],
    );
  }
}

// ── Widget : Marker technicien ──
class _TechMarker extends StatelessWidget {
  const _TechMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Icon(Icons.engineering, color: Colors.white, size: 22),
    );
  }
}

// ── Widget : Bouton zoom ──
class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final TechLinkColors tc;
  const _ZoomButton({required this.icon, required this.onTap, required this.tc});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tc.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: tc.textPrimary),
      ),
    );
  }
}

// ── Widget : Légende ──
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final TechLinkColors tc;
  const _LegendDot({required this.color, required this.label, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: tc.textSecondary)),
      ],
    );
  }
}
