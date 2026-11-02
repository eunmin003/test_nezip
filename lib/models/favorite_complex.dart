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

  // 공시가격 조회용 (실거래가 데이터에서 채움)
  final String? pnu; // 필지고유번호 19자리
  final String? parcelAddress; // 지번 주소 (PNU가 없을 때 검색용)
  final String? dong; // 동 (예: 101동)
  final String? ho; // 호 (예: 1203호)
  final int? officialPrice; // 이미 알고 있는 공시가격 (원)

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
    this.pnu,
    this.parcelAddress,
    this.dong,
    this.ho,
    this.officialPrice,
  });

  /// 공시가격 API로 조회할 수 있는 정보가 있는지
  bool get canLookupOfficialPrice =>
      (pnu != null && pnu!.length == 19) || (parcelAddress?.isNotEmpty ?? false);
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
    name: '관양현대',
    region: Region(Sido.gyeonggi, '안양시 동안구'),
    recentPrice: 1040000000, // 2026.06.22 전용 84.47㎡ 8층
    dealDate: '2026.06',
    areaM2: 84,
    zoneName: '관양현대아파트 재건축',
    stage: '사업시행인가',
    isSample: true,
    parcelAddress: '경기 안양시 동안구 관양동 1396',
  ),
  FavoriteComplex(
    id: 'sample-2',
    name: '하계 한신동성',
    region: Region(Sido.seoul, '노원구'),
    recentPrice: 1030000000, // 2026.07.08 전용 112.24㎡ 10층 (만원 단위 확인 필요)
    dealDate: '2026.07',
    areaM2: 112,
    zoneName: '하계한신동성아파트 재건축',
    stage: '추진위원회승인',
    isSample: true,
    parcelAddress: '서울 노원구 하계동 256-5',
  ),
  FavoriteComplex(
    id: 'sample-3',
    name: '효성동 중앙공영',
    region: Region(Sido.incheon, '계양구'),
    recentPrice: 110000000, // 2026.01.31 전용 56.72㎡ 6층 (만원 단위 확인 필요)
    dealDate: '2026.01',
    areaM2: 57,
    zoneName: '효성동 중앙공영아파트 소규모재건축',
    stage: '조합설립인가',
    isSample: true,
    parcelAddress: '인천 계양구 효성동 293-1',
  ),
];