// lib/services/complex_repository.dart
//
// 단지(아파트·연립다세대) 최근 실거래 데이터 저장소
//   데이터: assets/data/complexes.json  (tools/fetch_trades.py → tools/geocode_complexes.py 로 생성)
//   - 가격(price)은 json에서 "만원" 단위 → 여기서 "원"으로 바꿔서 넘겨줌
//
// 화면에서는 이 세 가지만 쓰면 됩니다.
//   ComplexRepository.inZone(구역ID)     → 그 정비구역 안 단지 목록 (구역 카드)
//   ComplexRepository.inBounds(화면범위)  → 화면 안 단지 목록 (지도 마커)
//   ComplexRepository.toFavorite(단지)    → 찜할 때 FavoriteComplex로 변환

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../models/favorite_complex.dart';
import '../tax/region_rules.dart';

/// 단지 하나의 최근 실거래 정보
class ComplexInfo {
  final String id; // "시도|시군구|동|지번|단지명" (찜 구분 키)
  final String name; // 단지명
  final String type; // 아파트 / 연립다세대
  final String sido; // 서울특별시 / 인천광역시 / 경기도
  final String sigungu; // 마포구, 수원시 장안구 …
  final String address; // 지번 주소
  final double lat, lng;

  final String? zoneId; // 소속 정비구역 (없으면 null)
  final String? zoneName;
  final String? zoneStage;

  final int priceWon; // 최근 거래가 (원)
  final String dealDate; // yyyy-MM-dd
  final double? areaM2; // 전용면적
  final String? floor;
  final String? buildYear;
  final int dealCount; // 조회 기간 거래 수
  final String? pnu; // 필지고유번호 (공시가격 조회용, 없을 수 있음)

  const ComplexInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.sido,
    required this.sigungu,
    required this.address,
    required this.lat,
    required this.lng,
    required this.zoneId,
    required this.zoneName,
    required this.zoneStage,
    required this.priceWon,
    required this.dealDate,
    required this.areaM2,
    required this.floor,
    required this.buildYear,
    required this.dealCount,
    required this.pnu,
  });

  bool get isApartment => type == '아파트';

  /// 전용면적 → 평 (1평 = 3.3058㎡)
  double? get pyeong => areaM2 == null ? null : areaM2! / 3.3058;

  factory ComplexInfo.fromJson(Map<String, dynamic> j) {
    final idParts = (j['id'] ?? '').toString().split('|');
    final price = j['price'];
    return ComplexInfo(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      type: (j['type'] ?? '').toString(),
      sido: idParts.isNotEmpty ? idParts[0] : '',
      sigungu: idParts.length > 1 ? idParts[1] : '',
      address: (j['address'] ?? '').toString(),
      lat: (j['lat'] as num).toDouble(),
      lng: (j['lng'] as num).toDouble(),
      zoneId: j['zoneId'] as String?,
      zoneName: j['zoneName'] as String?,
      zoneStage: j['zoneStage'] as String?,
      priceWon: price is num ? price.toInt() * 10000 : 0, // 만원 → 원
      dealDate: (j['date'] ?? '').toString(),
      areaM2: (j['area'] as num?)?.toDouble(),
      floor: j['floor']?.toString(),
      buildYear: j['buildYear']?.toString(),
      dealCount: (j['count'] as num?)?.toInt() ?? 1,
      pnu: (j['pnu'] as String?)?.isNotEmpty == true ? j['pnu'] as String : null,
    );
  }
}

class ComplexRepository {
  static const _assetPath = 'assets/data/complexes.json';

  static List<ComplexInfo>? _all;
  static Map<String, List<ComplexInfo>>? _byZone;
  static Future<void>? _loading;

  /// 앱 시작 후 한 번만 읽음 (여러 곳에서 동시에 불러도 한 번만 실행)
  static Future<void> _ensureLoaded() {
    return _loading ??= () async {
      final raw = await rootBundle.loadString(_assetPath);
      // 6MB 가까운 JSON이라 파싱은 백그라운드 isolate에서
      final List list = await compute(_decode, raw);
      final all = <ComplexInfo>[];
      for (final e in list) {
        try {
          all.add(ComplexInfo.fromJson(Map<String, dynamic>.from(e as Map)));
        } catch (err) {
          debugPrint('[단지] 건너뜀: $err');
        }
      }
      final byZone = <String, List<ComplexInfo>>{};
      for (final c in all) {
        if (c.zoneId != null) (byZone[c.zoneId!] ??= []).add(c);
      }
      _all = all;
      _byZone = byZone;
      debugPrint('[단지] ${all.length}개 로드 (정비구역 안 ${byZone.values.fold<int>(0, (s, l) => s + l.length)}개)');
    }();
  }

  static List _decode(String raw) => json.decode(raw) as List;

  /// 미리 읽어 두기 (지도 화면이 처음 뜰 때 호출하면 첫 터치가 빨라짐)
  static Future<void> preload() => _ensureLoaded();

  /// 정비구역 안 단지 목록 (최근 거래일 순)
  static Future<List<ComplexInfo>> inZone(String zoneId) async {
    await _ensureLoaded();
    final list = [...?_byZone![zoneId]];
    list.sort((a, b) => b.dealDate.compareTo(a.dealDate));
    return list;
  }

  /// 화면 범위 안 단지 목록 (지도 마커용). [limit]개까지만.
  static Future<List<ComplexInfo>> inBounds(NLatLngBounds b, {int limit = 300}) async {
    await _ensureLoaded();
    final out = <ComplexInfo>[];
    for (final c in _all!) {
      if (c.lat >= b.southLatitude &&
          c.lat <= b.northLatitude &&
          c.lng >= b.westLongitude &&
          c.lng <= b.eastLongitude) {
        out.add(c);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  /// 찜할 때 관심 단지 모델로 변환
  static FavoriteComplex toFavorite(ComplexInfo c) {
    final sido = c.sido.contains('인천')
        ? Sido.incheon
        : (c.sido.contains('경기') ? Sido.gyeonggi : Sido.seoul);
    final region = parseRegion(c.sido, c.sigungu) ??
        parseRegion(c.sido, _legacySigungu(c.sigungu)) ??
        Region(sido, c.sigungu); // 목록에 없으면 이름만 유지
    return FavoriteComplex(
      id: c.id,
      name: c.name,
      region: region,
      recentPrice: c.priceWon,
      dealDate: c.dealDate,
      areaM2: c.areaM2,
      zoneName: c.zoneName,
      stage: c.zoneStage,
      pnu: c.pnu,
      parcelAddress: c.address,
    );
  }

  /// 2026.7 인천 개편 전후 이름 차이 보정
  static String _legacySigungu(String s) => switch (s) {
        '서해구' => '서구',
        '서구' => '서해구',
        _ => s,
      };
}
