import 'package:flutter/material.dart';

import 'home_shell.dart';

/// ③ 계산기 탭: 위쪽에 [세금] [대출] 두 개의 안쪽 탭
class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('계산기'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '세금'),
              Tab(text: '대출'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // 다음 단계: lib/tax/ 세금 계산 엔진 + 입력 화면
            ComingSoon(
              icon: Icons.receipt_long_outlined,
              title: '세금 계산',
              plans: [
                '살 때: 취득세',
                '보유: 재산세·종합부동산세',
                '팔 때: 양도소득세',
                '증여세',
              ],
            ),
            // 다음 단계: LTV·DSR 한도 + 월 상환액 계산
            ComingSoon(
              icon: Icons.account_balance_outlined,
              title: '대출 계산',
              plans: [
                'LTV 기준 대출 한도',
                'DSR 기준 대출 한도',
                '월 상환액·총 이자',
              ],
            ),
          ],
        ),
      ),
    );
  }
}