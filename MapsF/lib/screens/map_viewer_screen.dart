import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../app/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/gps/gps_service.dart';
import '../core/utils/geo_utils.dart';
import '../models/current_location.dart';
import '../models/local_map.dart';
import '../models/map_detail.dart';
import '../models/project_viewer.dart';
import '../services/service_providers.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_banner.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/map/app_floating_map_button.dart';

enum MapViewerMode { singleMap, projectAllMaps, selectedMaps }

const double _maxViewerZoom = 22;
const int _maxOverzoomLevels = 2;

double _visualMaxZoom(int nativeMaxZoom) {
  return (nativeMaxZoom + _maxOverzoomLevels)
      .clamp(0, _maxViewerZoom)
      .toDouble();
}

class MapViewerScreen extends ConsumerStatefulWidget {
  const MapViewerScreen.single({super.key, required this.mapId})
    : mode = MapViewerMode.singleMap,
      projectId = null,
      mapIds = const [];

  const MapViewerScreen.project({super.key, required this.projectId})
    : mode = MapViewerMode.projectAllMaps,
      mapId = null,
      mapIds = const [];

  const MapViewerScreen.selection({
    super.key,
    required this.projectId,
    required this.mapIds,
  }) : mode = MapViewerMode.selectedMaps,
       mapId = null;

  final MapViewerMode mode;
  final String? mapId;
  final String? projectId;
  final List<String> mapIds;

  @override
  ConsumerState<MapViewerScreen> createState() => _MapViewerScreenState();
}

class _MapViewerScreenState extends ConsumerState<MapViewerScreen> {
  final mapController = MapController();
  final gpsService = GpsService();
  late Future<LocalMap?> localMapFuture;
  MbTilesTileProvider? mbtilesTileProvider;
  String? tileProviderPath;
  CurrentLocation? location;
  String? gpsError;
  bool loadingGps = false;
  bool showRoadReference = false;

  @override
  void initState() {
    super.initState();
    localMapFuture = kIsWeb || widget.mode != MapViewerMode.singleMap
        ? Future<LocalMap?>.value()
        : ref.read(localMapRepositoryProvider).findMap(widget.mapId!);
  }

  @override
  void dispose() {
    mbtilesTileProvider?.dispose();
    super.dispose();
  }

  MbTilesTileProvider providerFor(LocalMap map) {
    if (tileProviderPath != map.mbtilesPath) {
      mbtilesTileProvider?.dispose();
      mbtilesTileProvider = MbTilesTileProvider.fromPath(path: map.mbtilesPath);
      tileProviderPath = map.mbtilesPath;
    }
    return mbtilesTileProvider!;
  }

  Future<void> locate() async {
    setState(() {
      loadingGps = true;
      gpsError = null;
    });
    try {
      final current = await gpsService.getCurrentLocation();
      setState(() {
        location = current;
        loadingGps = false;
      });
      mapController.move(LatLng(current.lat, current.lng), 16);
    } catch (e) {
      setState(() {
        gpsError = e.toString();
        loadingGps = false;
      });
    }
  }

  void toggleRoadReference() {
    setState(() {
      showRoadReference = !showRoadReference;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _RemoteMapViewer(
        mode: widget.mode,
        mapId: widget.mapId,
        projectId: widget.projectId,
        mapIds: widget.mapIds,
        mapController: mapController,
        gpsService: gpsService,
        location: location,
        gpsError: gpsError,
        loadingGps: loadingGps,
        showRoadReference: showRoadReference,
        onLocate: locate,
        onToggleRoadReference: toggleRoadReference,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Visor offline')),
      body: FutureBuilder<LocalMap?>(
        future: localMapFuture,
        builder: (context, snapshot) {
          final localMap = snapshot.data;

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(
              title: 'Abriendo visor offline',
              steps: [
                'Leyendo paquete local',
                'Validando teselas',
                'Centrando mapa',
              ],
            );
          }

          if (localMap == null) {
            return const AppEmptyState(
              icon: Icons.map_outlined,
              title: 'Todavia no tienes mapas offline',
              message:
                  'Sube un PDF georreferenciado para crear el paquete local y trabajar en campo.',
            );
          }

          return _MapContent(
            localMap: localMap,
            mapController: mapController,
            mbtilesTileProvider: providerFor(localMap),
            location: location,
            gpsError: gpsError,
            showRoadReference: showRoadReference,
            onToggleRoadReference: toggleRoadReference,
          );
        },
      ),
      floatingActionButton: AppFloatingMapButton(
        icon: Icons.my_location_rounded,
        tooltip: loadingGps ? 'Buscando GPS' : 'Mi ubicacion',
        loading: loadingGps,
        onPressed: loadingGps ? null : locate,
      ),
    );
  }
}

class _RemoteMapViewer extends ConsumerWidget {
  const _RemoteMapViewer({
    required this.mode,
    required this.mapId,
    required this.projectId,
    required this.mapIds,
    required this.mapController,
    required this.gpsService,
    required this.location,
    required this.gpsError,
    required this.loadingGps,
    required this.showRoadReference,
    required this.onLocate,
    required this.onToggleRoadReference,
  });

  final MapViewerMode mode;
  final String? mapId;
  final String? projectId;
  final List<String> mapIds;
  final MapController mapController;
  final GpsService gpsService;
  final CurrentLocation? location;
  final String? gpsError;
  final bool loadingGps;
  final bool showRoadReference;
  final Future<void> Function() onLocate;
  final VoidCallback onToggleRoadReference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = Future.wait<Object?>([
      mode == MapViewerMode.singleMap
          ? ref.read(mapServiceProvider).getMapDetail(mapId!)
          : ref
                .read(projectServiceProvider)
                .getProjectViewer(projectId: projectId!, mapIds: mapIds),
      ref.read(tokenStorageProvider).getAccessToken(),
    ]);

    return Scaffold(
      appBar: AppBar(title: const Text('Visor web')),
      body: FutureBuilder<List<Object?>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(
              title: 'Abriendo visor web',
              steps: [
                'Consultando backend',
                'Cargando token',
                'Preparando capas',
              ],
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: AppErrorBanner(
                title: 'No se pudo abrir el visor',
                message:
                    'La conexion con el backend fallo. Intenta nuevamente en unos segundos.',
              ),
            );
          }

          final viewerData = snapshot.data![0];
          final token = snapshot.data![1]?.toString() ?? '';
          if (viewerData is ProjectViewer) {
            return _RemoteProjectMapContent(
              viewer: viewerData,
              token: token,
              mapController: mapController,
              location: location,
              gpsError: gpsError,
              showRoadReference: showRoadReference,
              onToggleRoadReference: onToggleRoadReference,
            );
          }
          final detail = viewerData as MapDetail;
          return _RemoteMapContent(
            detail: detail,
            token: token,
            mapController: mapController,
            location: location,
            gpsError: gpsError,
            showRoadReference: showRoadReference,
            onToggleRoadReference: onToggleRoadReference,
          );
        },
      ),
      floatingActionButton: AppFloatingMapButton(
        icon: Icons.my_location_rounded,
        tooltip: loadingGps ? 'Buscando GPS' : 'Mi ubicacion',
        loading: loadingGps,
        onPressed: loadingGps ? null : onLocate,
      ),
    );
  }
}

class _RemoteMapContent extends StatelessWidget {
  const _RemoteMapContent({
    required this.detail,
    required this.token,
    required this.mapController,
    required this.location,
    required this.gpsError,
    required this.showRoadReference,
    required this.onToggleRoadReference,
  });

  final MapDetail detail;
  final String token;
  final MapController mapController;
  final CurrentLocation? location;
  final String? gpsError;
  final bool showRoadReference;
  final VoidCallback onToggleRoadReference;

  @override
  Widget build(BuildContext context) {
    final center = LatLng(
      detail.center?.lat ?? 9.9281,
      detail.center?.lng ?? -84.0907,
    );
    final bounds = detail.bounds;
    final footprintPoints = bounds == null
        ? const <LatLng>[]
        : [
            LatLng(bounds.minLat, bounds.minLng),
            LatLng(bounds.maxLat, bounds.minLng),
            LatLng(bounds.maxLat, bounds.maxLng),
            LatLng(bounds.minLat, bounds.maxLng),
          ];
    final tileBounds = bounds == null
        ? null
        : LatLngBounds(
            LatLng(bounds.minLat, bounds.minLng),
            LatLng(bounds.maxLat, bounds.maxLng),
          );
    final point = location == null
        ? null
        : LatLng(location!.lat, location!.lng);
    final inside = point == null || footprintPoints.length < 3
        ? null
        : pointInPolygon(point, footprintPoints);
    final version = Uri.encodeComponent(detail.tileVersion ?? detail.status);
    final view = detail.viewMode == 'quick' ? 'quick' : 'optimized';
    final rawTileUrl =
        '${AppConstants.apiUrl}/maps/${detail.id}/raw-tiles/{z}/{x}/{y}.png?'
        'access_token=${Uri.encodeComponent(token)}&v=$version';
    final tileUrl =
        '${AppConstants.apiUrl}/maps/${detail.id}/tiles/{z}/{x}/{y}.png?'
        'view=$view&access_token=${Uri.encodeComponent(token)}&v=$version';
    final minZoom = detail.minZoom.toDouble();
    final maxZoom = _visualMaxZoom(detail.maxZoom);
    final defaultZoom = detail.defaultZoom
        .toDouble()
        .clamp(minZoom, maxZoom)
        .toDouble();

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: defaultZoom,
            minZoom: minZoom,
            maxZoom: maxZoom,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.geocampo.geocampo_app',
              minNativeZoom: 0,
              maxNativeZoom: 19,
              keepBuffer: 1,
              panBuffer: 0,
            ),
            if (detail.viewMode == 'raw')
              TileLayer(
                urlTemplate: rawTileUrl,
                minNativeZoom: detail.minZoom,
                maxNativeZoom: detail.maxZoom,
                maxZoom: maxZoom,
                tileBounds: tileBounds,
                keepBuffer: 0,
                panBuffer: 0,
                retinaMode: false,
                userAgentPackageName: 'com.geocampo.geocampo_app',
              ),
            if (detail.viewMode != 'raw')
              TileLayer(
                urlTemplate: tileUrl,
                minNativeZoom: detail.minZoom,
                maxNativeZoom: detail.maxZoom,
                maxZoom: maxZoom,
                tileBounds: tileBounds,
                keepBuffer: 2,
                panBuffer: 1,
                retinaMode: false,
                userAgentPackageName: 'com.geocampo.geocampo_app',
              ),
            if (showRoadReference) _RoadReferenceLayer(tileBounds: tileBounds),
            if (detail.viewMode != 'raw' && footprintPoints.length >= 3)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: footprintPoints,
                    color: Colors.transparent,
                    borderColor: AppColors.primaryGreen,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            if (point != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 54,
                    height: 54,
                    child: const Icon(
                      Icons.my_location,
                      color: AppColors.gpsBlue,
                      size: 34,
                    ),
                  ),
                ],
              ),
          ],
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: _MapOverlayPanel(
            icon: Icons.map_outlined,
            title: detail.name,
            badge: inside == null
                ? null
                : _LocationBadge(
                    label: inside
                        ? 'Dentro del mapa'
                        : 'Fuera del mapa cargado',
                    inside: inside,
                  ),
            action: AppFloatingMapButton(
              icon: Icons.alt_route_rounded,
              tooltip: showRoadReference ? 'Ocultar calles' : 'Mostrar calles',
              active: showRoadReference,
              onPressed: onToggleRoadReference,
            ),
          ),
        ),
        if (gpsError != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 88,
            child: const AppErrorBanner(
              title: 'GPS no disponible',
              message:
                  'No pudimos obtener tu ubicacion. Revisa permisos o senal del dispositivo.',
            ),
          ),
      ],
    );
  }
}

class _RemoteProjectMapContent extends StatefulWidget {
  const _RemoteProjectMapContent({
    required this.viewer,
    required this.token,
    required this.mapController,
    required this.location,
    required this.gpsError,
    required this.showRoadReference,
    required this.onToggleRoadReference,
  });

  final ProjectViewer viewer;
  final String token;
  final MapController mapController;
  final CurrentLocation? location;
  final String? gpsError;
  final bool showRoadReference;
  final VoidCallback onToggleRoadReference;

  @override
  State<_RemoteProjectMapContent> createState() =>
      _RemoteProjectMapContentState();
}

class _RemoteProjectMapContentState extends State<_RemoteProjectMapContent> {
  late final visibleLayerIds = widget.viewer.maps
      .where((map) => map.visible)
      .map((map) => map.id)
      .toSet();

  @override
  Widget build(BuildContext context) {
    final center = LatLng(
      widget.viewer.center?.lat ?? 9.9281,
      widget.viewer.center?.lng ?? -84.0907,
    );
    final bounds = widget.viewer.bounds;
    final footprintPoints = bounds == null
        ? const <LatLng>[]
        : [
            LatLng(bounds.minLat, bounds.minLng),
            LatLng(bounds.maxLat, bounds.minLng),
            LatLng(bounds.maxLat, bounds.maxLng),
            LatLng(bounds.minLat, bounds.maxLng),
          ];
    final projectBounds = bounds == null
        ? null
        : LatLngBounds(
            LatLng(bounds.minLat, bounds.minLng),
            LatLng(bounds.maxLat, bounds.maxLng),
          );
    final point = widget.location == null
        ? null
        : LatLng(widget.location!.lat, widget.location!.lng);
    final inside = point == null || footprintPoints.length < 3
        ? null
        : pointInPolygon(point, footprintPoints);
    final maxNativeZoom = widget.viewer.maps.isEmpty
        ? 18
        : widget.viewer.maps
              .map((map) => map.maxZoom)
              .reduce((a, b) => a > b ? a : b);
    final maxZoom = _visualMaxZoom(maxNativeZoom);

    return Stack(
      children: [
        FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15,
            minZoom: 0,
            maxZoom: maxZoom,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.geocampo.geocampo_app',
              minNativeZoom: 0,
              maxNativeZoom: 19,
              keepBuffer: 1,
              panBuffer: 0,
            ),
            ...widget.viewer.maps
                .where((map) => visibleLayerIds.contains(map.id))
                .map(
                  (map) => Opacity(
                    opacity: map.opacity.clamp(0, 1).toDouble(),
                    child: TileLayer(
                      urlTemplate: _tileUrl(map.tileUrl, widget.token),
                      minNativeZoom: map.minZoom,
                      maxNativeZoom: map.maxZoom,
                      maxZoom: maxZoom,
                      tileBounds: _boundsFor(map.bounds),
                      keepBuffer: 1,
                      panBuffer: 0,
                      retinaMode: false,
                    ),
                  ),
                ),
            if (widget.showRoadReference)
              _RoadReferenceLayer(tileBounds: projectBounds),
            if (footprintPoints.length >= 3)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: footprintPoints,
                    color: Colors.transparent,
                    borderColor: AppColors.primaryGreen,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            if (point != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 54,
                    height: 54,
                    child: const Icon(
                      Icons.my_location,
                      color: AppColors.gpsBlue,
                      size: 34,
                    ),
                  ),
                ],
              ),
          ],
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: _MapOverlayPanel(
            icon: Icons.layers_outlined,
            title:
                '${widget.viewer.projectName} · ${visibleLayerIds.length} capas',
            badge: inside == null
                ? null
                : _LocationBadge(
                    label: inside ? 'Dentro del proyecto' : 'Fuera del area',
                    inside: inside,
                  ),
            action: AppFloatingMapButton(
              icon: Icons.alt_route_rounded,
              tooltip: widget.showRoadReference
                  ? 'Ocultar calles'
                  : 'Mostrar calles',
              active: widget.showRoadReference,
              onPressed: widget.onToggleRoadReference,
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: widget.gpsError == null ? 12 : 88,
          child: _MapLayerPanel(
            children: widget.viewer.maps
                .map(
                  (map) => _LayerToggleTile(
                    title: map.name,
                    subtitle: 'Opacidad ${(map.opacity * 100).round()}%',
                    selected: visibleLayerIds.contains(map.id),
                    onTap: () {
                      setState(() {
                        if (visibleLayerIds.contains(map.id)) {
                          visibleLayerIds.remove(map.id);
                        } else {
                          visibleLayerIds.add(map.id);
                        }
                      });
                    },
                  ),
                )
                .toList(growable: false),
          ),
        ),
        if (widget.gpsError != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: const AppErrorBanner(
              title: 'GPS no disponible',
              message:
                  'No pudimos obtener tu ubicacion. Revisa permisos o senal del dispositivo.',
            ),
          ),
      ],
    );
  }

  static String _tileUrl(String rawUrl, String token) {
    final url = rawUrl.startsWith('http')
        ? rawUrl
        : '${AppConstants.apiBaseUrl}$rawUrl';
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}access_token=${Uri.encodeComponent(token)}';
  }

  static LatLngBounds? _boundsFor(MapBounds? bounds) {
    if (bounds == null) return null;
    return LatLngBounds(
      LatLng(bounds.minLat, bounds.minLng),
      LatLng(bounds.maxLat, bounds.maxLng),
    );
  }
}

class _MapContent extends StatelessWidget {
  const _MapContent({
    required this.localMap,
    required this.mapController,
    required this.mbtilesTileProvider,
    required this.location,
    required this.gpsError,
    required this.showRoadReference,
    required this.onToggleRoadReference,
  });

  final LocalMap localMap;
  final MapController mapController;
  final MbTilesTileProvider mbtilesTileProvider;
  final CurrentLocation? location;
  final String? gpsError;
  final bool showRoadReference;
  final VoidCallback onToggleRoadReference;

  @override
  Widget build(BuildContext context) {
    final center = LatLng(
      localMap.centerLat ?? 9.9281,
      localMap.centerLng ?? -84.0907,
    );
    final defaultZoom = (localMap.defaultZoom ?? localMap.minZoom ?? 13)
        .toDouble();
    final minZoom = (localMap.minZoom ?? 0).toDouble();
    final maxZoom = _visualMaxZoom(localMap.maxZoom ?? 22);
    final footprintPoints = _parseLatLngList(localMap.footprintJson);
    final tileBounds = _parseBounds(localMap.boundsJson);
    final point = location == null
        ? null
        : LatLng(location!.lat, location!.lng);
    final inside = point == null || footprintPoints.length < 3
        ? null
        : pointInPolygon(point, footprintPoints);

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: defaultZoom,
            minZoom: minZoom,
            maxZoom: maxZoom,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.geocampo.geocampo_app',
              minNativeZoom: 0,
              maxNativeZoom: 19,
              keepBuffer: 1,
              panBuffer: 0,
            ),
            TileLayer(
              tileProvider: mbtilesTileProvider,
              minNativeZoom: localMap.minZoom ?? 0,
              maxNativeZoom: localMap.maxZoom ?? 22,
              maxZoom: maxZoom,
              tileBounds: tileBounds,
              keepBuffer: 1,
              panBuffer: 0,
              retinaMode: false,
            ),
            if (showRoadReference) _RoadReferenceLayer(tileBounds: tileBounds),
            if (footprintPoints.length >= 3)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: footprintPoints,
                    color: Colors.transparent,
                    borderColor: AppColors.primaryGreen,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            if (point != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 54,
                    height: 54,
                    child: const Icon(
                      Icons.my_location,
                      color: AppColors.gpsBlue,
                      size: 34,
                    ),
                  ),
                ],
              ),
          ],
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: _MapOverlayPanel(
            icon: Icons.map_outlined,
            title: localMap.name,
            badge: inside == null
                ? null
                : _LocationBadge(
                    label: inside
                        ? 'Dentro del mapa'
                        : 'Fuera del mapa cargado',
                    inside: inside,
                  ),
            action: AppFloatingMapButton(
              icon: Icons.alt_route_rounded,
              tooltip: showRoadReference ? 'Ocultar calles' : 'Mostrar calles',
              active: showRoadReference,
              onPressed: onToggleRoadReference,
            ),
          ),
        ),
        if (gpsError != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 88,
            child: const AppErrorBanner(
              title: 'GPS no disponible',
              message:
                  'No pudimos obtener tu ubicacion. Revisa permisos o senal del dispositivo.',
            ),
          ),
      ],
    );
  }

  static LatLngBounds? _parseBounds(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return null;
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) {
        final minLat = _doubleValue(decoded['min_lat']);
        final minLng = _doubleValue(decoded['min_lng']);
        final maxLat = _doubleValue(decoded['max_lat']);
        final maxLng = _doubleValue(decoded['max_lng']);
        if (minLat != null &&
            minLng != null &&
            maxLat != null &&
            maxLng != null) {
          return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static List<LatLng> _parseLatLngList(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return const [];
    try {
      final decoded = jsonDecode(rawJson);
      final coordinates = _unwrapCoordinates(decoded);
      return coordinates
          .map(_latLngFromCoordinate)
          .whereType<LatLng>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static List<dynamic> _unwrapCoordinates(Object? decoded) {
    if (decoded is Map) {
      final type = decoded['type']?.toString();
      final coordinates = decoded['coordinates'];
      if (type == 'Polygon' && coordinates is List && coordinates.isNotEmpty) {
        return coordinates.first as List<dynamic>;
      }
      if (coordinates is List) return coordinates;
    }
    if (decoded is List) {
      if (decoded.isNotEmpty && decoded.first is List) {
        final first = decoded.first as List;
        if (first.isNotEmpty && first.first is List) {
          return first.cast<dynamic>();
        }
      }
      return decoded;
    }
    return const [];
  }

  static LatLng? _latLngFromCoordinate(Object? value) {
    if (value is Map) {
      final lat = _doubleValue(value['lat'] ?? value['latitude']);
      final lng = _doubleValue(
        value['lng'] ?? value['lon'] ?? value['longitude'],
      );
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    if (value is List && value.length >= 2) {
      final lng = _doubleValue(value[0]);
      final lat = _doubleValue(value[1]);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }

  static double? _doubleValue(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class _MapOverlayPanel extends StatelessWidget {
  const _MapOverlayPanel({
    required this.icon,
    required this.title,
    required this.action,
    this.badge,
  });

  final IconData icon;
  final String title;
  final Widget action;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.mapDark.withValues(alpha: .90),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: .28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .16),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.lightGreen, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (badge != null) ...[const SizedBox(width: 8), badge!],
          const SizedBox(width: 8),
          SizedBox.square(dimension: 50, child: action),
        ],
      ),
    );
  }
}

class _MapLayerPanel extends StatelessWidget {
  const _MapLayerPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 236),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD5E2D9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}

class _LayerToggleTile extends StatefulWidget {
  const _LayerToggleTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_LayerToggleTile> createState() => _LayerToggleTileState();
}

class _LayerToggleTileState extends State<_LayerToggleTile> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: pressed ? .98 : 1,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: Material(
        color: widget.selected ? AppColors.paleGreen : const Color(0xFFF8FAF7),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => pressed = true),
          onTapCancel: () => setState(() => pressed = false),
          onTapUp: (_) => setState(() => pressed = false),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? AppColors.primaryGreen
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.selected
                          ? AppColors.primaryGreen
                          : const Color(0xFFB8C9BE),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: widget.selected
                        ? const Icon(
                            Icons.check_rounded,
                            key: ValueKey('checked'),
                            color: Colors.white,
                            size: 18,
                          )
                        : const SizedBox(key: ValueKey('empty')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoadReferenceLayer extends StatelessWidget {
  const _RoadReferenceLayer({required this.tileBounds});

  final LatLngBounds? tileBounds;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.36,
        child: TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.geocampo.geocampo_app',
          minNativeZoom: 0,
          maxNativeZoom: 19,
          maxZoom: 22,
          tileBounds: tileBounds,
          keepBuffer: 1,
          panBuffer: 0,
          retinaMode: false,
        ),
      ),
    );
  }
}

class _LocationBadge extends StatelessWidget {
  const _LocationBadge({required this.label, required this.inside});

  final String label;
  final bool inside;

  @override
  Widget build(BuildContext context) {
    final color = inside ? AppColors.primaryGreen : AppColors.dangerRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
