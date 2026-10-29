// lib/models/redev_zone.dart

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 폴리곤 하나 (외곽선 + 구멍)
class ZoneRing {
  final List<NLatLng> outer;
  final List<List<NLatLng>> holes;

  const ZoneRing(this.outer, this.holes);
}

/// 지정·고시된 정비구역 한 곳
/// (국토교통부 '도시및주거환경정비/정비구역' SHP + 추진단계 CSV를 합친 데이터)
class RedevZone {
  final String id;
  final String name; // 구역명 (원본에 이름이 없으면 '정비구역')
  final String type; // 재개발 / 재건축 / 주거환경개선 / 정비사업
  final String sido; // 서울특별시, 인천광역시
  final String sgg; // 구 이름
  final String noticeDate; // 고시일 (yyyy-MM-dd, 없으면 빈 문자열)
  final String remark; // 원본 비고

  // CSV에서 매칭된 정보 (매칭 안 되면 null)
  final String? stage; // 현 사업 추진단계
  final String? bizType; // 사업유형
  final String? executor; // 사업시행자
  final int? households; // 공급 예정 세대수

  final List<ZoneRing> rings;

  // 화면 범위 검사용 경계 상자
  final double minLat, minLng, maxLat, maxLng;

  RedevZone({
    required this.id,
    required this.name,
    required this.type,
    required this.sido,
    required this.sgg,
    required this.noticeDate,
    required this.remark,
    required this.stage,
    required this.bizType,
    required this.executor,
    required this.households,
    required this.rings,
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
  });

  bool get hasName => name.isNotEmpty && name != '정비구역';

  bool intersects(NLatLngBounds b) =>
      maxLat >= b.southLatitude &&
      minLat <= b.northLatitude &&
      maxLng >= b.westLongitude &&
      minLng <= b.eastLongitude;

  /// 추진단계에 따른 지도 색상
  Color get color => stageColor(stage);

  static Color stageColor(String? stage) {
    if (stage == null) return const Color(0xFFE53935); // 단계 정보 없음: 빨강
    if (stage.contains('착공') || stage.contains('준공')) return const Color(0xFF8E24AA); // 보라
    if (stage.contains('관리처분')) return const Color(0xFFD81B60); // 진분홍
    if (stage.contains('사업시행')) return const Color(0xFFF4511E); // 주황
    if (stage.contains('조합') || stage.contains('시행자')) return const Color(0xFFFB8C00); // 연주황
    return const Color(0xFFFDD835); // 추진위·정비구역지정: 노랑
  }

  factory RedevZone.fromFeature(Map<String, dynamic> f) {
    final p = f['properties'] as Map<String, dynamic>;
    final g = f['geometry'] as Map<String, dynamic>;

    // Polygon: [ring, ring...] / MultiPolygon: [[ring, ring...], ...]
    final List polys =
        g['type'] == 'Polygon' ? [g['coordinates']] : g['coordinates'] as List;

    double minLat = 90, minLng = 180, maxLat = -90, maxLng = -180;

    List<NLatLng> toRing(List coords) => coords.map((c) {
          final lng = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          if (lat < minLat) minLat = lat;
          if (lat > maxLat) maxLat = lat;
          if (lng < minLng) minLng = lng;
          if (lng > maxLng) maxLng = lng;
          return NLatLng(lat, lng);
        }).toList();

    final rings = <ZoneRing>[];
    for (final poly in polys) {
      final ringList = poly as List;
      if (ringList.isEmpty) continue;
      final outer = toRing(ringList.first as List);
      final holes = [for (final h in ringList.skip(1)) toRing(h as List)];
      if (outer.length >= 4) rings.add(ZoneRing(outer, holes));
    }

    return RedevZone(
      id: (p['id'] ?? '').toString(),
      name: (p['name'] ?? '정비구역').toString(),
      type: (p['type'] ?? '').toString(),
      sido: (p['sido'] ?? '').toString(),
      sgg: (p['sgg'] ?? '').toString(),
      noticeDate: (p['noticeDate'] ?? '').toString(),
      remark: (p['remark'] ?? '').toString(),
      stage: p['stage'] as String?,
      bizType: p['bizType'] as String?,
      executor: p['executor'] as String?,
      households: p['households'] as int?,
      rings: rings,
      minLat: minLat,
      minLng: minLng,
      maxLat: maxLat,
      maxLng: maxLng,
    );
  }
}
