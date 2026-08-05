import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

void main() async {
  // 메인 함수 실행 전 플러터 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 네이버 지도 SDK 초기화
  await NaverMapSdk.instance.initialize(
    clientId: 'bjvqec2t6a', // 발급받으신 CLIENT_ID
    onAuthFailed: (ex) {
      print("네이버 지도 인증 실패: $ex");
    },
  );

  runApp(const PropertyApp());
}

class PropertyApp extends StatelessWidget {
  const PropertyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: NaverMapHomeScreen(),
    );
  }
}

class NaverMapHomeScreen extends StatefulWidget {
  const NaverMapHomeScreen({super.key});

  @override
  State<NaverMapHomeScreen> createState() => _NaverMapHomeScreenState();
}

class _NaverMapHomeScreenState extends State<NaverMapHomeScreen> {
  NaverMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🗺️ 네이버 재개발 지도',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: NaverMap(
        options: const NaverMapViewOptions(
          // 서울 한남동 재개발 구역 위치로 초기 카메라 설정
          initialCameraPosition: NCameraPosition(
            target: NLatLng(37.5285, 126.9980),
            zoom: 14,
          ),
          locationButtonEnable: true,
        ),
        onMapReady: (controller) {
          _mapController = controller;

          // 1️⃣ 재개발 영역 다각형 (반투명 빨간색)
          final redevArea = NPolygonOverlay(
            id: 'redevelopment_zone_1',
            coords: const [
              NLatLng(37.5305, 126.9955),
              NLatLng(37.5315, 126.9995),
              NLatLng(37.5265, 127.0010),
              NLatLng(37.5255, 126.9965),
            ],
            color: Colors.redAccent.withOpacity(0.35), // 35% 반투명
            outlineColor: Colors.red,
            outlineWidth: 2,
          );

          // 2️⃣ 재건축 영역 다각형 (반투명 파란색)
          final rebuildArea = NPolygonOverlay(
            id: 'rebuild_zone_2',
            coords: const [
              NLatLng(37.5240, 126.9920),
              NLatLng(37.5250, 126.9950),
              NLatLng(37.5220, 126.9955),
              NLatLng(37.5215, 126.9925),
            ],
            color: Colors.blueAccent.withOpacity(0.35), // 35% 반투명
            outlineColor: Colors.blue,
            outlineWidth: 2,
          );

          // 3️⃣ 중앙 안내 마커
          final marker = NMarker(
            id: 'zone_marker_1',
            position: const NLatLng(37.5285, 126.9980),
            caption: const NOverlayCaption(text: "한남3구역 (재개발)"),
          );

          // 지도 위에 오버레이 추가
          controller.addOverlay(redevArea);
          controller.addOverlay(rebuildArea);
          controller.addOverlay(marker);
        },
      ),
    );
  }
}