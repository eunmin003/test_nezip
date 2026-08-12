// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'models/zone_model.dart';
import 'services/vworld_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterNaverMap().init(
    clientId: '6pq4zvh61t', // 🔑 네이버 Client ID 입력
    onAuthFailed: (ex) {
      print("네이버 지도 인증 실패: $ex");
    },
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, primarySwatch: Colors.blue),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  NaverMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  List<ZonePolygonModel> _currentPolygons = [];
  final Set<NPolygonOverlay> _overlays = {};
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. 네이버 지도 (서울 시청 기본 좌표)
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(37.5665, 126.9780), // 서울 시청 중심
                zoom: 14.5,
              ),
              mapType: NMapType.basic,
              indoorEnable: true, // 실내지도 옵션
            ),
            onMapReady: (controller) {
              _mapController = controller;
              _fetchCurrentCameraZones();
            },
            onCameraChange: (reason, animated) {
              // 카메라 이동 멈췄을 때 해당 화면 구역 재로드
            },
            onCameraIdle: () {
              _fetchCurrentCameraZones();
            },
          ),

          // 2. 상단 주소/구역 검색창
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 52,
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: '구역명 또는 지역명 검색 (예: 서소문, 순화, 신길)',
                            border: InputBorder.none,
                          ),
                          onSubmitted: (value) => _searchAndMove(value),
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () => _searchController.clear(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. 우측 상단 범례
          Positioned(
            top: 80,
            right: 12,
            child: Card(
              color: Colors.white.withOpacity(0.92),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendItem(Colors.orange, '재개발'),
                    const SizedBox(height: 4),
                    _legendItem(Colors.blue, '재건축'),
                    const SizedBox(height: 4),
                    _legendItem(Colors.green, '주거환경개선'),
                    const SizedBox(height: 4),
                    _legendItem(Colors.purple, '기타/도시환경'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.4),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Color _getZoneColor(String? type) {
    if (type == null) return Colors.indigo;
    if (type.contains('재개발')) return Colors.orange;
    if (type.contains('재건축')) return Colors.blue;
    if (type.contains('주거환경')) return Colors.green;
    return Colors.indigo;
  }

  // 현재 화면 영역(BBOX) 기반으로 정비구역 가져와 지도에 오버레이 추가
  Future<void> _fetchCurrentCameraZones() async {
    if (_mapController == null) return;

    setState(() => _isLoading = true);

    try {
      final bounds = await _mapController!.getContentBounds();
      final zones = await VworldService.fetchZonesByBounds(bounds);

      // 기존 오버레이 삭제
      for (var overlay in _overlays) {
        _mapController?.deleteOverlay(overlay.info);
      }
      _overlays.clear();
      _currentPolygons = zones;

      // 새 구역 도형 추가
      for (int i = 0; i < zones.length; i++) {
        final zone = zones[i];
        final baseColor = _getZoneColor(zone.detailInfo?.type);

        final polygonOverlay = NPolygonOverlay(
          id: 'zone_poly_${DateTime.now().millisecondsSinceEpoch}_$i',
          coords: zone.coordinates,
          color: baseColor.withOpacity(0.28),
          outlineColor: baseColor,
          outlineWidth: 2,
        );

        polygonOverlay.setOnTapListener((overlay) {
          _showZoneDetailModal(zone);
        });

        _overlays.add(polygonOverlay);
        _mapController?.addOverlay(polygonOverlay);
      }
    } catch (e) {
      print("오버레이 렌더링 오류: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showZoneDetailModal(ZonePolygonModel zone) {
    final info = zone.detailInfo;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      zone.name,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Chip(
                    label: Text(
                      info?.type ?? '도시정비구역',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: _getZoneColor(info?.type),
                  ),
                ],
              ),
              const Divider(height: 24),
              _detailRow(Icons.location_on, '위치', '${info?.sido ?? '서울'} ${info?.sigungu ?? ''}'),
              _detailRow(Icons.trending_up, '추진단계', info?.stage ?? '구역지정/진행중', highlight: true),
              _detailRow(Icons.apartment, '공급예정 세대수', info?.householdCount != null && info!.householdCount.isNotEmpty ? '${info.householdCount} 세대' : '확인중'),
              _detailRow(Icons.business, '사업시행자', info?.executor ?? '조합/추진위'),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String title, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 95,
            child: Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '정보 없음' : value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
                color: highlight ? Colors.blue.shade800 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _searchAndMove(String query) async {
    if (query.trim().isEmpty) return;
    final target = await VworldService.searchLocation(query.trim());
    if (target != null) {
      _mapController?.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: target, zoom: 15),
      );
    }
  }
}