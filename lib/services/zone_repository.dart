// lib/services/zone_repository.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../models/redev_zone.dart';

/// 앱에 포함된 정비구역 GeoJSON(assets/data/redevelopment_zones.geojson)을 읽어
/// 화면 범위 안의 구역을 돌려줍니다. 서버 없이 동작합니다.
///
/// 나중에 서버를 붙이면 [_loadAll]에서 파일 대신 서버 응답을 읽도록 바꾸면 됩니다.
class ZoneRepository {
  static const _assetPath = 'assets/data/redevelopment_zones.geojson';

  static List<RedevZone>? _cache;

  static Future<List<RedevZone>> _loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString(_assetPath);
    // 1MB 가까운 JSON이라 파싱은 백그라운드 isolate에서
    final Map<String, dynamic> fc = await compute(_decode, raw);
    final features = fc['features'] as List;
    _cache = [
      for (final f in features) RedevZone.fromFeature(f as Map<String, dynamic>)
    ].where((z) => z.rings.isNotEmpty).toList();
    debugPrint('[ZONE] 정비구역 ${_cache!.length}개 로드');
    return _cache!;
  }

  static Map<String, dynamic> _decode(String raw) =>
      json.decode(raw) as Map<String, dynamic>;

  /// 화면(bounds) 안에 걸쳐 있는 정비구역 목록
  static Future<List<RedevZone>> zonesIn(NLatLngBounds bounds) async {
    final all = await _loadAll();
    return all.where((z) => z.intersects(bounds)).toList();
  }
}
