// 공동주택 공시가격 조회 (브이월드 NED API · 국토교통부 공동주택가격정보)
//
// 1) 지번 주소 → PNU(필지고유번호 19자리)   : 브이월드 검색 API
// 2) PNU → 동·호별 공시가격 목록            : /ned/data/getApartHousingPriceAttr
//
// 키는 지도 검색과 같은 VWORLD_KEY를 씁니다 (--dart-define=VWORLD_KEY=...)
// ※ 브이월드 개발자센터에서 '공동주택가격정보' API 사용 신청이 되어 있어야 해요.
// ※ numOfRows는 최대 1000이라서 1000개씩 페이지로 나눠 받아요.
// ※ 모든 단계에서 [공시가격] 로그를 남깁니다 (키는 로그에서 가림).
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

  /// 로그용: 주소에서 key를 빼고 보여줌
  static String _safe(Uri u) {
    final q = Map<String, String>.from(u.queryParameters)..remove('key');
    return u.replace(queryParameters: q).toString();
  }

  /// 로그용: 긴 응답은 앞부분만
  static String _cut(String s, [int n = 400]) =>
      s.length > n ? '${s.substring(0, n)}…' : s;

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
    debugPrint('[공시가격] 1) PNU 검색 시작: $parcelAddress');
    if (_key.isEmpty) {
      debugPrint('[공시가격] VWORLD_KEY가 비어 있어요 (--dart-define 확인)');
      return null;
    }
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
    debugPrint('[공시가격] 요청: ${_safe(url)}');
    try {
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      final body = utf8.decode(res.bodyBytes);
      debugPrint('[공시가격] PNU 검색 응답 ${res.statusCode}: ${_cut(body)}');
      final data = json.decode(body);
      final r = data['response'];
      if (r?['status'] == 'OK') {
        final items = r['result']['items'] as List;
        if (items.isEmpty) {
          debugPrint('[공시가격] PNU 검색 결과 0건 → 주소를 확인해 주세요');
          return null;
        }
        final pnu = items.first['id']?.toString();
        debugPrint('[공시가격] PNU 찾음: $pnu');
        return pnu;
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
    if (list.isEmpty && year == null) {
      debugPrint('[공시가격] $y년 자료 없음 → ${y - 1}년으로 다시 조회');
      list = await _fetch(pnu, y - 1);
    }
    return list;
  }

  static Future<List<OfficialPrice>> _fetch(String pnu, int year) async {
    debugPrint('[공시가격] 2) 공시가격 조회 시작: pnu=$pnu, 연도=$year');
    const rows = 1000; // 브이월드 최대값 (1~1000)
    final out = <OfficialPrice>[];
    var otherYear = 0; // 다른 연도라서 뺀 개수

    for (var page = 1; page <= 10; page++) {
      final url = Uri.https('api.vworld.kr', '/ned/data/getApartHousingPriceAttr', {
        'pnu': pnu,
        'stdrYear': '$year',
        'format': 'json',
        'numOfRows': '$rows',
        'pageNo': '$page',
        'key': _key,
        if (_domain.isNotEmpty) 'domain': _domain,
      });
      if (page == 1) debugPrint('[공시가격] 요청: ${_safe(url)}');

      List fields = const [];
      try {
        final res = await http.get(url).timeout(const Duration(seconds: 8));
        final body = utf8.decode(res.bodyBytes);
        if (page == 1) debugPrint('[공시가격] 공시가격 응답 ${res.statusCode}: ${_cut(body)}');
        final data = json.decode(body);
        final root = data['apartHousingPrices'];
        if (root == null) {
          debugPrint('[공시가격] 응답에 apartHousingPrices가 없어요 (위 응답 원문 확인)');
          break;
        }
        if (root['field'] == null && root['resultCode'] != null) {
          debugPrint('[공시가격] API 오류: ${root['resultCode']} ${root['resultMsg']}');
          break;
        }
        var f = root['field'];
        if (f is Map) f = [f];
        if (f is! List || f.isEmpty) {
          if (page == 1) debugPrint('[공시가격] field 목록이 비어 있어요 (totalCount: ${root['totalCount']})');
          break;
        }
        fields = f;
        if (page == 1) {
          debugPrint('[공시가격] 첫 항목 필드: ${(fields.first as Map).keys.toList()}');
        }
        debugPrint('[공시가격] $page페이지: ${fields.length}개 받음 (전체 ${root['totalCount']})');
      } catch (e) {
        debugPrint('[공시가격] 조회 예외: $e');
        break;
      }

      for (final f in fields) {
        final itemYear = int.tryParse('${f['stdrYear'] ?? ''}');
        if (itemYear != null && itemYear != year) {
          otherYear++;
          continue; // 다른 연도 자료는 제외
        }
        final price = int.tryParse('${f['pblntfPc'] ?? ''}'.replaceAll(',', ''));
        if (price == null) continue;
        out.add(OfficialPrice(
          price: price,
          year: itemYear ?? year,
          aptName: f['aphusNm']?.toString(),
          dong: f['dongNm']?.toString(),
          ho: f['hoNm']?.toString(),
          areaM2: double.tryParse('${f['prvuseAr'] ?? ''}'),
        ));
      }

      if (fields.length < rows) break; // 마지막 페이지
    }

    debugPrint('[공시가격] 가격을 읽은 항목 ${out.length}개 (다른 연도 제외 $otherYear개)');
    return out;
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
    if (list.isEmpty) {
      debugPrint('[공시가격] 결과 없음 → 추정값으로 계산해요');
      return null;
    }

    // '101동'↔'101', '제603'↔'603호'가 같게 보이도록 숫자·영문만 비교
    String norm(String? s) => (s ?? '').replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
    if (dong != null && ho != null) {
      for (final p in list) {
        if (norm(p.dong) == norm(dong) && norm(p.ho) == norm(ho)) {
          debugPrint('[공시가격] 3) 동·호 일치: ${p.dong} ${p.ho} → ${p.price}원 (${p.year}년)');
          return p;
        }
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
    final picked = pool[pool.length ~/ 2];
    debugPrint('[공시가격] 3) 면적 기준 선택: 전용 ${picked.areaM2}㎡, '
        '${pool.length}세대 중간값 → ${picked.price}원 (${picked.year}년)');
    return picked;
  }
}