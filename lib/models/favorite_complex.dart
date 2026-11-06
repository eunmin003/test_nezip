// 관심 단지 모델 + 앱 안에서 공유하는 찜 목록 (기기에 영구 저장)
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// 저장용: 객체 → JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sido': region.sido.name, // 예: 'gyeonggi'
    'sigungu': region.sigungu, // 예: '안양시 동안구'
    'recentPrice': recentPrice,
    'dealDate': dealDate,
    'areaM2': areaM2,
    'zoneName': zoneName,
    'stage': stage,
    'isSample': isSample,
    'pnu': pnu,
    'parcelAddress': parcelAddress,
    'dong': dong,
    'ho': ho,
    'officialPrice': officialPrice,
  };

  /// 복원용: JSON → 객체
  factory FavoriteComplex.fromJson(Map<String, dynamic> j) => FavoriteComplex(
    id: j['id'] as String,
    name: j['name'] as String,
    region: Region(
      Sido.values.byName(j['sido'] as String),
      j['sigungu'] as String,
    ),
    recentPrice: (j['recentPrice'] as num).toInt(),
    dealDate: j['dealDate'] as String?,
    areaM2: (j['areaM2'] as num?)?.toDouble(),
    zoneName: j['zoneName'] as String?,
    stage: j['stage'] as String?,
    isSample: j['isSample'] as bool? ?? false,
    pnu: j['pnu'] as String?,
    parcelAddress: j['parcelAddress'] as String?,
    dong: j['dong'] as String?,
    ho: j['ho'] as String?,
    officialPrice: (j['officialPrice'] as num?)?.toInt(),
  );
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

/// 찜 목록 — 기기에 저장되어 앱을 다시 켜도 유지됨 + 로그인한 사용자별로 따로 저장
///
/// - 로그인 안 함: 기기용 목록 (저장 키 'favorites_v1')
/// - 로그인함   : 그 사람 목록 (저장 키 'favorites_v1_카카오회원번호')
/// - 로그인할 때 기기용 목록에 있던 단지는 그 사람 목록으로 합쳐짐 (기기용 목록은 비움)
/// - 로그아웃하면 기기용 목록으로 돌아가고, 다시 로그인하면 내 목록이 그대로 돌아옴
///
/// 사용법: main()에서 runApp 전에 `await FavoriteStore.instance.init();`
///        로그인 상태가 바뀌면 AuthService가 `switchUser(회원번호 또는 null)`을 불러줌
class FavoriteStore {
  FavoriteStore._();
  static final FavoriteStore instance = FavoriteStore._();

  static const _guestKey = 'favorites_v1';
  bool _loaded = false;
  String? _userId; // 지금 목록의 주인 (null이면 기기용 목록)

  final ValueNotifier<List<FavoriteComplex>> items = ValueNotifier(const []);

  /// 지금 목록을 저장하는 키
  String get _key => _keyFor(_userId);
  static String _keyFor(String? userId) => userId == null ? _guestKey : '${_guestKey}_$userId';

  /// 지금 목록의 주인 (로그인한 회원번호, 로그인 안 했으면 null)
  String? get currentUserId => _userId;

  /// 앱 시작 시 기기용 찜 목록 불러오기 (로그인 상태 복원은 AuthService가 이어서 함)
  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      items.value = await _read(prefs, _guestKey);
    } catch (e) {
      debugPrint('[찜] 불러오기 실패 (빈 목록으로 시작): $e');
    }
  }

  /// 로그인·로그아웃할 때 목록 바꾸기. userId가 null이면 기기용 목록으로.
  Future<void> switchUser(String? userId) async {
    if (userId == _userId) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      if (userId == null) {
        _userId = null;
        items.value = await _read(prefs, _guestKey);
        debugPrint('[찜] 로그아웃 → 기기용 목록 ${items.value.length}개');
        return;
      }

      // 내 목록 + 로그인 전에 기기에서 찜한 단지(중복 제외)
      final mine = await _read(prefs, _keyFor(userId));
      final guest = await _read(prefs, _guestKey);
      final ids = mine.map((c) => c.id).toSet();
      final moved = guest.where((c) => !ids.contains(c.id)).toList();

      _userId = userId;
      items.value = [...mine, ...moved];
      await _save();
      if (guest.isNotEmpty) await prefs.remove(_guestKey); // 옮겼으니 기기용 목록은 비움

      debugPrint('[찜] 로그인 → 내 목록 ${items.value.length}개 '
          '(기기에서 옮겨 온 단지 ${moved.length}개)');
    } catch (e) {
      debugPrint('[찜] 목록 전환 실패: $e');
    }
  }

  /// 회원탈퇴: 그 사람의 찜 목록만 삭제
  Future<void> deleteUserData(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFor(userId));
      if (_userId == userId) {
        _userId = null;
        items.value = await _read(prefs, _guestKey);
      }
      debugPrint('[찜] 회원 $userId의 찜 목록 삭제');
    } catch (e) {
      debugPrint('[찜] 찜 목록 삭제 실패: $e');
    }
  }

  /// 저장된 목록 읽기 (예시 단지는 코드의 최신 값으로 바꿔 끼움)
  Future<List<FavoriteComplex>> _read(SharedPreferences prefs, String key) async {
    final raw = prefs.getString(key);
    if (raw == null) {
      debugPrint('[찜] 저장된 목록 없음 ($key)');
      return [];
    }
    final out = <FavoriteComplex>[];
    for (final e in jsonDecode(raw) as List) {
      try {
        out.add(FavoriteComplex.fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (err) {
        debugPrint('[찜] 단지 하나를 읽지 못해 건너뜀: $err');
      }
    }

    final latest = {for (final s in sampleComplexes) s.id: s};
    var refreshed = 0;
    final merged = out.map((c) {
      final newer = c.isSample ? latest[c.id] : null;
      if (newer == null) return c;
      refreshed++;
      return newer;
    }).toList();

    if (refreshed > 0) {
      await prefs.setString(key, jsonEncode(merged.map((c) => c.toJson()).toList()));
    }
    debugPrint('[찜] 저장된 단지 ${merged.length}개 불러옴 ($key, 예시 단지 $refreshed개 최신값으로 교체)');
    return merged;
  }

  /// 바뀔 때마다 기기에 저장 (지금 목록의 주인 키로)
  Future<void> _save() async {
    final key = _key;
    final list = items.value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(list.map((c) => c.toJson()).toList()));
      debugPrint('[찜] 저장: ${list.length}개 ($key)');
    } catch (e) {
      debugPrint('[찜] 저장 실패: $e');
    }
  }

  bool contains(String id) => items.value.any((c) => c.id == id);

  void add(FavoriteComplex c) {
    if (contains(c.id)) return;
    items.value = [...items.value, c];
    _save();
  }

  void remove(String id) {
    if (!contains(id)) return;
    items.value = items.value.where((c) => c.id != id).toList();
    _save();
  }

  void toggle(FavoriteComplex c) => contains(c.id) ? remove(c.id) : add(c);

  void loadSamples() {
    for (final c in sampleComplexes) {
      add(c);
    }
  }
}

/// 예시 단지 — 실제 정비사업 단지 (가격: 국토부 실거래가, 단계: 공개 자료 기준)
/// 값을 고치면 다음 실행 때 기기에 저장된 예시 단지도 자동으로 최신값으로 바뀜
const List<FavoriteComplex> sampleComplexes = [
  FavoriteComplex(
    id: 'sample-1',
    name: '관양현대',
    region: Region(Sido.gyeonggi, '안양시 동안구'),
    recentPrice: 1040000000, // 2026.06.22 전용 84.47㎡ 8층
    dealDate: '2026.06',
    areaM2: 84.47,
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
    areaM2: 112.24,
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
    areaM2: 56.72,
    zoneName: '효성동 중앙공영아파트 소규모재건축',
    stage: '조합설립인가',
    isSample: true,
    parcelAddress: '인천 계양구 효성동 293-1',
  ),
];