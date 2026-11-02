// 보유세(재산세·종합부동산세) 계산 (2026년 11월 기준, 모의계산용)
import 'dart:math' as math;
import 'calculator.dart';

int _t10(num v) => (v ~/ 10) * 10;
const int _big = 1 << 62;

class _Step {
  final int lower; // 구간 시작
  final int upTo; // 구간 끝
  final int base; // 구간 시작까지의 누적 세액
  final double rate;
  const _Step(this.lower, this.upTo, this.base, this.rate);
}

int _stepTax(int amount, List<_Step> table) {
  if (amount <= 0) return 0;
  for (final s in table) {
    if (amount <= s.upTo) return (s.base + (amount - s.lower) * s.rate).floor();
  }
  return 0;
}

// 재산세 표준세율 0.1~0.4%
const List<_Step> _propStd = [
  _Step(0, 60000000, 0, 0.001),
  _Step(60000000, 150000000, 60000, 0.0015),
  _Step(150000000, 300000000, 195000, 0.0025),
  _Step(300000000, _big, 570000, 0.004),
];

// 1세대 1주택 특례세율 (공시가격 9억 이하) 0.05~0.35%
const List<_Step> _propSpecial = [
  _Step(0, 60000000, 0, 0.0005),
  _Step(60000000, 150000000, 30000, 0.001),
  _Step(150000000, 300000000, 120000, 0.002),
  _Step(300000000, _big, 420000, 0.0035),
];

// 종부세 2주택 이하 0.5~2.7%
const List<_Step> _jong2 = [
  _Step(0, 300000000, 0, 0.005),
  _Step(300000000, 600000000, 1500000, 0.007),
  _Step(600000000, 1200000000, 3600000, 0.010),
  _Step(1200000000, 2500000000, 9600000, 0.013),
  _Step(2500000000, 5000000000, 26500000, 0.015),
  _Step(5000000000, 9400000000, 64000000, 0.020),
  _Step(9400000000, _big, 152000000, 0.027),
];

// 종부세 3주택 이상 (과세표준 12억 초과 구간부터 중과) 0.5~5.0%
const List<_Step> _jong3 = [
  _Step(0, 300000000, 0, 0.005),
  _Step(300000000, 600000000, 1500000, 0.007),
  _Step(600000000, 1200000000, 3600000, 0.010),
  _Step(1200000000, 2500000000, 9600000, 0.020),
  _Step(2500000000, 5000000000, 35600000, 0.030),
  _Step(5000000000, 9400000000, 110600000, 0.040),
  _Step(9400000000, _big, 286600000, 0.050),
];

class HoldingInput {
  final int officialPrice; // 이 집 공시가격
  final int houses; // 6월 1일 기준 1세대 주택 수
  final int otherOfficialTotal; // 다른 집 공시가격 합계
  final int age; // 1주택자 나이 (세액공제)
  final int holdYears; // 1주택 보유기간 (세액공제)
  final bool urbanArea; // 도시지역 (도시지역분 부과)

  const HoldingInput({
    required this.officialPrice,
    required this.houses,
    required this.otherOfficialTotal,
    required this.age,
    required this.holdYears,
    required this.urbanArea,
  });
}

TaxResult calcHoldingTax(HoldingInput i) {
  final notes = <String>[];
  final one = i.houses <= 1;
  final p = i.officialPrice;

  // ── 재산세 (이 집 1채)
  final double fmv = one ? (p <= 3 * kEok ? 0.43 : (p <= 6 * kEok ? 0.44 : 0.45)) : 0.60;
  final propBase = (p * fmv).floor();
  final special = one && p <= 9 * kEok;
  final prop = _t10(_stepTax(propBase, special ? _propSpecial : _propStd));
  final urban = i.urbanArea ? _t10(propBase * 0.0014) : 0;
  final edu = _t10(prop * 0.2);
  final propTotal = prop + urban + edu;

  final lines = <TaxLine>[
    TaxLine('공시가격 (이 집)', p),
    TaxLine('재산세 과세표준', propBase, memo: '공정시장가액비율 ${formatPct(fmv)}'),
    TaxLine('재산세', prop, memo: special ? '1주택 특례세율 0.05~0.35%' : '표준세율 0.1~0.4%'),
    if (urban > 0) TaxLine('도시지역분', urban, memo: '과세표준의 0.14%'),
    TaxLine('지방교육세', edu, memo: '재산세의 20%'),
    TaxLine('재산세 합계', propTotal, emphasize: true),
  ];

  // ── 종합부동산세 (전체 주택 합산)
  final total = p + (one ? 0 : i.otherOfficialTotal);
  final deduction = one ? 12 * kEok : 9 * kEok;
  int jongTotal = 0;

  if (total > deduction) {
    final jBase = ((total - deduction) * 0.6).floor();
    final calc = _stepTax(jBase, i.houses >= 3 ? _jong3 : _jong2);

    // 재산세와 겹치는 부분 공제 (근사치)
    var overlap = (jBase * fmv * 0.004).floor();
    if (one) overlap = math.min(overlap, prop);
    final afterOverlap = math.max(0, calc - overlap);

    // 1세대 1주택 고령자·장기보유 세액공제 (합산 최대 80%)
    double creditRate = 0;
    if (one) {
      final ageRate = i.age >= 70 ? 0.4 : (i.age >= 65 ? 0.3 : (i.age >= 60 ? 0.2 : 0.0));
      final holdRate =
      i.holdYears >= 15 ? 0.5 : (i.holdYears >= 10 ? 0.4 : (i.holdYears >= 5 ? 0.2 : 0.0));
      creditRate = math.min(ageRate + holdRate, 0.8);
    }
    final credit = (afterOverlap * creditRate).floor();
    final jong = _t10(afterOverlap - credit);
    final rural = _t10(jong * 0.2);
    jongTotal = jong + rural;

    lines.addAll([
      TaxLine('공시가격 합계', total, memo: i.houses >= 2 ? '보유 주택 전체' : null),
      TaxLine('종부세 기본공제', -deduction, memo: one ? '1세대 1주택 12억' : '일반 9억'),
      TaxLine('종부세 과세표준', jBase, memo: '공정시장가액비율 60%'),
      TaxLine('종부세 산출세액', calc, memo: i.houses >= 3 ? '3주택 이상 세율' : '2주택 이하 세율'),
      TaxLine('재산세 중복분 공제', -overlap, memo: '근사치'),
      if (credit > 0) TaxLine('고령자·장기보유 공제', -credit, memo: formatPct(creditRate)),
      TaxLine('종합부동산세', jong),
      TaxLine('농어촌특별세', rural, memo: '종부세의 20%'),
      TaxLine('종부세 합계', jongTotal, emphasize: true),
    ]);
  } else {
    lines.add(TaxLine('종합부동산세', 0,
        memo: '공시가격 합계가 ${one ? '12억' : '9억'} 이하라 대상이 아니에요'));
  }

  final grand = propTotal + jongTotal;
  lines.add(TaxLine('1년 보유세 합계', grand, emphasize: true));

  if (i.houses >= 2) notes.add('재산세는 이 집 1채만 계산했고, 종부세는 모든 집을 합쳐서 계산했어요.');
  notes.add('매년 6월 1일에 집을 가진 사람이 그해 보유세를 내요. 재산세는 7월·9월, 종부세는 12월에 내요.');
  notes.add('세부담 상한, 임대주택 감면, 부부 공동명의 특례는 반영되지 않았어요.');
  notes.add('2026년 세제개편안에 따라 2027년부터 종부세 1주택 공제가 실거주 기준으로 바뀔 예정이에요.');

  return TaxResult(title: '보유세 (1년)', total: grand, lines: lines, notes: notes);
}