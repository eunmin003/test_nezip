import 'package:flutter/material.dart';

import 'home_shell.dart';

/// ② 관심 단지 탭
/// 다음 단계: 지도에서 찜한 단지 저장 → 목록 + 소속 정비구역 진행 단계 바 → 누르면 세금·대출 상세
class FavoriteScreen extends StatelessWidget {
  const FavoriteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('관심 단지')),
      body: const ComingSoon(
        icon: Icons.favorite_border,
        title: '관심 단지',
        plans: [
          '지도에서 찜한 단지 목록',
          '소속 정비구역의 진행 단계 바',
          '단지별 세금·대출 바로 계산',
        ],
      ),
    );
  }
}