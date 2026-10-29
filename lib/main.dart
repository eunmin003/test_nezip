import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'services/vworld_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 네이버 지도 SDK 초기화 (1.3.1부터 새 인증 방식: FlutterNaverMap().init)
  // Client ID는 실행 옵션으로 넣습니다: --dart-define=NAVER_CLIENT_ID=발급받은ID
  const naverClientId = String.fromEnvironment('NAVER_CLIENT_ID');
  await FlutterNaverMap().init(
    clientId: naverClientId,
    onAuthFailed: (ex) {
      switch (ex) {
        case NUnauthorizedClientException():
          debugPrint('[NAVER] 401 인증 실패: Client ID 또는 콘솔에 등록한 패키지명(com.example.myzip) 확인 → $ex');
        case NQuotaExceededException():
          debugPrint('[NAVER] 429: 콘솔에서 Dynamic Map 서비스 선택 여부/사용량 확인 → $ex');
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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
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
          // 새로고침 버튼 (현재 위치 영역의 구역 데이터 다시 로드)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadZonesInCurrentBounds,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 네이버 지도 위젯
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(37.5665, 126.9780), // 서울시청 중심
                zoom: 13,
              ),
              locationButtonEnable: true,
            ),
            onMapReady: (controller) {
              _mapController = controller;
              // 지도가 로드된 직후 현재 화면 영역 내 정비구역 로드
              _loadZonesInCurrentBounds();
            },
            // 지도 이동이 멈추면 새 영역의 구역을 다시 불러옴
            onCameraIdle: _loadZonesInCurrentBounds,
          ),

          // 상단 장소/주소 검색 창 UI
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
                          hintText: '지역명 또는 장소 검색 (예: 여의도)',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (value) => _searchAndMoveLocation(value),
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

          // 로딩 표시기
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  // 1. 현재 지도의 바운즈(영역) 기반으로 VWorld API 호출 및 반투명 도형 렌더링
  Future<void> _loadZonesInCurrentBounds() async {
    if (_mapController == null || _isLoading) return;

    // 너무 멀리서 보면 요청 영역이 커져 V-world가 거부하거나 느려지므로 줌 12 이상에서만 조회
    final camera = await _mapController!.getCameraPosition();
    if (camera.zoom < 12) return;

    setState(() => _isLoading = true);

    try {
      // 현재 화면에 보이는 지도의 NLatLngBounds 좌표 영역 가져오기
      final NLatLngBounds bounds = await _mapController!.getContentBounds();

      // VworldService를 통해 해당 영역 내 정비구역 좌표 리스트 받아오기
      final List<List<NLatLng>> zonePolygons =
      await VworldService.fetchZonesByBounds(bounds);

      // 기존 오버레이 모두 제거
      _mapController!.clearOverlays();

      // 받아온 구역 좌표들을 NPolygonOverlay로 만들어 지도에 추가
      for (int i = 0; i < zonePolygons.length; i++) {
        final polygonPoints = zonePolygons[i];

        if (polygonPoints.length >= 3) {
          final polygon = NPolygonOverlay(
            id: 'vworld_zone_$i',
            coords: polygonPoints,
            color: Colors.red.withValues(alpha: 0.35), // 반투명 빨간색
            outlineColor: Colors.red, // 테두리 선 색상
            outlineWidth: 2,
          );

          _mapController!.addOverlay(polygon);
        }
      }

      if (zonePolygons.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('현재 화면 영역 내에 표시할 도시정비구역이 없습니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("구역 로딩 중 오류 발생: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 2. VworldService.searchLocation을 활용한 장소 검색 및 카메라 이동
  Future<void> _searchAndMoveLocation(String query) async {
    if (query.trim().isEmpty || _mapController == null) return;

    FocusScope.of(context).unfocus(); // 키보드 내리기
    setState(() => _isLoading = true);

    final NLatLng? searchResult = await VworldService.searchLocation(query);
    if (mounted) setState(() => _isLoading = false); // 구역 로딩이 막히지 않도록 먼저 해제

    if (searchResult != null) {
      // 검색된 위치로 지도 카메라 이동
      final cameraUpdate = NCameraUpdate.scrollAndZoomTo(
        target: searchResult,
        zoom: 14,
      );
      await _mapController!.updateCamera(cameraUpdate);

      // 이동된 위치의 새로운 구역 데이터 로드
      await _loadZonesInCurrentBounds();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('검색 결과를 찾을 수 없습니다.')),
        );
      }
    }
  }
}