import 'package:flutter/material.dart';

import 'home_shell.dart';

/// ④ 소식 탭
/// 다음 단계: 뉴스 RSS 목록 + 관심 단지 관련 기사 먼저 보여주기
class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('소식')),
      body: const ComingSoon(
        icon: Icons.newspaper_outlined,
        title: '소식',
        plans: [
          '정비사업·부동산 정책 뉴스',
          '대출 규제·세금 개편 소식',
          '관심 단지 관련 기사',
        ],
      ),
    );
  }
}