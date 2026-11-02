// 시범 지역(서울·인천·경기) 행정구역 + 조정대상지역 지정 이력
// 기준: 2025.10.16 지정(10·15 대책), 2026.7.1 추가 지정(국토교통부공고 제2026-882호)
// ※ 지정·해제가 바뀌면 아래 _seoulCore / _gg20251016 / _gg20260701 과 _periodsOf()만 고치면 됨

enum Sido { seoul, incheon, gyeonggi }

extension SidoLabel on Sido {
  String get label {
    switch (this) {
      case Sido.seoul:
        return '서울특별시';
      case Sido.incheon:
        return '인천광역시';
      case Sido.gyeonggi:
        return '경기도';
    }
  }
}

/// 시범 지역 시·군·구 목록 (2026.7.1 행정구역 기준)
const Map<Sido, List<String>> kSigungu = {
  Sido.seoul: [
    '강남구', '강동구', '강북구', '강서구', '관악구', '광진구', '구로구', '금천구',
    '노원구', '도봉구', '동대문구', '동작구', '마포구', '서대문구', '서초구', '성동구',
    '성북구', '송파구', '양천구', '영등포구', '용산구', '은평구', '종로구', '중구', '중랑구',
  ],
  Sido.incheon: [
    '제물포구', '영종구', '미추홀구', '연수구', '남동구', '부평구',
    '계양구', '서구', '검단구', '강화군', '옹진군',
  ],
  Sido.gyeonggi: [
    '수원시 장안구', '수원시 권선구', '수원시 팔달구', '수원시 영통구',
    '성남시 수정구', '성남시 중원구', '성남시 분당구',
    '안양시 만안구', '안양시 동안구',
    '안산시 상록구', '안산시 단원구',
    '고양시 덕양구', '고양시 일산동구', '고양시 일산서구',
    '용인시 처인구', '용인시 기흥구', '용인시 수지구',
    '부천시 원미구', '부천시 소사구', '부천시 오정구',
    '화성시 만세구', '화성시 효행구', '화성시 병점구', '화성시 동탄구',
    '의정부시', '광명시', '평택시', '동두천시', '과천시', '구리시', '남양주시',
    '오산시', '시흥시', '군포시', '의왕시', '하남시', '파주시', '이천시', '안성시',
    '김포시', '광주시', '양주시', '포천시', '여주시', '연천군', '가평군', '양평군',
  ],
};

class Region {
  final Sido sido;
  final String sigungu;
  const Region(this.sido, this.sigungu);

  String get label => '${sido.label} $sigungu';
}

// ───────────── 조정대상지역 지정 이력 ─────────────
class _Period {
  final DateTime from; // 지정일 (포함)
  final DateTime? until; // 해제일 (미포함), null이면 현재까지
  const _Period(this.from, [this.until]);
}

const Set<String> _seoulCore = {'강남구', '서초구', '송파구', '용산구'};

const Set<String> _gg20251016 = {
  '과천시', '광명시', '성남시 분당구', '성남시 수정구', '성남시 중원구',
  '수원시 영통구', '수원시 장안구', '수원시 팔달구', '안양시 동안구',
  '용인시 수지구', '의왕시', '하남시',
};

const Set<String> _gg20260701 = {'화성시 동탄구', '용인시 기흥구', '구리시'};

/// 서울 외 지역은 2023.1.5 이전 지정 이력이 복잡해서 기록하지 않음 → 사용자 확인
final DateTime kRecordStartOutsideSeoul = DateTime(2023, 1, 5);

/// 다주택 양도세 중과 유예 보완조치: 이 날까지 계약한 경우
final DateTime kGraceContractDeadline = DateTime(2026, 5, 9);

List<_Period> _periodsOf(Region r) {
  switch (r.sido) {
    case Sido.seoul:
      if (_seoulCore.contains(r.sigungu)) {
        return [_Period(DateTime(2017, 8, 3))];
      }
      return [
        _Period(DateTime(2017, 8, 3), DateTime(2023, 1, 5)),
        _Period(DateTime(2025, 10, 16)),
      ];
    case Sido.gyeonggi:
      if (_gg20251016.contains(r.sigungu)) return [_Period(DateTime(2025, 10, 16))];
      if (_gg20260701.contains(r.sigungu)) return [_Period(DateTime(2026, 7, 1))];
      return [];
    case Sido.incheon:
      return [];
  }
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

String formatDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

_Period? _periodAt(Region r, DateTime date) {
  final d = _day(date);
  for (final p in _periodsOf(r)) {
    final started = !d.isBefore(p.from);
    final notEnded = p.until == null || d.isBefore(p.until!);
    if (started && notEnded) return p;
  }
  return null;
}

/// 해당 날짜에 조정대상지역이었는지.
/// 서울 외 지역의 2023.1.5 이전 날짜는 기록이 없어 null (사용자 확인 필요).
bool? isRegulatedOn(Region r, DateTime date) {
  if (_periodAt(r, date) != null) return true;
  if (r.sido != Sido.seoul && _day(date).isBefore(kRecordStartOutsideSeoul)) return null;
  return false;
}

/// 지금 조정대상지역인지
bool isRegulatedNow(Region r) => isRegulatedOn(r, DateTime.now()) ?? false;

class SaleZoneCheck {
  final bool heavyZone; // 다주택 중과를 적용할 지역·계약인지
  final String? note;
  const SaleZoneCheck(this.heavyZone, {this.note});
}

/// 팔 때 다주택 중과 지역 판단 (지정 전 계약, 5.9 유예 보완조치 반영)
SaleZoneCheck checkSaleZone(Region r, DateTime saleDate, DateTime contractDate) {
  final p = _periodAt(r, saleDate);
  if (p == null) return const SaleZoneCheck(false);

  final c = _day(contractDate);

  // 조정대상지역 지정 공고 전에 계약하고 계약금을 받은 주택은 중과 제외
  if (c.isBefore(p.from)) {
    return SaleZoneCheck(false,
        note: '조정대상지역 지정(${formatDate(p.from)}) 전에 계약하고 계약금을 받은 집이라 다주택 중과에서 제외돼요. 계약금 증빙이 필요해요.');
  }

  // 2026.5.9까지 계약 + 기한 내 양도 시 중과 배제 (강남·서초·송파·용산 4개월, 그 외 6개월)
  if (!c.isAfter(kGraceContractDeadline)) {
    final months = (r.sido == Sido.seoul && _seoulCore.contains(r.sigungu)) ? 4 : 6;
    final limit = DateTime(c.year, c.month + months, c.day);
    if (!_day(saleDate).isAfter(limit)) {
      return SaleZoneCheck(false,
          note: '2026.5.9 이전 계약 + 계약일로부터 $months개월 안에 양도해서 중과 유예 보완조치가 적용돼요.');
    }
  }

  return const SaleZoneCheck(true);
}