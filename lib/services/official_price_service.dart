// 공동주택 공시가격 조회 (브이월드 NED API · 국토교통부 공동주택가격정보)
//
// 1) 지번 주소 → PNU(필지고유번호 19자리)   : 브이월드 검색 API
// 2) PNU → 동·호별 공시가격 목록            : /ned/data/getApartHousingPriceAttr
//
// 키는 지도 검색과 같은 VWORLD_KEY를 씁니다 (--dart-define=VWORLD_KEY=...)
// ※ 브이월드 개발자센터에서 '공동주택가격정보' API 사용 신청이 되어 있어야 해요.
// ※ 응답 필드 이름은 첫 실제 호출 때 debugPrint 로그로 한 번 확인해 주세요.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'vworld_services.dart';

class OfficialPrice {
  final int price; // 공시가격 (원)
  final int year; // 기준연도
  final String? aptName;
  final String? dong;
  final String? ho;
  final double? areaM2; // 전용면적

  const OfficialPrice({
    required this.price,
    required this.year,
    this.aptName,
    this.dong,
    this.ho,
    this.areaM2,
  });
}

class OfficialPriceService {
  static String get _key => VworldService.apiKey;
  static String get _domain => VworldService.domain;

  /// 법정동코드(10자리) + 지번 → PNU 19자리
  /// 예) 4117310300 + 일반(1) + 본번 0123 + 부번 0004 = 4117310300101230004
  static String buildPnu({
    required String lawdCode10,
    required int bonbun,
    int bubun = 0,
    bool mountain = false,
  }) {
    return lawdCode10 +
        (mountain ? '2' : '1') +
        bonbun.toString().padLeft(4, '0') +
        bubun.toString().padLeft(4, '0');
  }

  /// 지번 주소(예: '경기도 안양시 동안구 평촌동 123-4') → PNU
  static Future<String?> findPnu(String parcelAddress) async {
    final url = Uri.https('api.vworld.kr', '/req/search', {
      'service': 'search',
      'request': 'search',
      'version': '2.0',
      'size': '1',
      'page': '1',
      'query': parcelAddress,
      'type': 'ADDRESS',
      'category': 'PARCEL',
      'format': 'json',
      'key': _key,
      if (_domain.isNotEmpty) 'domain': _domain,
    });
    try {
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      final data = json.decode(utf8.decode(res.bodyBytes));
      final r = data['response'];
      if (r?['status'] == 'OK') {
        final items = r['result']['items'] as List;
        if (items.isNotEmpty) return items.first['id']?.toString();
      } else {
        debugPrint('[공시가격] PNU 검색 실패: ${r?['status']} ${r?['error']}');
      }
    } catch (e) {
      debugPrint('[공시가격] PNU 검색 예외: $e');
    }
    return null;
  }

  /// PNU의 공동주택 공시가격 목록 (올해 자료가 없으면 작년 자료)
  static Future<List<OfficialPrice>> fetchApartPrices(String pnu, {int? year}) async {
    final y = year ?? DateTime.now().year;
    var list = await _fetch(pnu, y);
    if (list.isEmpty && year == null) list = await _fetch(pnu, y - 1);
    return list;
  }

  static Future<List<OfficialPrice>> _fetch(String pnu, int year) async {
    final url = Uri.https('api.vworld.kr', '/ned/data/getApartHousingPriceAttr', {
      'pnu': pnu,
      'stdrYear': '$year',
      'format': 'json',
      'numOfRows': '1000',
      'pageNo': '1',
      'key': _key,
      if (_domain.isNotEmpty) 'domain': _domain,
    });
    try {
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      final data = json.decode(utf8.decode(res.bodyBytes));
      final root = data['apartHousingPrices'];
      if (root == null) {
        debugPrint('[공시가격] 응답에 apartHousingPrices가 없어요: ${res.body.length > 300 ? res.body.substring(0, 300) : res.body}');
        return [];
      }
      var fields = root['field'];
      if (fields is Map) fields = [fields];
      if (fields is! List) return [];

      final out = <OfficialPrice>[];
      for (final f in fields) {
        final price = int.tryParse('${f['pblntfPc'] ?? ''}'.replaceAll(',', ''));
        if (price == null) continue;
        out.add(OfficialPrice(
          price: price,
          year: int.tryParse('${f['stdrYear'] ?? year}') ?? year,
          aptName: f['aphusNm']?.toString(),
          dong: f['dongNm']?.toString(),
          ho: f['hoNm']?.toString(),
          areaM2: double.tryParse('${f['prvuseAr'] ?? ''}'),
        ));
      }
      return out;
    } catch (e) {
      debugPrint('[공시가격] 조회 예외: $e');
      return [];
    }
  }

  /// 한 세대의 공시가격 고르기
  /// 동·호가 맞으면 그 값, 아니면 전용면적이 가장 비슷한 세대들의 중간값
  static Future<OfficialPrice?> fetchFor({
    required String pnu,
    String? dong,
    String? ho,
    double? areaM2,
  }) async {
    final list = await fetchApartPrices(pnu);
    if (list.isEmpty) return null;

    String norm(String? s) => (s ?? '').replaceAll(RegExp(r'[^0-9A-Za-z가-힣]'), '');
    if (dong != null && ho != null) {
      for (final p in list) {
        if (norm(p.dong).contains(norm(dong)) && norm(p.ho) == norm(ho)) return p;
      }
    }

    var pool = list;
    final target = areaM2;
    if (target != null) {
      final withArea = list.where((p) => p.areaM2 != null).toList();
      if (withArea.isNotEmpty) {
        withArea.sort((a, b) =>
            (a.areaM2! - target).abs().compareTo((b.areaM2! - target).abs()));
        final nearest = withArea.first.areaM2!;
        pool = withArea.where((p) => (p.areaM2! - nearest).abs() < 0.5).toList();
      }
    }
    pool.sort((a, b) => a.price.compareTo(b.price));
    return pool[pool.length ~/ 2];
  }
}
