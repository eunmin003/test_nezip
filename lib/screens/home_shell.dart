import 'package:flutter/material.dart';

import 'calculator_screen.dart';
import 'chat_screen.dart';
import 'favorite_screen.dart';
import 'map_screen.dart';
import 'my_screen.dart';
import 'news_screen.dart';

/// 앱의 뼈대: 하단 탭 5개 (지도 / 관심 단지 / 계산기 / 소식 / 마이)
///
/// IndexedStack을 써서 탭을 바꿔도 각 화면의 상태가 그대로 남아 있습니다.
/// (예: 지도 위치·줌, 계산기에 입력한 값)
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = <Widget>[
    MapScreen(),
    FavoriteScreen(),
    CalculatorScreen(),
    NewsScreen(),
    MyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      // 모든 탭 오른쪽 아래에 떠 있는 AI 상담 버튼 (스크롤해도 그 자리에 고정)
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'chat_fab',
        tooltip: 'AI 상담',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        ),
        child: const Icon(Icons.smart_toy_outlined),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: '지도',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: '관심 단지',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: '계산기',
          ),
          NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper),
            label: '소식',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '마이',
          ),
        ],
      ),
    );
  }
}

/// 아직 만들지 않은 화면에서 쓰는 공용 "준비 중" 표시
class ComingSoon extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> plans;

  const ComingSoon({
    super.key,
    required this.icon,
    required this.title,
    required this.plans,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('$title 준비 중', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final p in plans)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('· $p',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.grey[700])),
              ),
          ],
        ),
      ),
    );
  }
}