import 'package:flutter/material.dart';

import 'loan_simulator_screen.dart';
import 'tax_simulator_screen.dart';

/// 계산기 탭: 세금 / 대출
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
            tabs: [Tab(text: '세금'), Tab(text: '대출')],
          ),
        ),
        body: const TabBarView(
          children: [
            TaxSimulatorScreen(),
            LoanSimulatorScreen(),
          ],
        ),
      ),
    );
  }
}