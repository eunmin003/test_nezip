// 관심 단지 모델 + 앱 안에서 공유하는 찜 목록
import 'package:flutter/foundation.dart';
import '../tax/region_rules.dart';

class FavoriteComplex {
  final String id;
  final String name; // 단지명
  final Region region;
  final int recentPrice; // 최근 실거래가 (원)
  final String? dealDate; // 거래일
  final double? areaM2; // 전용면적
  final String? zoneName; // 소속 정비구역
  final String? stage; // 정비사업 추진단계
  final bool isSample;

  const FavoriteComplex({
    required this.id,
    required this.name,
    required this.region,
    required this.recentPrice,
    this.dealDate,
    this.areaM2,
    this.zoneName,
    this.stage,
    this.isSample = false,
  });
}

/// 지오코더·CSV의 '서울특별시' + '노원구' 같은 글자를 Region으로 바꿈
Region? parseRegion(String sidoText, String sigunguText) {
  Sido? sido;
  if (sidoText.contains('서울')) sido = Sido.seoul;
  if (sidoText.contains('인천')) sido = Sido.incheon;
  if (sidoText.contains('경기')) sido = Sido.gyeonggi;
  if (sido == null) return null;

  final list = kSigungu[sido]!;
  final s = sigunguText.trim();
  if (list.contains(s)) return Region(sido, s);
  for (final g in list) {
    if (g.endsWith(' $s') || g.replaceAll(' ', '') == s.replaceAll(' ', '')) {
      return Region(sido, g);
    }
  }
  for (final g in list) {
    if (s.isNotEmpty && g.startsWith(s)) return Region(sido, g);
  }
  return null;
}

/// 찜 목록 (지금은 앱을 끄면 사라짐 → 나중에 서버나 저장소 연결)
class FavoriteStore {
  FavoriteStore._();
  static final FavoriteStore instance = FavoriteStore._();

  final ValueNotifier<List<FavoriteComplex>> items = ValueNotifier(const []);

  bool contains(String id) => items.value.any((c) => c.id == id);

  void add(FavoriteComplex c) {
    if (contains(c.id)) return;
    items.value = [...items.value, c];
  }

  void remove(String id) {
    items.value = items.value.where((c) => c.id != id).toList();
  }

  void toggle(FavoriteComplex c) => contains(c.id) ? remove(c.id) : add(c);

  void loadSamples() {
    for (final c in sampleComplexes) {
      add(c);
    }
  }
}

/// 실거래가 API 연결 전 화면 확인용 예시 (실제 단지·가격 아님)
const List<FavoriteComplex> sampleComplexes = [
  FavoriteComplex(
    id: 'sample-1',
    name: '(예시) 동안구 A단지',
    region: Region(Sido.gyeonggi, '안양시 동안구'),
    recentPrice: 800000000,
    dealDate: '2026.10',
    areaM2: 84,
    zoneName: '(예시) 동안 재건축구역',
    stage: '조합설립인가',
    isSample: true,
  ),
  FavoriteComplex(
    id: 'sample-2',
    name: '(예시) 노원구 B단지',
    region: Region(Sido.seoul, '노원구'),
    recentPrice: 650000000,
    dealDate: '2026.09',
    areaM2: 59,
    zoneName: '(예시) 노원 재건축구역',
    stage: '사업시행인가',
    isSample: true,
  ),
  FavoriteComplex(
    id: 'sample-3',
    name: '(예시) 부평구 C단지',
    region: Region(Sido.incheon, '부평구'),
    recentPrice: 450000000,
    dealDate: '2026.10',
    areaM2: 84,
    zoneName: '(예시) 부평 재개발구역',
    stage: '관리처분계획인가',
    isSample: true,
  ),
];