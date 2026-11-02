// 조합원입주권·분양권 양도소득세 (2026년 11월 기준, 모의계산용)
// 근거: 소득세법 제89조 제1항 제4호, 제95조, 제100조, 제104조
import 'dart:math' as math;
import 'calculator.dart';

enum RightType { memberOriginal, memberSuccessor, presale }

extension RightTypeLabel on RightType {
  String get label {
    switch (this) {
      case RightType.memberOriginal:
        return '조합원입주권 (원조합원)';
      case RightType.memberSuccessor:
        return '조합원입주권 (사서 들어감 · 승계)';
      case RightType.presale:
        return '분양권';
    }
  }

  String get help {
    switch (this) {
      case RightType.memberOriginal:
        return '원래 가진 집이 재개발·재건축되면서 받은 입주권';
      case RightType.memberSuccessor:
        return '다른 조합원에게 입주권을 산 경우';
      case RightType.presale:
        return '청약 당첨 또는 전매로 산 분양권';
    }
  }
}

class RightTransferInput {
  final RightType type;
  final int salePrice; // 양도가액
  final int buyPrice; // 원조합원: 종전 주택 취득가 / 그 외: 입주권·분양권 매입가(프리미엄 포함)
  final int expenses; // 필요경비
  final int rightValue; // 권리가액 (원조합원, 관리처분 때 평가된 종전 주택 가치)
  final int paidSettlement; // 낸 추가분담금(청산금)
  final DateTime buyDate; // 원조합원: 종전 주택 취득일 / 그 외: 권리 취득일
  final DateTime saleDate;
  final DateTime? approvalDate; // 관리처분계획인가일 (원조합원)
  final int liveMonths; // 종전 주택 거주기간 (원조합원)
  final int houses; // 양도 시점 1세대 주택 수 (입주권·분양권 포함)
  final bool regulatedAtBuy; // 종전 주택 취득 당시 조정대상지역

  const RightTransferInput({
    required this.type,
    required this.salePrice,
    required this.buyPrice,
    required this.expenses,
    required this.rightValue,
    required this.paidSettlement,
    required this.buyDate,
    required this.saleDate,
    required this.approvalDate,
    required this.liveMonths,
    required this.houses,
    required this.regulatedAtBuy,
  });
}

const int _big = 1 << 62;

class _Br {
  final int upTo;
  final double rate;
  final int ded;
  const _Br(this.upTo, this.rate, this.ded);
}

const List<_Br> _basic = [
  _Br(14000000, 0.06, 0),
  _Br(50000000, 0.15, 1260000),
  _Br(88000000, 0.24, 5760000),
  _Br(150000000, 0.35, 15440000),
  _Br(300000000, 0.38, 19940000),
  _Br(500000000, 0.40, 25940000),
  _Br(1000000000, 0.42, 35940000),
  _Br(_big, 0.45, 65940000),
];

int _basicTax(int base) {
  if (base <= 0) return 0;
  for (final b in _basic) {
    if (base <= b.upTo) return (base * b.rate - b.ded).floor();
  }
  return 0;
}

int _t10(num v) => (v ~/ 10) * 10;

TaxResult calcRightTransferTax(RightTransferInput i) {
  final notes = <String>[];
  final title = '양도소득세 · ${i.type.label}';
  final gain = i.salePrice - i.buyPrice - i.expenses - i.paidSettlement;
  final holdMonths = monthsBetween(i.buyDate, i.saleDate);

  final lines = <TaxLine>[
    TaxLine('양도가액', i.salePrice),
    TaxLine(i.type == RightType.memberOriginal ? '종전 주택 취득가' : '매입가 (프리미엄 포함)', -i.buyPrice),
    if (i.expenses > 0) TaxLine('필요경비', -i.expenses),
    if (i.paidSettlement > 0) TaxLine('낸 추가분담금', -i.paidSettlement),
    TaxLine('양도차익', gain),
  ];

  if (gain <= 0) {
    return TaxResult(
      title: title,
      total: 0,
      lines: [...lines, const TaxLine('납부할 세금 합계', 0, emphasize: true)],
      notes: ['양도차익이 없어서 양도세가 발생하지 않아요.'],
    );
  }

  // ───────── 분양권: 1년 미만 70%, 그 외 60% (비과세·장기보유공제 없음)
  if (i.type == RightType.presale) {
    final base = math.max(0, gain - kTransferBasicDeduction);
    final rate = holdMonths < 12 ? 0.7 : 0.6;
    final tax = _t10(base * rate);
    final local = _t10(tax * 0.1);
    lines.addAll([
      const TaxLine('기본공제', -kTransferBasicDeduction),
      TaxLine('과세표준', base),
      TaxLine('양도소득세', tax, memo: '분양권 ${holdMonths < 12 ? '1년 미만' : '1년 이상'} ${formatPct(rate)}'),
      TaxLine('지방소득세', local, memo: '양도세의 10%'),
      TaxLine('납부할 세금 합계', tax + local, emphasize: true),
    ]);
    notes.addAll([
      '분양권은 오래 보유해도 최소 60% 세율이 적용되고, 비과세·장기보유특별공제가 없어요.',
      '2021년 이후 취득한 분양권은 다른 집을 팔 때 주택 수에 포함돼요.',
    ]);
    return TaxResult(title: title, total: tax + local, lines: lines, notes: notes);
  }

  // ───────── 승계조합원: 장기보유공제 없음, 비과세 없음
  if (i.type == RightType.memberSuccessor) {
    final base = math.max(0, gain - kTransferBasicDeduction);
    final normal = _basicTax(base);
    double? shortRate;
    if (holdMonths < 12) {
      shortRate = 0.7;
    } else if (holdMonths < 24) {
      shortRate = 0.6;
    }
    final shortTax = shortRate == null ? 0 : (base * shortRate).floor();
    final tax = _t10(math.max(normal, shortTax));
    final local = _t10(tax * 0.1);
    lines.addAll([
      const TaxLine('장기보유특별공제', 0, memo: '승계 입주권은 공제 없음'),
      const TaxLine('기본공제', -kTransferBasicDeduction),
      TaxLine('과세표준', base),
      TaxLine('양도소득세', tax,
          memo: shortTax > normal ? '단기 양도 ${formatPct(shortRate!)}' : '기본세율 6~45%'),
      TaxLine('지방소득세', local, memo: '양도세의 10%'),
      TaxLine('납부할 세금 합계', tax + local, emphasize: true),
    ]);
    notes.addAll([
      '사서 들어간 입주권은 아직 집이 아니라 권리라서, 장기보유특별공제와 1주택 비과세를 받을 수 없어요.',
      '보유기간은 입주권을 산 날부터 계산해요.',
    ]);
    return TaxResult(title: title, total: tax + local, lines: lines, notes: notes);
  }

  // ───────── 원조합원
  final approval = i.approvalDate ?? i.saleDate;
  final holdBefore = monthsBetween(i.buyDate, approval); // 종전 주택 보유기간 (인가일까지)

  // 관리처분 전 차익 = 권리가액 − 취득가 − 필요경비 / 후 차익 = 나머지
  int beforeGain = i.rightValue > 0 ? i.rightValue - i.buyPrice - i.expenses : 0;
  beforeGain = beforeGain.clamp(0, gain).toInt();
  final afterGain = gain - beforeGain;
  if (i.rightValue <= 0) {
    notes.add('권리가액을 넣지 않아서 장기보유특별공제를 계산하지 않았어요. 관리처분계획서에서 확인할 수 있어요.');
  }

  // 1세대 1주택 비과세 (소득세법 제89조 제1항 제4호)
  final exempt = i.houses == 1 &&
      holdBefore >= 24 &&
      (!i.regulatedAtBuy || i.liveMonths >= 24);

  if (i.houses == 1 && !exempt) {
    notes.add('관리처분계획인가일까지 종전 주택 2년 보유(조정지역 취득이면 2년 거주)를 못 채워 비과세가 안 돼요.');
  }

  lines.addAll([
    TaxLine('관리처분 전 차익', beforeGain, memo: '권리가액 − 취득가'),
    TaxLine('관리처분 후 차익', afterGain, memo: '프리미엄 등'),
  ]);

  double ratio = 1;
  if (exempt) {
    if (i.salePrice <= kHighPriceLine) {
      return TaxResult(
        title: title,
        total: 0,
        lines: [...lines, const TaxLine('납부할 세금 합계', 0, emphasize: true)],
        notes: ['1세대 1주택 비과세 대상이에요 (양도가 12억 이하). 양도일에 다른 집이 없어야 해요.', ...notes],
      );
    }
    ratio = (i.salePrice - kHighPriceLine) / i.salePrice;
    notes.add('양도가가 12억을 넘어서, 차익 중 ${formatPct(ratio)}만 과세했어요.');
  }

  final taxBefore = (beforeGain * ratio).floor();
  final taxAfter = (afterGain * ratio).floor();

  // 장기보유특별공제: 관리처분 전 차익에만, 인가일까지 보유기간으로
  final holdY = holdBefore ~/ 12;
  final liveY = i.liveMonths ~/ 12;
  double lt = 0;
  String ltMemo;
  if (holdY < 3) {
    ltMemo = '인가일까지 보유 3년 미만';
  } else if (exempt && liveY >= 2) {
    lt = math.min(holdY * 0.04, 0.4) + math.min(liveY * 0.04, 0.4);
    ltMemo = '1주택 보유 $holdY년·거주 $liveY년 → ${formatPct(lt)} (관리처분 전 차익에만)';
  } else {
    lt = math.min(holdY * 0.02, 0.30);
    ltMemo = '보유 $holdY년 → ${formatPct(lt)} (관리처분 전 차익에만)';
  }
  final ltcd = (taxBefore * lt).floor();
  lines.add(TaxLine('장기보유특별공제', -ltcd, memo: ltMemo));

  final base = math.max(0, taxBefore - ltcd + taxAfter - kTransferBasicDeduction);
  lines.add(const TaxLine('기본공제', -kTransferBasicDeduction));
  lines.add(TaxLine('과세표준', base));

  final normal = _basicTax(base);
  double? shortRate;
  if (holdMonths < 12) {
    shortRate = 0.7;
  } else if (holdMonths < 24) {
    shortRate = 0.6;
  }
  final shortTax = shortRate == null ? 0 : (base * shortRate).floor();
  final tax = _t10(math.max(normal, shortTax));
  final local = _t10(tax * 0.1);

  lines.addAll([
    TaxLine('양도소득세', tax,
        memo: shortTax > normal ? '단기 양도 ${formatPct(shortRate!)}' : '기본세율 6~45% (입주권은 다주택 중과 없음)'),
    TaxLine('지방소득세', local, memo: '양도세의 10%'),
    TaxLine('납부할 세금 합계', tax + local, emphasize: true),
  ]);

  notes.add('원조합원 보유기간은 종전 주택을 산 날부터 계산하고, 장기보유특별공제는 관리처분계획인가일까지만 인정돼요.');
  notes.add('청산금을 돌려받은 경우, 대체주택 비과세 특례는 반영되지 않았어요.');

  return TaxResult(title: title, total: tax + local, lines: lines, notes: notes);
}
