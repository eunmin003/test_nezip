import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'models/redev_zone.dart';
import 'services/vworld_services.dart';
import 'services/zone_repository.dart';

/// Client ID는 실행 옵션으로 넣습니다: --dart-define=NAVER_CLIENT_ID=발급받은ID
const String _rawClientId = String.fromEnvironment('NAVER_CLIENT_ID');

/// 실행 옵션에 따옴표·공백·잘못 붙은 '='가 섞여 들어와도 401이 나지 않도록 정리합니다.
String _cleanClientId(String raw) {
  var id = raw.trim();
  while (id.startsWith('=')) {
    id = id.substring(1).trim();
  }
  while (id.length >= 2 &&
      ((id.startsWith('"') && id.endsWith('"')) ||
          (id.startsWith("'") && id.endsWith("'")))) {
    id = id.substring(1, id.length - 1).trim();
  }
  return id;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final naverClientId = _cleanClientId(_rawClientId);

  // 값 전체 대신 앞 4글자와 길이만 출력 (콘솔 값과 비교용)
  final preview = naverClientId.length > 4
      ? '${naverClientId.substring(0, 4)}****'
      : naverClientId;
  debugPrint('[NAVER] 원본 길이 ${_rawClientId.length}자 → 정리 후 "$preview" (${naverClientId.length}자)');

  // 네이버 지도 SDK 초기화 (신규 Maps 인증 방식)
  await FlutterNaverMap().init(
    clientId: naverClientId,
    onAuthFailed: (ex) {
      switch (ex) {
        case NUnauthorizedClientException():
          debugPrint('[NAVER] 401 인증 실패: Client ID 값 또는 콘솔 패키지명(com.example.myzip) 확인 → $ex');
        case NQuotaExceededException():
          debugPrint('[NAVER] 429: 콘솔에서 Dynamic Map 선택 여부/사용량 확인 → $ex');
        case NClientUnspecifiedException():
          debugPrint('[NAVER] 800: Client ID가 비어 있음 → $ex');
        default:
          debugPrint('[NAVER] 인증 실패 → $ex');
      }
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
      theme: ThemeData(colorSchemeSeed: const Color(0xFF3F51B5)),
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
  bool _isLoading = false;

  /// 이미 지도에 올린 구역 id (같은 구역을 두 번 올리지 않도록)
  final Set<String> _shownZoneIds = {};

  /// 이 줌보다 멀리서 보면 구역을 새로 그리지 않음 (너무 많아져서 느려지는 것 방지)
  static const double _minZoomForZones = 11;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('도시정비사업 구역 지도'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '다시 그리기',
            onPressed: _reloadZones,
          ),
        ],
      ),
      body: Stack(
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(37.5665, 126.9780), // 서울시청
                zoom: 13,
              ),
              locationButtonEnable: true,
            ),
            onMapReady: (controller) {
              _mapController = controller;
              _loadZonesInCurrentBounds();
            },
            // 지도 이동이 멈추면 새로 보이는 구역을 추가로 그림
            onCameraIdle: _loadZonesInCurrentBounds,
          ),

          // 상단 검색창
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: '지역명 또는 장소 검색 (예: 공덕역)',
                          border: InputBorder.none,
                        ),
                        onSubmitted: _searchAndMoveLocation,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () =>
                          _searchAndMoveLocation(_searchController.text),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 왼쪽 아래 범례
          const Positioned(left: 12, bottom: 90, child: _StageLegend()),

          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  /// 오버레이를 모두 지우고 다시 그리기
  Future<void> _reloadZones() async {
    if (_mapController == null) return;
    await _mapController!.clearOverlays(type: NOverlayType.polygonOverlay);
    _shownZoneIds.clear();
    await _loadZonesInCurrentBounds();
  }

  /// 현재 화면 안의 정비구역을 지도에 그리기 (이미 그린 구역은 건너뜀)
  Future<void> _loadZonesInCurrentBounds() async {
    if (_mapController == null || _isLoading) return;

    final camera = await _mapController!.getCameraPosition();
    if (camera.zoom < _minZoomForZones) return;

    setState(() => _isLoading = true);
    try {
      final bounds = await _mapController!.getContentBounds();
      final zones = await ZoneRepository.zonesIn(bounds);

      final newOverlays = <NAddableOverlay>{};
      for (final zone in zones) {
        for (var i = 0; i < zone.rings.length; i++) {
          final overlayId = '${zone.id}_$i';
          if (_shownZoneIds.contains(overlayId)) continue;

          final ring = zone.rings[i];
          final polygon = NPolygonOverlay(
            id: overlayId,
            coords: ring.outer,
            holes: ring.holes,
            color: zone.color.withValues(alpha: 0.35),
            outlineColor: zone.color,
            outlineWidth: 2,
          );
          polygon.setOnTapListener((_) => _showZoneSheet(zone));
          newOverlays.add(polygon);
          _shownZoneIds.add(overlayId);
        }
      }

      if (newOverlays.isNotEmpty) {
        await _mapController!.addOverlayAll(newOverlays);
      }
      debugPrint('[ZONE] 화면 안 ${zones.length}개, 새로 그림 ${newOverlays.length}개');
    } catch (e, st) {
      debugPrint('[ZONE] 구역 그리기 오류: $e\n$st');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 구역을 눌렀을 때 하단 정보 카드
  void _showZoneSheet(RedevZone zone) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => _ZoneInfoSheet(zone: zone),
    );
  }

  /// 장소 검색 후 카메라 이동
  Future<void> _searchAndMoveLocation(String query) async {
    if (query.trim().isEmpty || _mapController == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    final NLatLng? searchResult = await VworldService.searchLocation(query);
    if (mounted) setState(() => _isLoading = false);

    if (searchResult != null) {
      await _mapController!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: searchResult, zoom: 15),
      );
      // 카메라가 멈추면 onCameraIdle에서 구역을 그림
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검색 결과를 찾을 수 없습니다.')),
      );
    }
  }
}

/// 구역 정보 카드
class _ZoneInfoSheet extends StatelessWidget {
  final RedevZone zone;

  const _ZoneInfoSheet({required this.zone});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final location = [zone.sido, zone.sgg].where((s) => s.isNotEmpty).join(' ');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: zone.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    zone.hasName ? zone.name : '정비구역 (구역명 미기재)',
                    style: textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(location, style: textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
            const Divider(height: 24),
            _row('사업 구분', zone.bizType ?? zone.type),
            _row('추진 단계', zone.stage ?? '정보 없음'),
            _row('사업 시행자', zone.executor ?? '정보 없음'),
            _row('예정 세대수',
                (zone.households == null || zone.households == 0) ? '정보 없음' : '${zone.households}세대'),
            _row('지정·고시일', zone.noticeDate.isEmpty ? '정보 없음' : zone.noticeDate),
            const SizedBox(height: 8),
            Text(
              '출처: 국토교통부 정비구역(2026-10 기준), 도시정비사업 현황 CSV',
              style: textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.grey))),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

/// 추진단계 색상 범례
class _StageLegend extends StatelessWidget {
  const _StageLegend();

  static const _items = [
    ('추진위·구역지정', '정비구역지정'),
    ('조합설립', '조합설립인가'),
    ('사업시행인가', '사업시행인가'),
    ('관리처분', '관리처분인가'),
    ('착공', '착공'),
    ('단계 정보 없음', null),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, stage) in _items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      color: RedevZone.stageColor(stage),
                    ),
                    const SizedBox(width: 6),
                    Text(label, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}