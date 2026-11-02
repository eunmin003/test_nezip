import 'package:flutter/material.dart';

import '../models/favorite_complex.dart';
import '../models/redev_zone.dart';
import '../tax/calculator.dart' show formatKorean;
import 'loan_simulator_screen.dart';
import 'tax_simulator_screen.dart';

/// ② 관심 단지 탭: 찜한 단지 + 정비사업 진행 단계 + 세금·대출 바로 계산
class FavoriteScreen extends StatelessWidget {
  const FavoriteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = FavoriteStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('관심 단지')),
      body: ValueListenableBuilder<List<FavoriteComplex>>(
        valueListenable: store.items,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border,
                        size: 56, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    const Text('아직 찜한 단지가 없어요'),
                    const SizedBox(height: 8),
                    const Text('지도에서 단지를 찜하면 여기에 모여요',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: store.loadSamples,
                      child: const Text('예시 단지 불러오기'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ComplexCard(items[i]),
          );
        },
      ),
    );
  }
}

const List<String> kStages = ['정비구역지정', '추진위원회', '조합설립', '사업시행', '관리처분', '착공', '준공'];

int stageIndex(String? stage) {
  if (stage == null) return -1;
  for (int i = kStages.length - 1; i >= 0; i--) {
    if (stage.contains(kStages[i])) return i;
  }
  return 0;
}

class _ComplexCard extends StatelessWidget {
  final FavoriteComplex c;
  const _ComplexCard(this.c);

  void _open(BuildContext context, int tab) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FavoriteDetailScreen(complex: c, initialTab: tab),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(c.name, style: t.titleMedium)),
                IconButton(
                  tooltip: '찜 해제',
                  icon: Icon(Icons.favorite, color: cs.error),
                  onPressed: () => FavoriteStore.instance.remove(c.id),
                ),
              ],
            ),
            Text(c.region.label, style: TextStyle(fontSize: 12, color: cs.outline)),
            const SizedBox(height: 8),
            Text(
              '최근 실거래가 ${formatKorean(c.recentPrice)}'
                  '${c.areaM2 != null ? ' · 전용 ${c.areaM2!.toStringAsFixed(0)}㎡' : ''}'
                  '${c.dealDate != null ? ' · ${c.dealDate}' : ''}',
            ),
            if (c.zoneName != null) ...[
              const SizedBox(height: 12),
              Text(c.zoneName!, style: t.labelLarge),
              const SizedBox(height: 6),
              _StageBar(stage: c.stage),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _open(context, 0),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('세금 계산'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _open(context, 1),
                    icon: const Icon(Icons.account_balance, size: 18),
                    label: const Text('대출 계산'),
                  ),
                ),
              ],
            ),
            if (c.isSample)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('예시 데이터예요 (실제 단지·가격 아님)',
                    style: TextStyle(fontSize: 11, color: cs.outline)),
              ),
          ],
        ),
      ),
    );
  }
}

/// 정비사업 진행 단계 바
class _StageBar extends StatelessWidget {
  final String? stage;
  const _StageBar({required this.stage});

  @override
  Widget build(BuildContext context) {
    final idx = stageIndex(stage);
    final color = RedevZone.stageColor(stage);
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int i = 0; i < kStages.length; i++)
              Expanded(
                child: Container(
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: i <= idx ? color : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          idx < 0 ? '진행 단계 정보 없음' : '${idx + 1}/${kStages.length}단계 · $stage',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// 관심 단지 상세: 세금 / 대출 (가격·지역 자동 입력)
class FavoriteDetailScreen extends StatelessWidget {
  final FavoriteComplex complex;
  final int initialTab;
  const FavoriteDetailScreen({super.key, required this.complex, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(complex.name),
          bottom: const TabBar(tabs: [Tab(text: '세금'), Tab(text: '대출')]),
        ),
        body: TabBarView(
          children: [
            TaxSimulatorScreen(initialPrice: complex.recentPrice, initialRegion: complex.region),
            LoanSimulatorScreen(initialPrice: complex.recentPrice, initialRegion: complex.region),
          ],
        ),
      ),
    );
  }
}