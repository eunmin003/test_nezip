import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;

/// V-world API 호출 모음.
///
/// 키는 코드에 직접 쓰지 않고 실행 옵션(--dart-define)으로 넣습니다.
///   --dart-define=VWORLD_KEY=발급받은키
///   --dart-define=VWORLD_DOMAIN=키 발급 때 등록한 서비스 URL
class VworldService {
  static const String apiKey = String.fromEnvironment('VWORLD_KEY');
  static const String domain = String.fromEnvironment('VWORLD_DOMAIN');

  /// 정비구역 레이어 ID.
  /// V-world 개발자센터 > 2D데이터 API 목록에서 '정비구역' 레이어 ID를 확인해 넣으세요.
  static const String zoneLayer = 'LT_C_UP201';

  static void _checkKey() {
    if (apiKey.isEmpty) {
      debugPrint('[VWORLD] VWORLD_KEY가 비어 있습니다. --dart-define으로 키를 넣어주세요.');
    }
  }

  // 1. 장소 검색 → 좌표
  static Future<NLatLng?> searchLocation(String query) async {
    _checkKey();
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

  // 2. 현재 화면 영역(BOX) 안의 정비구역 폴리곤 조회
  static Future<List<List<NLatLng>>> fetchZonesByBounds(
      NLatLngBounds bounds) async {
    _checkKey();
    final minX = bounds.southWest.longitude;
    final minY = bounds.southWest.latitude;
    final maxX = bounds.northEast.longitude;
    final maxY = bounds.northEast.latitude;

    // 2D 데이터 API: BOX(경도min,위도min,경도max,위도max), 결과 좌표도 EPSG:4326(경도,위도)
    final url = Uri.https('api.vworld.kr', '/req/data', {
      'service': 'data',
      'request': 'GetFeature',
      'data': zoneLayer,
      'key': apiKey,
      if (domain.isNotEmpty) 'domain': domain,
      'geomFilter': 'BOX($minX,$minY,$maxX,$maxY)',
      'crs': 'EPSG:4326',
      'format': 'json',
      'geometry': 'true',
      'attribute': 'true',
      'size': '1000',
      'page': '1',
    });

    final zoneList = <List<NLatLng>>[];

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        debugPrint('[VWORLD 구역] HTTP ${response.statusCode}: ${response.body}');
        return zoneList;
      }

      final data = json.decode(utf8.decode(response.bodyBytes));
      final res = data['response'];
      final status = res['status'];

      if (status == 'NOT_FOUND') return zoneList; // 영역 안에 구역이 없음
      if (status != 'OK') {
        // INCORRECT_KEY, 도메인 불일치, 잘못된 레이어 ID 등은 여기에 찍힙니다.
        debugPrint('[VWORLD 구역] status=$status error=${res['error']}');
        return zoneList;
      }

      final features =
          res['result']['featureCollection']['features'] as List? ?? [];

      for (final feature in features) {
        final geometry = feature['geometry'];
        if (geometry == null) continue;
        final coords = geometry['coordinates'] as List;

        // V-world는 대부분 MultiPolygon으로 응답합니다.
        // Polygon:      [ 외곽링, 구멍링... ]
        // MultiPolygon: [ [외곽링, 구멍링...], [외곽링, ...] ]
        final List<List> outerRings = switch (geometry['type']) {
          'Polygon' => [coords[0] as List],
          'MultiPolygon' => [for (final poly in coords) (poly as List)[0] as List],
          _ => const [],
        };

        for (final ring in outerRings) {
          final points = ring.map((c) => _toLatLng(c as List)).toList();
          if (points.length >= 3) zoneList.add(points);
        }
      }
      debugPrint('[VWORLD 구역] ${features.length}개 feature → 폴리곤 ${zoneList.length}개');
    } catch (e, st) {
      debugPrint('[VWORLD 구역] 예외: $e\n$st');
    }

    return zoneList;
  }

  /// [경도, 위도] → NLatLng. 혹시 [위도, 경도] 순서로 오면 뒤집어 줍니다(한국 범위 기준).
  static NLatLng _toLatLng(List c) {
    final a = (c[0] as num).toDouble();
    final b = (c[1] as num).toDouble();
    final looksSwapped = a > 30 && a < 45 && b > 120 && b < 135;
    return looksSwapped ? NLatLng(a, b) : NLatLng(b, a);
  }
}