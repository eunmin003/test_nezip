// 주택담보대출 한도(LTV·DSR) + 이자 계산 (2026년 11월 기준, 수도권 시범 지역)
import 'dart:math' as math;
import 'calculator.dart' show kEok;

/// 은행권 DSR 한도
const double kDsrLimitBank = 0.40;

/// 수도권·규제지역 주담대 스트레스 금리 하한 (변동금리)
const double kStressRateCapital = 0.03;

/// 수도권·규제지역 주담대 최대 만기
const int kMaxYearsCapital = 30;

enum HouseStatus { firstTime, noHouse, oneSellPlan, oneKeep, multi }

extension HouseStatusLabel on HouseStatus {
  String get label {
    switch (this) {
      case HouseStatus.firstTime:
        return '생애최초 구입';
      case HouseStatus.noHouse:
        return '무주택 (생애최초 아님)';
      case HouseStatus.oneSellPlan:
        return '1주택 · 기존 집 처분 조건';
      case HouseStatus.oneKeep:
        return '1주택 · 기존 집 유지';
      case HouseStatus.multi:
        return '2주택 이상';
    }
  }
}

enum RepayType { equalPayment, equalPrincipal, bullet }

extension RepayTypeLabel on RepayType {
  String get label {
    switch (this) {
      case RepayType.equalPayment:
        return '원리금균등 (매달 같은 금액)';
      case RepayType.equalPrincipal:
        return '원금균등 (처음에 많이, 점점 줄어듦)';
      case RepayType.bullet:
        return '만기일시 (이자만 내다 마지막에 원금)';
    }
  }
}

class LoanInput {
  final int price; // 집 시가
  final bool regulated; // 조정대상지역(규제지역)
  final HouseStatus status;
  final int annualIncome; // 연소득
  final int existingAnnualRepay; // 기존 대출 1년 원리금
  final double rate; // 실제 연 금리 (0.04 = 4%)
  final int years; // 만기
  final bool variableRate; // 변동금리면 스트레스 금리 가산
  final RepayType repay;
  final int? desired; // 희망 대출액 (없으면 최대 한도)

  const LoanInput({
    required this.price,
    required this.regulated,
    required this.status,
    required this.annualIncome,
    required this.existingAnnualRepay,
    required this.rate,
    required this.years,
    required this.variableRate,
    required this.repay,
    this.desired,
  });
}

class LoanScenario {
  final String label;
  final int principal;
  final int firstMonthly; // 첫 달 상환액
  final int totalInterest; // 총 이자
  const LoanScenario(this.label, this.principal, this.firstMonthly, this.totalInterest);
}

class LoanResult {
  final double ltvRatio;
  final int ltvAmount;
  final int cap;
  final int ltvLimit;
  final double stressRate;
  final double dsrRate;
  final int allowedAnnual;
  final int dsrLimit;
  final int finalLimit;
  final int loan;
  final double dsrPercent; // 선택 대출 기준 예상 DSR
  final String limitedBy;
  final int years;
  final List<LoanScenario> scenarios;
  final List<String> notes;

  const LoanResult({
    required this.ltvRatio,
    required this.ltvAmount,
    required this.cap,
    required this.ltvLimit,
    required this.stressRate,
    required this.dsrRate,
    required this.allowedAnnual,
    required this.dsrLimit,
    required this.finalLimit,
    required this.loan,
    required this.dsrPercent,
    required this.limitedBy,
    required this.years,
    required this.scenarios,
    required this.notes,
  });
}

double ltvRatioFor(HouseStatus s, bool regulated) {
  switch (s) {
    case HouseStatus.firstTime:
      return 0.70; // 수도권·규제지역 생애최초
    case HouseStatus.noHouse:
    case HouseStatus.oneSellPlan:
      return regulated ? 0.40 : 0.70;
    case HouseStatus.oneKeep:
    case HouseStatus.multi:
      return 0.0; // 수도권·규제지역 추가 구입 주담대 불가
  }
}

/// 수도권·규제지역 주택구입 주담대 금액 상한
int capitalCapFor(int price) {
  if (price <= 15 * kEok) return 6 * kEok;
  if (price <= 25 * kEok) return 4 * kEok;
  return 2 * kEok;
}

int _floor10man(num v) => (v ~/ 100000) * 100000; // 10만원 단위 내림

/// 1원 빌렸을 때 1년에 갚는 원리금 (DSR 계산용)
double _annualRepayFactor(double rate, int years, RepayType t) {
  final n = years * 12;
  final r = rate / 12;
  switch (t) {
    case RepayType.equalPayment:
      if (r == 0) return 1 / years;
      final p = math.pow(1 + r, n).toDouble();
      return r * p / (p - 1) * 12;
    case RepayType.equalPrincipal:
      return 1 / years + rate * (n + 1) / (2 * n); // 평균 연 원리금
    case RepayType.bullet:
      return 1 / math.min(years, 10) + rate; // 일시상환 원금은 최대 10년 분할로 봄
  }
}

LoanScenario loanScenario(String label, int principal, double rate, int years, RepayType t) {
  final n = years * 12;
  final r = rate / 12;
  switch (t) {
    case RepayType.equalPayment:
      final monthly = principal * _annualRepayFactor(rate, years, t) / 12;
      return LoanScenario(label, principal, monthly.round(), (monthly * n - principal).round());
    case RepayType.equalPrincipal:
      final first = principal / n + principal * r;
      return LoanScenario(label, principal, first.round(), (principal * r * (n + 1) / 2).round());
    case RepayType.bullet:
      final monthly = principal * r;
      return LoanScenario(label, principal, monthly.round(), (monthly * n).round());
  }
}

LoanResult calcLoan(LoanInput i) {
  final notes = <String>[];

  final years = math.min(i.years, kMaxYearsCapital);
  if (i.years > kMaxYearsCapital) {
    notes.add('수도권·규제지역 주담대 만기는 최대 30년이라 30년으로 계산했어요.');
  }

  // ── LTV
  final ltvRatio = ltvRatioFor(i.status, i.regulated);
  final ltvAmount = _floor10man(i.price * ltvRatio);
  final cap = capitalCapFor(i.price);
  final ltvLimit = math.min(ltvAmount, cap);

  // ── DSR (스트레스 금리 반영)
  final stress = i.variableRate ? kStressRateCapital : 0.0;
  final dsrRate = i.rate + stress;
  final allowedAnnual = (i.annualIncome * kDsrLimitBank - i.existingAnnualRepay).floor();
  final dsrLimit = allowedAnnual <= 0
      ? 0
      : _floor10man(allowedAnnual / _annualRepayFactor(dsrRate, years, i.repay));

  final finalLimit = math.min(ltvLimit, dsrLimit);
  final limitedBy = ltvRatio == 0
      ? '대출 불가'
      : (dsrLimit < ltvLimit ? 'DSR' : (ltvAmount > cap ? '수도권 금액 상한' : 'LTV'));

  var loan = finalLimit;
  if (i.desired != null && i.desired! > 0) {
    loan = math.min(i.desired!, finalLimit);
    if (i.desired! > finalLimit) notes.add('희망 금액이 한도를 넘어서 최대 한도로 계산했어요.');
  }

  final dsrPercent = i.annualIncome <= 0
      ? 0.0
      : (i.existingAnnualRepay + loan * _annualRepayFactor(dsrRate, years, i.repay)) /
      i.annualIncome;

  final scenarios = [
    loanScenario('LTV 기준 한도로 빌리면', ltvLimit, i.rate, years, i.repay),
    loanScenario('DSR 기준 한도로 빌리면', dsrLimit, i.rate, years, i.repay),
    loanScenario('실제 받을 수 있는 금액', loan, i.rate, years, i.repay),
  ];

  // ── 안내
  switch (i.status) {
    case HouseStatus.oneKeep:
    case HouseStatus.multi:
      notes.add('수도권·규제지역에서 기존 집을 유지하는 1주택자와 다주택자는 주택 구입 목적 주담대를 받을 수 없어요.');
      break;
    case HouseStatus.firstTime:
      notes.add('생애최초 LTV 우대는 소득·주택가격 요건이 있고, 6개월 안에 전입해야 해요.');
      break;
    case HouseStatus.oneSellPlan:
      notes.add('처분 조건부 1주택은 기존 집을 약정 기한(보통 6개월) 안에 팔아야 해요.');
      break;
    case HouseStatus.noHouse:
      break;
  }
  if (stress > 0) {
    notes.add('DSR은 실제 금리 + 스트레스 금리 ${(stress * 100).toStringAsFixed(1)}%p로 계산했고, 이자는 실제 금리로 계산했어요.');
  } else {
    notes.add('고정금리라 스트레스 금리를 더하지 않았어요. 혼합형·주기형은 일부만 더해져서 은행 결과와 다를 수 있어요.');
  }
  notes.add('DSR 40%는 은행 기준이에요. 은행마다 자체 한도가 더 낮을 수 있어요.');

  return LoanResult(
    ltvRatio: ltvRatio,
    ltvAmount: ltvAmount,
    cap: cap,
    ltvLimit: ltvLimit,
    stressRate: stress,
    dsrRate: dsrRate,
    allowedAnnual: math.max(0, allowedAnnual),
    dsrLimit: dsrLimit,
    finalLimit: finalLimit,
    loan: loan,
    dsrPercent: dsrPercent,
    limitedBy: limitedBy,
    years: years,
    scenarios: scenarios,
    notes: notes,
  );
}