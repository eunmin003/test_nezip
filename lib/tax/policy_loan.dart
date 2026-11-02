// 정책대출(디딤돌·보금자리론) 대상 여부 확인 (2026년 10월 공시 기준, 모의 확인용)
// 디딤돌: 주택도시기금 / 보금자리론: 한국주택금융공사
import 'dart:math' as math;
import 'calculator.dart' show kEok, kMan;
import 'loan_calculator.dart' show HouseStatus;

class PolicyLoanInput {
  final int price; // 집값
  final int householdIncome; // 부부합산 연소득
  final int applicantIncome; // 신청인 본인 연소득 (신혼 소득특례 판단용, 없으면 0)
  final int netAssets; // 부부합산 순자산
  final HouseStatus status;
  final bool newlywed; // 혼인 7년 이내 (또는 3개월 내 결혼 예정)
  final int children; // 미성년 자녀 수
  final bool area85OrLess; // 전용 85㎡ 이하
  final bool regulated; // 조정대상지역
  final int existingAnnualRepay; // 기존 대출 1년 원리금

  const PolicyLoanInput({
    required this.price,
    required this.householdIncome,
    required this.applicantIncome,
    required this.netAssets,
    required this.status,
    required this.newlywed,
    required this.children,
    required this.area85OrLess,
    required this.regulated,
    required this.existingAnnualRepay,
  });
}

class PolicyLoanCheck {
  final String name;
  final bool eligible;
  final List<String> passed; // 충족한 조건
  final List<String> failed; // 못 채운 조건
  final int maxLimit; // 예상 최대 한도 (대상일 때)
  final String rateText; // 금리 안내
  final List<String> notes;

  const PolicyLoanCheck({
    required this.name,
    required this.eligible,
    required this.passed,
    required this.failed,
    required this.maxLimit,
    required this.rateText,
    required this.notes,
  });
}

// ── 디딤돌 (주택도시기금, 2026년 기준)
const int kDidimdolIncomeBasic = 6000 * kMan;
const int kDidimdolIncomeFirstOrKids = 7000 * kMan; // 생애최초·2자녀 이상
const int kDidimdolIncomeNewlywed = 8500 * kMan;
const int kDidimdolNetAssets = 51100 * kMan; // 5.11억 (매년 갱신)
const int kDidimdolPriceBasic = 5 * kEok;
const int kDidimdolPriceNewlyKids = 6 * kEok; // 신혼·2자녀 이상
const int kDidimdolLimitBasic = 2 * kEok;
const int kDidimdolLimitFirst = 24000 * kMan; // 2.4억
const int kDidimdolLimitNewlyKids = 32000 * kMan; // 3.2억

// ── 보금자리론 (한국주택금융공사, 2026년 10월 기준)
const int kBogeumPrice = 6 * kEok;
const int kBogeumIncomeBasic = 7000 * kMan;
const int kBogeumIncomeNewlywed = 8500 * kMan;
const int kBogeumIncomeOneKid = 9000 * kMan;
const int kBogeumIncomeTwoKids = 1 * kEok;
const int kBogeumNewlywedSingle = 7000 * kMan; // 2026.10.19~ 신혼 1인 소득특례
const int kBogeumLimitBasic = 36000 * kMan; // 3.6억
const int kBogeumLimitMultiKids = 4 * kEok;
const int kBogeumLimitFirst = 42000 * kMan; // 4.2억

const double kPolicyLtvCapital = 0.70; // 수도권·규제지역
const double kPolicyDti = 0.60;

int _floor10man(num v) => (v ~/ 100000) * 100000;

/// DTI 60%로 빌릴 수 있는 원금 (30년 원리금균등, 대표 금리)
int _dtiLimit(int income, int existing, double rate) {
  final allowed = income * kPolicyDti - existing;
  if (allowed <= 0) return 0;
  const n = 360;
  final r = rate / 12;
  final p = math.pow(1 + r, n).toDouble();
  final annualFactor = r * p / (p - 1) * 12;
  return _floor10man(allowed / annualFactor);
}

String _comma(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _man(int won) {
  final eok = won ~/ kEok;
  final man = (won % kEok) ~/ kMan;
  if (eok > 0 && man > 0) return '$eok억 ${_comma(man)}만원';
  if (eok > 0) return '$eok억원';
  return '${_comma(man)}만원';
}

List<PolicyLoanCheck> checkPolicyLoans(PolicyLoanInput i) {
  return [_didimdol(i), _bogeumjari(i)];
}

PolicyLoanCheck _didimdol(PolicyLoanInput i) {
  final passed = <String>[];
  final failed = <String>[];
  final first = i.status == HouseStatus.firstTime;
  final kids2 = i.children >= 2;

  // 주택 보유
  if (first || i.status == HouseStatus.noHouse) {
    passed.add('무주택');
  } else {
    failed.add('무주택 세대주만 신청할 수 있어요');
  }

  // 소득
  final incomeCap = i.newlywed
      ? kDidimdolIncomeNewlywed
      : (first || kids2 ? kDidimdolIncomeFirstOrKids : kDidimdolIncomeBasic);
  if (i.householdIncome <= incomeCap) {
    passed.add('부부합산 소득 ${_man(incomeCap)} 이하');
  } else {
    failed.add('부부합산 소득이 ${_man(incomeCap)}을 넘어요');
  }

  // 순자산
  if (i.netAssets <= kDidimdolNetAssets) {
    passed.add('순자산 ${_man(kDidimdolNetAssets)} 이하');
  } else {
    failed.add('순자산이 ${_man(kDidimdolNetAssets)}을 넘어요');
  }

  // 주택가격
  final priceCap = (i.newlywed || kids2) ? kDidimdolPriceNewlyKids : kDidimdolPriceBasic;
  if (i.price <= priceCap) {
    passed.add('집값 ${_man(priceCap)} 이하');
  } else {
    failed.add('집값이 ${_man(priceCap)}을 넘어요');
  }

  // 면적
  if (i.area85OrLess) {
    passed.add('전용 85㎡ 이하');
  } else {
    failed.add('전용 85㎡ 이하 주택만 가능해요');
  }

  // 한도: 상품 한도, LTV 70%, DTI 60% 중 가장 작은 값
  var cap = kDidimdolLimitBasic;
  if (first) cap = math.max(cap, kDidimdolLimitFirst);
  if (i.newlywed || kids2) cap = math.max(cap, kDidimdolLimitNewlyKids);
  final ltv = _floor10man(i.price * kPolicyLtvCapital);
  final dti = _dtiLimit(i.householdIncome, i.existingAnnualRepay, 0.035);
  final limit = [cap, ltv, dti].reduce(math.min);

  return PolicyLoanCheck(
    name: '디딤돌대출',
    eligible: failed.isEmpty,
    passed: passed,
    failed: failed,
    maxLimit: failed.isEmpty ? limit : 0,
    rateText: '연 2.85~4.15% (소득·만기별, 우대금리 적용 시 더 낮아질 수 있음)',
    notes: [
      '상품 한도 ${_man(cap)} · LTV 70% · DTI 60% 중 가장 작은 금액이에요.',
      '수도권은 대출 후 6개월 안에 전입해야 해요.',
    ],
  );
}

PolicyLoanCheck _bogeumjari(PolicyLoanInput i) {
  final passed = <String>[];
  final failed = <String>[];
  final first = i.status == HouseStatus.firstTime;

  // 주택 보유: 무주택 또는 처분조건부 1주택
  if (first || i.status == HouseStatus.noHouse || i.status == HouseStatus.oneSellPlan) {
    passed.add(i.status == HouseStatus.oneSellPlan ? '처분조건부 1주택' : '무주택');
  } else {
    failed.add('무주택 또는 기존 집을 파는 조건의 1주택만 가능해요');
  }

  // 소득
  int incomeCap = kBogeumIncomeBasic;
  if (i.newlywed) incomeCap = kBogeumIncomeNewlywed;
  if (i.children == 1) incomeCap = math.max(incomeCap, kBogeumIncomeOneKid);
  if (i.children >= 2) incomeCap = math.max(incomeCap, kBogeumIncomeTwoKids);
  final newlywedSpecial = i.newlywed &&
      i.householdIncome > incomeCap &&
      i.applicantIncome > 0 &&
      i.applicantIncome <= kBogeumNewlywedSingle;
  if (i.householdIncome <= incomeCap) {
    passed.add('부부합산 소득 ${_man(incomeCap)} 이하');
  } else if (newlywedSpecial) {
    passed.add('신혼 소득특례 (본인 소득 7천만원 이하)');
  } else {
    failed.add('부부합산 소득이 ${_man(incomeCap)}을 넘어요');
  }

  // 주택가격
  if (i.price <= kBogeumPrice) {
    passed.add('집값 6억 이하');
  } else {
    failed.add('집값이 6억을 넘어요');
  }

  // 한도
  var cap = kBogeumLimitBasic;
  if (i.children >= 2) cap = math.max(cap, kBogeumLimitMultiKids);
  if (first) cap = math.max(cap, kBogeumLimitFirst);
  final ltv = _floor10man(i.price * kPolicyLtvCapital);
  final dti = _dtiLimit(i.householdIncome, i.existingAnnualRepay, 0.05);
  final limit = [cap, ltv, dti].reduce(math.min);

  return PolicyLoanCheck(
    name: '보금자리론',
    eligible: failed.isEmpty,
    passed: passed,
    failed: failed,
    maxLimit: failed.isEmpty ? limit : 0,
    rateText: i.regulated
        ? '연 4.90~5.20% + 규제지역 0.2%p (우대금리 최대 1.0%p 차감)'
        : '연 4.90~5.20% (우대금리 최대 1.0%p 차감)',
    notes: [
      '상품 한도 ${_man(cap)} · LTV 70% · DTI 60% 중 가장 작은 금액이에요.',
      if (newlywedSpecial) '신혼 소득특례는 2026.10.19 신청분부터 적용돼요. 우대금리가 자동으로 붙지는 않아요.',
      if (i.status == HouseStatus.oneSellPlan) '기존 집은 약정 기한 안에 팔아야 해요.',
    ],
  );
}
