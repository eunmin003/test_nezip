// lib/services/vworld_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../models/zone_model.dart';
import 'api_service.dart';

class VworldService {
  static const String apiKey = 'FABE0537-B493-34BA-9AA4-F970193ACE9A';
  static Map<String, ZoneDetailInfo>? _cachedCsvMap;

  /// 현재 카메라 BBOX(남서좌표, 북동좌표) 범위의 구역만 실시간 호출
  static Future<List<ZonePolygonModel>> fetchZonesByBounds(NLatLngBounds bounds) async {
    _cachedCsvMap ??= await ApiService.loadCsvData();

    // BBOX 포맷: minX,minY,maxX,maxY (경도,위도,경도,위도)
    final minLng = bounds.southWest.longitude;
    final minLat = bounds.southWest.latitude;
    final maxLng = bounds.northEast.longitude;
    final maxLat = bounds.northEast.latitude;

    final url = Uri.parse(
      'https://api.vworld.kr/req/wfs?SERVICE=WFS&REQUEST=GetFeature&TYPENAME=lt_c_uq111'
          '&OUTPUT=application/json&SRSNAME=EPSG:4326'
          '&BBOX=$minLng,$minLat,$maxLng,$maxLat,EPSG:4326'
          '&KEY=$apiKey',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> body = jsonDecode(decodedBody);
        final List<dynamic> features = body['features'] ?? [];

        List<ZonePolygonModel> polygonList = [];

        for (var feature in features) {
          final properties = feature['properties'] ?? {};
          final name = (properties['nam'] ?? properties['dsg_nam'] ?? properties['lbl'] ?? '정비구역')
              .toString()
              .trim();
          final geometry = feature['geometry'];

          // 구역명 CSV 매칭
          ZoneDetailInfo? matchedInfo = _cachedCsvMap?[name];
          if (matchedInfo == null && _cachedCsvMap != null) {
            for (var entry in _cachedCsvMap!.entries) {
              if (name.contains(entry.key) || entry.key.contains(name)) {
                matchedInfo = entry.value;
                break;
              }
            }
          }

          if (geometry != null) {
            final type = geometry['type'];
            if (type == 'Polygon') {
              List<dynamic> rawCoords = geometry['coordinates'][0];
              final points = _parseCoords(rawCoords);
              if (points.length >= 3) {
                polygonList.add(ZonePolygonModel(name: name, coordinates: points, detailInfo: matchedInfo));
              }
            } else if (type == 'MultiPolygon') {
              for (var poly in geometry['coordinates']) {
                List<dynamic> rawCoords = poly[0];
                final points = _parseCoords(rawCoords);
                if (points.length >= 3) {
                  polygonList.add(ZonePolygonModel(name: name, coordinates: points, detailInfo: matchedInfo));
                }
              }
            }
          }
        }
        return polygonList;
      }
    } catch (e) {
      print("BBOX 구역 로딩 오류: $e");
    }
    return [];
  }

  /// 주소 검색
  static Future<NLatLng?> searchLocation(String query) async {
    final searchUrl = Uri.parse(
      'https://api.vworld.kr/req/search?service=search&request=search&version=2.0&crs=EPSG:4326&size=1&type=DISTRICT&category=L4&query=$query&key=$apiKey',
    );

    try {
      final response = await http.get(searchUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final items = data['response']?['result']?['items'];

        if (items != null && items.isNotEmpty) {
          final point = items[0]['point'];
          return NLatLng(double.parse(point['y']), double.parse(point['x']));
        }
      }
    } catch (e) {
      print("주소 검색 오류: $e");
    }
    return null;
  }

  static List<NLatLng> _parseCoords(List<dynamic> rawCoords) {
    List<NLatLng> points = [];
    for (var coord in rawCoords) {
      double lng = (coord[0] as num).toDouble();
      double lat = (coord[1] as num).toDouble();
      if (lat >= 33.0 && lat <= 39.0 && lng >= 124.0 && lng <= 132.0) {
        points.add(NLatLng(lat, lng));
      } else if (lng >= 33.0 && lng <= 39.0 && lat >= 124.0 && lat <= 132.0) {
        points.add(NLatLng(lng, lat));
      }
    }
    return points;
  }
}