import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;

/// V-world API 호출 모음 (현재는 장소 검색만 사용).
///
/// 정비구역 폴리곤은 V-world API에 레이어가 없어서
/// assets/data/redevelopment_zones.geojson 파일을 읽습니다 → zone_repository.dart
///
/// 키는 코드에 직접 쓰지 않고 실행 옵션(--dart-define)으로 넣습니다.
///   --dart-define=VWORLD_KEY=발급받은키
class VworldService {
  static const String apiKey = String.fromEnvironment('VWORLD_KEY');
  static const String domain = String.fromEnvironment('VWORLD_DOMAIN');

  /// 장소 검색 → 좌표
  static Future<NLatLng?> searchLocation(String query) async {
    if (apiKey.isEmpty) {
      debugPrint('[VWORLD] VWORLD_KEY가 비어 있습니다. --dart-define으로 키를 넣어주세요.');
    }
    final url = Uri.https('api.vworld.kr', '/req/search', {
      'service': 'search',
      'request': 'search',
      'version': '2.0',
      'crs': 'EPSG:4326',
      'size': '1',
      'page': '1',
      'query': query,
      'type': 'PLACE',
      'format': 'json',
      'key': apiKey,
      if (domain.isNotEmpty) 'domain': domain,
    });

    try {
      final response = await http.get(url);
      final data = json.decode(utf8.decode(response.bodyBytes));
      final res = data['response'];
      if (res['status'] == 'OK') {
        final items = res['result']['items'] as List;
        if (items.isNotEmpty) {
          final x = double.parse(items[0]['point']['x'].toString()); // 경도
          final y = double.parse(items[0]['point']['y'].toString()); // 위도
          return NLatLng(y, x);
        }
      } else {
        debugPrint('[VWORLD 검색] status=${res['status']} error=${res['error']}');
      }
    } catch (e) {
      debugPrint('[VWORLD 검색] 예외: $e');
    }
    return null;
  }
}