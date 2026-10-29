import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

/// Client ID는 실행 옵션으로 넣습니다:
///   flutter run --dart-define=NAVER_CLIENT_ID=발급받은ID
/// (VS Code F5로 실행한다면 .vscode/launch.json의 toolArgs에 넣어야 합니다)
const String _rawClientId = String.fromEnvironment('NAVER_CLIENT_ID');

/// 실행 옵션에 따옴표나 공백이 섞여 들어와도 401이 나지 않도록 정리합니다.
String _cleanClientId(String raw) {
  var id = raw.trim();
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

  if (naverClientId.isEmpty) {
    debugPrint('[NAVER] Client ID가 비어 있습니다. --dart-define=NAVER_CLIENT_ID=... 로 실행했는지 확인하세요.');
  }

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
      title: 'myzip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('지도')),
      body: NaverMap(
        options: const NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(
            target: NLatLng(37.3943, 126.9568), // 안양시청 부근
            zoom: 14,
          ),
          locationButtonEnable: false,
        ),
        onMapReady: (controller) {
          debugPrint('[NAVER] 지도 로딩 완료');
        },
      ),
    );
  }
}