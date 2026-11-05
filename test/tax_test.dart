// 세금·대출 계산 단위 테스트
// 실행: 터미널에서  flutter test test/tax_test.dart
// 기대값은 앱 화면에서 확인한 값 + 계산식으로 직접 검산한 값이에요.
import 'package:flutter_test/flutter_test.dart';

import 'package:myzip/tax/calculator.dart';
import 'package:myzip/tax/right_transfer_tax.dart';
import 'package:myzip/tax/holding_tax.dart';
import 'package:myzip/tax/loan_calculator.dart';

void main() {
  // ───────────────── 취득세 ─────────────────
  group('취득세', () {
    test('5억 · 1주택 → 5,500,000원 (취득세 1% + 지방교육세 0.1%)', () {
      final r = calcAcquisitionTax(const AcquisitionInput(
        price: 500000000,
        housesAfter: 1,
        regulated: true,
        over85: false,
        temporaryTwo: false,
        firstHome: false,
      ));
      expect(r.total, 5500000);
    });

    test('5억 · 생애최초 → 3,300,000원 (200만원 감면 + 지방교육세 같은 비율 감면)', () {
      final r = calcAcquisitionTax(const AcquisitionInput(
        price: 500000000,
        housesAfter: 1,
        regulated: true,
        over85: false,
        temporaryTwo: false,
        firstHome: true,
      ));
      expect(r.total, 3300000);
    });

    test('8억 · 1주택 → 세율 2.33%, 20,504,000원 (6~9억 구간 산식)', () {
      final r = calcAcquisitionTax(const AcquisitionInput(
        price: 800000000,
        housesAfter: 1,
        regulated: false,
        over85: false,
        temporaryTwo: false,
        firstHome: false,
      ));
      expect(r.total, 20504000);
    });

    test('5억 · 조정지역 3주택 → 12% 중과, 62,000,000원', () {
      final r = calcAcquisitionTax(const AcquisitionInput(
        price: 500000000,
        housesAfter: 3,
        regulated: true,
        over85: false,
        temporaryTwo: false,
        firstHome: false,
      ));
      expect(r.total, 62000000);
    });
  });

  // ───────────────── 양도세 (주택) ─────────────────
  group('양도세 (주택)', () {
    test('조정지역 2주택 중과: 10억-5억, 5년 보유 → 299,816,000원', () {
      final r = calcTransferTax(const TransferInput(
        salePrice: 1000000000,
        buyPrice: 500000000,
        expenses: 0,
        holdMonths: 60,
        liveMonths: 0,
        houses: 2,
        regulatedNow: true,
        regulatedAtBuy: true,
        temporaryTwo: false,
      ));
      expect(r.total, 299816000);
    });
  });

  // ───────────────── 입주권·분양권 양도세 ─────────────────
  group('입주권·분양권 양도세', () {
    // 앱에서 테스트한 입력과 같음 (양도일만 고정 날짜로)
    RightTransferInput original({required int houses}) => RightTransferInput(
      type: RightType.memberOriginal,
      salePrice: 1000000000, // 10억
      buyPrice: 300000000, // 종전 주택 3억
      expenses: 0,
      rightValue: 500000000, // 권리가액 5억
      paidSettlement: 100000000, // 추가분담금 1억
      buyDate: DateTime(2015, 1, 1),
      saleDate: DateTime(2026, 11, 2),
      approvalDate: DateTime(2022, 1, 1), // 인가일까지 7년 → 장특공 14%
      liveMonths: 0,
      houses: houses,
      regulatedAtBuy: false,
    );

    test('원조합원 2주택 → 223,575,000원', () {
      expect(calcRightTransferTax(original(houses: 2)).total, 223575000);
    });

    test('원조합원 1주택 → 0원 (비과세)', () {
      expect(calcRightTransferTax(original(houses: 1)).total, 0);
    });

    test('분양권 6억-5억, 1년 이상 보유 → 60% 세율, 64,350,000원', () {
      final r = calcRightTransferTax(RightTransferInput(
        type: RightType.presale,
        salePrice: 600000000,
        buyPrice: 500000000,
        expenses: 0,
        rightValue: 0,
        paidSettlement: 0,
        buyDate: DateTime(2024, 1, 1),
        saleDate: DateTime(2026, 11, 2),
        approvalDate: null,
        liveMonths: 0,
        houses: 1,
        regulatedAtBuy: false,
      ));
      expect(r.total, 64350000);
    });
  });

  // ───────────────── 보유세 ─────────────────
  group('보유세', () {
    test('관양현대 공시가 5억 6,600만 · 1주택 · 도시지역 → 730,340원', () {
      final r = calcHoldingTax(const HoldingInput(
        officialPrice: 566000000,
        houses: 1,
        otherOfficialTotal: 0,
        age: 40,
        holdYears: 3,
        urbanArea: true,
      ));
      expect(r.total, 730340); // 재산세 318,080 + 도시지역분 348,650 + 지방교육세 63,610
    });
  });

  // ───────────────── 대출 ─────────────────
  group('대출', () {
    test('4.5억 강남 생애최초, 연소득 6천만, 4% 변동 30년 → 3억 60만원 (DSR)', () {
      final r = calcLoan(const LoanInput(
        price: 450000000,
        regulated: true,
        status: HouseStatus.firstTime,
        annualIncome: 60000000,
        existingAnnualRepay: 0,
        rate: 0.04,
        years: 30,
        variableRate: true, // 스트레스 3%p → DSR은 7%로 계산
        repay: RepayType.equalPayment,
      ));
      expect(r.ltvLimit, 315000000); // LTV 70%
      expect(r.loan, 300600000);
      expect(r.limitedBy, 'DSR');
    });

    test('20억 · 비규제 무주택 → 수도권 상한 4억에 걸림', () {
      final r = calcLoan(const LoanInput(
        price: 2000000000,
        regulated: false,
        status: HouseStatus.noHouse,
        annualIncome: 300000000,
        existingAnnualRepay: 0,
        rate: 0.04,
        years: 30,
        variableRate: true,
        repay: RepayType.equalPayment,
      ));
      expect(r.loan, 400000000);
      expect(r.limitedBy, '수도권 금액 상한');
    });

    test('2주택 이상 → 대출 불가 (0원)', () {
      final r = calcLoan(const LoanInput(
        price: 800000000,
        regulated: true,
        status: HouseStatus.multi,
        annualIncome: 100000000,
        existingAnnualRepay: 0,
        rate: 0.04,
        years: 30,
        variableRate: true,
        repay: RepayType.equalPayment,
      ));
      expect(r.loan, 0);
      expect(r.limitedBy, '대출 불가');
    });
  });
}