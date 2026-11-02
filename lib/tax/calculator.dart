// 내집마련 A to Z — 부동산 세금 계산 로직 (2026년 11월 기준, 모의계산용)
// 모든 금액 단위: 원(int)

import 'dart:math' as math;

// ───────────────────── 공통 상수 ─────────────────────
const int kMan = 10000;
const int kEok = 100000000;
const int _inf = 1 << 62;

/// 조정대상지역 다주택 양도세 중과 (2026.5.10 양도분부터 다시 적용 중)
const bool kHeavyTransferTaxActive = true;

/// 생애최초 취득세 감면 한도
const int kFirstHomeReliefCap = 2000000;

/// 1세대1주택 고가주택 기준
const int kHighPriceLine = 12 * kEok;

/// 양도소득 기본공제
const int kTransferBasicDeduction = 2500000;

// ───────────────────── 결과 모델 ─────────────────────
class TaxLine {
  final String label;
  final int amount;
  final String? memo;
  final bool emphasize;
  const TaxLine(this.label, this.amount, {this.memo, this.emphasize = false});
}

class TaxResult {
  final String title;
  final int total;
  final List<TaxLine> lines;
  final List<String> notes;
  const TaxResult({
    required this.title,
    required this.total,
    required this.lines,
    this.notes = const [],
  });
}

// ───────────────────── 유틸 ─────────────────────
String formatWon(int won) {
  final s = won.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${won < 0 ? '-' : ''}$buf원';
}

String formatKorean(int won) {
  final eok = won ~/ kEok;
  final man = (won % kEok) ~/ kMan;
  final parts = <String>[];
  if (eok > 0) parts.add('$eok억');
  if (man > 0) parts.add('${formatWon(man).replaceAll('원', '')}만');
  if (parts.isEmpty) return formatWon(won);
  return '${parts.join(' ')}원';
}

String formatPct(double r) {
  final s = (r * 100).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  return '$s%';
}

int monthsBetween(DateTime from, DateTime to) {
  var m = (to.year - from.year) * 12 + (to.month - from.month);
  if (to.day < from.day) m -= 1;
  return math.max(0, m);
}

int _truncTen(num v) => (v ~/ 10) * 10; // 10원 미만 절사

class _Bracket {
  final int upTo;
  final double rate;
  final int deduction; // 누진공제
  const _Bracket(this.upTo, this.rate, this.deduction);
}

// 양도소득세 기본세율 (6~45%)
const List<_Bracket> _incomeBrackets = [
  _Bracket(14000000, 0.06, 0),
  _Bracket(50000000, 0.15, 1260000),
  _Bracket(88000000, 0.24, 5760000),
  _Bracket(150000000, 0.35, 15440000),
  _Bracket(300000000, 0.38, 19940000),
  _Bracket(500000000, 0.40, 25940000),
  _Bracket(1000000000, 0.42, 35940000),
  _Bracket(_inf, 0.45, 65940000),
];

// 증여세율 (10~50%)
const List<_Bracket> _giftBrackets = [
  _Bracket(100000000, 0.10, 0),
  _Bracket(500000000, 0.20, 10000000),
  _Bracket(1000000000, 0.30, 60000000),
  _Bracket(3000000000, 0.40, 160000000),
  _Bracket(_inf, 0.50, 460000000),
];

int _progressive(int base, List<_Bracket> table, {double extraRate = 0}) {
  if (base <= 0) return 0;
  for (final b in table) {
    if (base <= b.upTo) {
      return (base * (b.rate + extraRate) - b.deduction).floor();
    }
  }
  return 0;
}

// ═════════════════════ 1. 취득세 (살 때) ═════════════════════
class AcquisitionInput {
  final int price; // 취득가액
  final int housesAfter; // 취득 후 1세대 주택 수 (이번 집 포함)
  final bool regulated; // 취득 주택이 조정대상지역
  final bool over85; // 전용 85㎡ 초과
  final bool temporaryTwo; // 일시적 2주택 (종전 주택 기한 내 처분 예정)
  final bool firstHome; // 생애최초 구입

  const AcquisitionInput({
    required this.price,
    required this.housesAfter,
    required this.regulated,
    required this.over85,
    required this.temporaryTwo,
    required this.firstHome,
  });
}

/// 주택 유상취득 표준세율: 6억 이하 1%, 6~9억 구간 산식, 9억 초과 3%
double _standardHousingRate(int price) {
  if (price <= 6 * kEok) return 0.01;
  if (price <= 9 * kEok) {
    final r = (price * 2 / (3 * kEok) - 3) / 100;
    return (r * 10000).round() / 10000; // 소수점 넷째 자리까지
  }
  return 0.03;
}

TaxResult calcAcquisitionTax(AcquisitionInput i) {
  final notes = <String>[];
  final baseRate = _standardHousingRate(i.price);
  double rate;
  bool heavy = false;

  if (i.housesAfter <= 1) {
    rate = baseRate;
  } else if (i.regulated) {
    if (i.housesAfter == 2) {
      if (i.temporaryTwo) {
        rate = baseRate;
        notes.add('일시적 2주택은 종전 주택을 기한 내 처분하지 않으면 8% 중과로 추징될 수 있어요.');
      } else {
        rate = 0.08;
        heavy = true;
      }
    } else {
      rate = 0.12;
      heavy = true;
    }
  } else {
    if (i.housesAfter == 2) {
      rate = baseRate;
    } else if (i.housesAfter == 3) {
      rate = 0.08;
      heavy = true;
    } else {
      rate = 0.12;
      heavy = true;
    }
  }

  final acq = _truncTen(i.price * rate);

  int relief = 0;
  if (i.firstHome) {
    if (i.housesAfter == 1 && i.price <= kHighPriceLine) {
      relief = math.min(acq, kFirstHomeReliefCap);
      notes.add('생애최초 감면은 취득 후 3개월 내 전입·3년 실거주 등 사후 요건을 지키지 않으면 추징돼요.');
    } else {
      notes.add('생애최초 감면은 취득가 12억 이하 + 취득 후 1주택일 때만 적용돼요.');
    }
  }

  // 지방교육세: 일반세율이면 취득세율의 10%, 중과면 0.4%
  final eduRate = heavy ? 0.004 : rate * 0.1;
  // 농어촌특별세: 전용 85㎡ 초과만 (일반 0.2%, 8% 중과 0.6%, 12% 중과 1.0%)
  final ruralRate = !i.over85
      ? 0.0
      : (rate >= 0.12 ? 0.01 : (rate >= 0.08 ? 0.006 : 0.002));

  // 생애최초 감면 시 지방교육세도 같은 비율로 감면
  final eduFull = _truncTen(i.price * eduRate);
  final edu = (relief > 0 && acq > 0)
      ? _truncTen(eduFull * (acq - relief) / acq)
      : eduFull;
  final rural = _truncTen(i.price * ruralRate);
  final total = acq - relief + edu + rural;

  if (heavy) notes.add('다주택 중과세율이 적용됐어요.');
  notes.add('공시가 1억 이하 주택, 지방 미분양 등 주택 수 제외 특례는 반영되지 않았어요.');

  return TaxResult(
    title: '취득세 (살 때)',
    total: total,
    lines: [
      TaxLine('취득가액', i.price),
      TaxLine('취득세', acq, memo: '세율 ${formatPct(rate)}'),
      if (relief > 0) TaxLine('생애최초 감면', -relief, memo: '최대 200만원'),
      TaxLine('지방교육세', edu,
          memo: relief > 0 ? '${formatPct(eduRate)} · 생애최초 감면 비율만큼 줄어듦' : formatPct(eduRate)),
      if (rural > 0) TaxLine('농어촌특별세', rural, memo: formatPct(ruralRate)),
      TaxLine('납부할 세금 합계', total, emphasize: true),
    ],
    notes: notes,
  );
}

// ═════════════════════ 2. 양도소득세 (팔 때) ═════════════════════
class TransferInput {
  final int salePrice; // 양도가액
  final int buyPrice; // 취득가액
  final int expenses; // 필요경비 (취득세, 중개수수료, 확장공사비 등)
  final int holdMonths; // 보유기간 (개월)
  final int liveMonths; // 거주기간 (개월)
  final int houses; // 양도 시점 1세대 주택 수 (파는 집 포함)
  final bool regulatedNow; // 파는 집이 현재 조정대상지역
  final bool regulatedAtBuy; // 살 때 조정대상지역이었음 (비과세 거주요건)
  final bool temporaryTwo; // 일시적 2주택 비과세 특례 요건 충족

  const TransferInput({
    required this.salePrice,
    required this.buyPrice,
    required this.expenses,
    required this.holdMonths,
    required this.liveMonths,
    required this.houses,
    required this.regulatedNow,
    required this.regulatedAtBuy,
    required this.temporaryTwo,
  });
}

TaxResult calcTransferTax(TransferInput i) {
  final notes = <String>[];
  final gain = i.salePrice - i.buyPrice - i.expenses;

  if (gain <= 0) {
    return TaxResult(
      title: '양도소득세 (팔 때)',
      total: 0,
      lines: [
        TaxLine('양도차익', gain),
        const TaxLine('납부할 세금 합계', 0, emphasize: true),
      ],
      notes: ['양도차익이 없어서 양도세가 발생하지 않아요.'],
    );
  }

  // ── 1세대1주택 비과세 판단
  final isOneHouse = i.houses == 1 || (i.houses == 2 && i.temporaryTwo);
  final meetsHold = i.holdMonths >= 24;
  final meetsLive = !i.regulatedAtBuy || i.liveMonths >= 24;
  final exempt = isOneHouse && meetsHold && meetsLive;

  if (isOneHouse && !meetsHold) notes.add('보유 2년 미만이라 1주택 비과세가 적용되지 않았어요.');
  if (isOneHouse && meetsHold && !meetsLive) {
    notes.add('취득 당시 조정대상지역이라 2년 거주 요건이 필요해요. 비과세가 적용되지 않았어요.');
  }

  final lines = <TaxLine>[
    TaxLine('양도가액', i.salePrice),
    TaxLine('취득가액', -i.buyPrice),
    if (i.expenses > 0) TaxLine('필요경비', -i.expenses),
    TaxLine('양도차익', gain),
  ];

  int taxableGain = gain;
  if (exempt) {
    if (i.salePrice <= kHighPriceLine) {
      return TaxResult(
        title: '양도소득세 (팔 때)',
        total: 0,
        lines: [...lines, const TaxLine('납부할 세금 합계', 0, emphasize: true)],
        notes: ['1세대1주택 비과세 대상이에요 (양도가 12억 이하).', ...notes],
      );
    }
    taxableGain = (gain * (i.salePrice - kHighPriceLine) / i.salePrice).floor();
    lines.add(TaxLine('과세 대상 양도차익', taxableGain, memo: '12억 초과분 비율만 과세'));
  }

  // ── 중과 여부
  final heavyExempt = i.houses == 2 && i.temporaryTwo;
  final heavyExtra = (!exempt &&
      kHeavyTransferTaxActive &&
      i.regulatedNow &&
      i.houses >= 2 &&
      !heavyExempt)
      ? (i.houses == 2 ? 0.2 : 0.3)
      : 0.0;

  // ── 장기보유특별공제
  final holdY = i.holdMonths ~/ 12;
  final liveY = i.liveMonths ~/ 12;
  double ltRate = 0;
  String ltMemo = '';
  if (heavyExtra > 0) {
    ltMemo = '중과 대상이라 공제 배제';
  } else if (holdY < 3) {
    ltMemo = '보유 3년 미만';
  } else if (exempt && liveY >= 2) {
    ltRate = math.min(holdY * 0.04, 0.4) + math.min(liveY * 0.04, 0.4);
    ltMemo = '1주택 보유 $holdY년·거주 $liveY년 → ${formatPct(ltRate)}';
  } else {
    ltRate = math.min(holdY * 0.02, 0.30);
    ltMemo = '보유 $holdY년 → ${formatPct(ltRate)}';
  }
  final ltcd = (taxableGain * ltRate).floor();
  lines.add(TaxLine('장기보유특별공제', -ltcd, memo: ltMemo));

  final income = taxableGain - ltcd;
  final base = math.max(0, income - kTransferBasicDeduction);
  lines.add(const TaxLine('기본공제', -kTransferBasicDeduction));
  lines.add(TaxLine('과세표준', base));

  // ── 세율: 기본(+중과) vs 단기세율 중 큰 것
  final normalTax = _progressive(base, _incomeBrackets, extraRate: heavyExtra);
  double? shortRate;
  if (i.holdMonths < 12) {
    shortRate = 0.7;
  } else if (i.holdMonths < 24) {
    shortRate = 0.6;
  }
  final shortTax = shortRate == null ? 0 : (base * shortRate).floor();

  final useShort = shortTax > normalTax;
  final tax = _truncTen(math.max(normalTax, shortTax));
  final local = _truncTen(tax * 0.1);

  String rateMemo;
  if (useShort) {
    rateMemo = '단기 양도 ${formatPct(shortRate!)}';
  } else if (heavyExtra > 0) {
    rateMemo = '기본세율 + ${formatPct(heavyExtra)}p 중과';
  } else {
    rateMemo = '기본세율 6~45%';
  }

  lines.add(TaxLine('양도소득세', tax, memo: rateMemo));
  lines.add(TaxLine('지방소득세', local, memo: '양도세의 10%'));
  lines.add(TaxLine('납부할 세금 합계', tax + local, emphasize: true));

  if (heavyExtra > 0) {
    notes.add('조정대상지역 다주택 중과가 적용됐어요 (2026.5.10 양도분부터).');
  }
  notes.add('양도일은 잔금일 기준이에요. 거주주택 비과세, 상생임대 등 특례는 반영되지 않았어요.');

  return TaxResult(
    title: '양도소득세 (팔 때)',
    total: tax + local,
    lines: lines,
    notes: notes,
  );
}

// ═════════════════════ 3. 증여세 (+ 증여 취득세) ═════════════════════
enum GiftRelation { spouse, ascendantToChild, childToParent, otherRelative, others }

extension GiftRelationLabel on GiftRelation {
  String get label {
    switch (this) {
      case GiftRelation.spouse:
        return '배우자';
      case GiftRelation.ascendantToChild:
        return '부모·조부모 → 자녀·손주';
      case GiftRelation.childToParent:
        return '자녀 → 부모';
      case GiftRelation.otherRelative:
        return '기타 친족 (형제 등)';
      case GiftRelation.others:
        return '타인';
    }
  }
}

class GiftInput {
  final int value; // 증여재산가액 (시가)
  final GiftRelation relation;
  final bool recipientMinor; // 받는 사람이 미성년
  final bool marriageBirth; // 혼인·출산 증여공제 (직계존속 → 성년, 최대 1억)
  final bool generationSkip; // 조부모 → 손주 (세대생략 할증)
  final int priorGifts; // 10년 내 같은 사람에게 받은 증여액
  final int priorGiftTax; // 그때 낸 증여세

  // 주택 증여 시 받는 사람이 내는 취득세
  final bool isHousing;
  final bool regulated; // 조정대상지역
  final bool officialOver3; // 공시가격 3억 이상
  final bool giverMultiHome; // 증여자 1세대 2주택 이상
  final bool over85; // 전용 85㎡ 초과

  const GiftInput({
    required this.value,
    required this.relation,
    required this.recipientMinor,
    required this.marriageBirth,
    required this.generationSkip,
    required this.priorGifts,
    required this.priorGiftTax,
    required this.isHousing,
    required this.regulated,
    required this.officialOver3,
    required this.giverMultiHome,
    required this.over85,
  });
}

int _giftDeduction(GiftInput i) {
  switch (i.relation) {
    case GiftRelation.spouse:
      return 6 * kEok;
    case GiftRelation.ascendantToChild:
      final basic = i.recipientMinor ? 20000000 : 50000000;
      final extra = (i.marriageBirth && !i.recipientMinor) ? kEok : 0;
      return basic + extra;
    case GiftRelation.childToParent:
      return 50000000;
    case GiftRelation.otherRelative:
      return 10000000;
    case GiftRelation.others:
      return 0;
  }
}

TaxResult calcGiftTax(GiftInput i) {
  final notes = <String>[];
  final lines = <TaxLine>[TaxLine('증여재산가액', i.value)];

  final totalGift = i.value + i.priorGifts;
  if (i.priorGifts > 0) {
    lines.add(TaxLine('10년 내 증여 합산', i.priorGifts));
  }
  final deduction = math.min(_giftDeduction(i), totalGift);
  lines.add(TaxLine('증여재산공제', -deduction, memo: i.relation.label));

  var base = totalGift - deduction;
  if (base < 500000) base = 0; // 과세표준 50만원 미만 과세 안 함
  lines.add(TaxLine('과세표준', base));

  var calc = _progressive(base, _giftBrackets);
  if (i.generationSkip && calc > 0) {
    final s = (i.recipientMinor && totalGift > 20 * kEok) ? 0.4 : 0.3;
    final add = (calc * s).floor();
    lines.add(TaxLine('세대생략 할증', add, memo: formatPct(s)));
    calc += add;
  }
  lines.add(TaxLine('산출세액', calc));

  final afterPrior = math.max(0, calc - i.priorGiftTax);
  if (i.priorGiftTax > 0) lines.add(TaxLine('기납부세액 공제', -i.priorGiftTax));

  final credit = (afterPrior * 0.03).floor();
  if (credit > 0) lines.add(TaxLine('신고세액공제', -credit, memo: '기한 내 신고 시 3%'));

  final giftTax = _truncTen(afterPrior - credit);
  lines.add(TaxLine('증여세', giftTax, emphasize: true));

  int acqTotal = 0;
  if (i.isHousing) {
    final heavy = i.regulated && i.officialOver3 && i.giverMultiHome;
    final rate = heavy ? 0.12 : 0.035;
    final eduRate = heavy ? 0.004 : 0.003;
    final ruralRate = !i.over85 ? 0.0 : (heavy ? 0.01 : 0.002);
    final acq = _truncTen(i.value * rate);
    final edu = _truncTen(i.value * eduRate);
    final rural = _truncTen(i.value * ruralRate);
    acqTotal = acq + edu + rural;
    lines.add(TaxLine('증여 취득세', acq, memo: '세율 ${formatPct(rate)}'));
    lines.add(TaxLine('지방교육세', edu));
    if (rural > 0) lines.add(TaxLine('농어촌특별세', rural));
    if (heavy) notes.add('조정지역·공시가 3억 이상·증여자 다주택이라 증여 취득세 12% 중과가 적용됐어요.');
  }

  final total = giftTax + acqTotal;
  lines.add(TaxLine('받는 사람이 낼 세금 합계', total, emphasize: true));

  notes.add('증여재산공제는 10년간 같은 그룹(배우자/직계존속 등) 합산 한도예요.');
  notes.add('부담부증여(대출·전세금 승계)는 반영되지 않았어요.');

  return TaxResult(title: '증여세', total: total, lines: lines, notes: notes);
}