import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:proj4dart/proj4dart.dart' as proj4;

class VworldService { // 클래스명 스펠링 확인 (VworldService 또는 VWorldService)
  static const String apiKey = 'YOUR_VWORLD_API_KEY';

  // 1. searchLocation 메서드 추가 (지오코더/검색 API)
  static Future<NLatLng?> searchLocation(String query) async {
    final url = Uri.parse(
      'https://api.vworld.kr/req/search?service=search&request=search&version=2.0&crs=EPSG:4326&size=1&page=1&query=${Uri.encodeComponent(query)}&type=PLACE&format=json&key=$apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['response']['status'] == 'OK') {
          final items = data['response']['result']['items'] as List;
          if (items.isNotEmpty) {
            double x = double.parse(items[0]['point']['x']); // 경도
            double y = double.parse(items[0]['point']['y']); // 위도
            return NLatLng(y, x);
          }
        }
      }
    } catch (e) {
      print('Location search error: $e');
    }
    return null;
  }

  // 2. fetchZonesByBounds 메서드 추가 (영역/BBOX 기반 구역 조회)
  static Future<List<List<NLatLng>>> fetchZonesByBounds(NLatLngBounds bounds) async {
    // bounds 영역(southWest, northEast)을 BBOX 파라미터 형식으로 추출
    final minX = bounds.southWest.longitude;
    final minY = bounds.southWest.latitude;
    final maxX = bounds.northEast.longitude;
    final maxY = bounds.northEast.latitude;

    final url = Uri.parse(
      'https://api.vworld.kr/req/wfs?service=WFS&version=1.1.0&request=GetFeature&typename=lt_c_up201&output=application/json&bbox=$minX,$minY,$maxX,$maxY,EPSG:4326&key=$apiKey',
    );

    List<List<NLatLng>> zoneList = [];

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List? ?? [];

        for (var feature in features) {
          final geometry = feature['geometry'];
          if (geometry != null && geometry['type'] == 'Polygon') {
            final rawCoords = geometry['coordinates'][0] as List;
            List<NLatLng> points = rawCoords.map((coord) {
              return NLatLng(
                (coord[1] as num).toDouble(), // 위도
                (coord[0] as num).toDouble(), // 경도
              );
            }).toList();

            if (points.isNotEmpty) {
              zoneList.add(points);
            }
          }
        }
      }
    } catch (e) {
      print('Fetch zones error: $e');
    }

    return zoneList;
  }
}