import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/favorite_complex.dart';
import '../services/news_service.dart';

/// ④ 소식 탭: 정비사업·대출·세금 정책 뉴스 + 관심 단지 관련 기사
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  NewsCategory _category = NewsCategory.all;
  late Future<List<NewsItem>> _news = NewsService.fetch(_category);
  Future<List<NewsItem>>? _favoriteNews;
  String _favoriteKey = '';

  @override
  void initState() {
    super.initState();
    FavoriteStore.instance.items.addListener(_onFavoritesChanged);
    _updateFavoriteNews(); // 처음에는 setState 없이
  }

  @override
  void dispose() {
    FavoriteStore.instance.items.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  /// 관심 단지가 바뀌면 관련 기사 다시 찾기 (정비구역 이름 우선, 없으면 단지명)
  void _onFavoritesChanged() {
    if (mounted) setState(_updateFavoriteNews);
  }

  void _updateFavoriteNews() {
    final names = FavoriteStore.instance.items.value
        .map((c) => (c.zoneName != null && c.zoneName != '정비구역') ? c.zoneName! : c.name)
        .toList();
    final key = names.join('|');
    if (key == _favoriteKey) return;
    _favoriteKey = key;
    _favoriteNews = names.isEmpty ? null : NewsService.forNames(names);
  }

  void _select(NewsCategory c) {
    setState(() {
      _category = c;
      _news = NewsService.fetch(c);
    });
  }

  Future<void> _refresh() async {
    final f = NewsService.fetch(_category, refresh: true);
    setState(() => _news = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('소식')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            // ── 분야 선택 칩 ──
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    for (final c in NewsCategory.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c.label),
                          selected: _category == c,
                          onSelected: (_) => _select(c),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── 관심 단지 관련 기사 (찜한 단지가 있을 때만) ──
            if (_favoriteNews != null)
              SliverToBoxAdapter(
                child: FutureBuilder<List<NewsItem>>(
                  future: _favoriteNews,
                  builder: (context, snap) {
                    final items = (snap.data ?? const <NewsItem>[]).take(3).toList();
                    if (snap.connectionState == ConnectionState.done && items.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return _FavoriteNewsBox(
                      loading: snap.connectionState != ConnectionState.done,
                      items: items,
                    );
                  },
                ),
              ),

            // ── 뉴스 목록 ──
            FutureBuilder<List<NewsItem>>(
              future: _news,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final items = snap.data ?? const <NewsItem>[];
                if (items.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('뉴스를 불러오지 못했어요.\n아래로 당겨서 다시 시도해 주세요.',
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => _NewsTile(items[i]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 관심 단지 관련 기사 상자
class _FavoriteNewsBox extends StatelessWidget {
  final bool loading;
  final List<NewsItem> items;
  const _FavoriteNewsBox({required this.loading, required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text('관심 단지 관련 소식',
                  style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary)),
            ],
          ),
          const SizedBox(height: 6),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else
            for (final n in items) _NewsTile(n, compact: true),
        ],
      ),
    );
  }
}

/// 기사 한 줄 (언론사 → 제목 → 몇 시간/며칠 전)
///   ⓒ 조선비즈
///   "6개 기관 떠나는데 협의 한 번 없어"… 과천시, 세종 이전에 반발
///   19시간 전
class _NewsTile extends StatelessWidget {
  final NewsItem n;
  final bool compact; // 관심 단지 상자 안에서는 조금 작게
  const _NewsTile(this.n, {this.compact = false});

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(n.link);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('기사를 열 수 없어요')));
      }
    }
  }

  /// 읽기 쉬운 시간 표시: 방금 전 / 15분 전 / 19시간 전 / 2일 전
  static String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '방금 전';
    if (d.inMinutes < 60) return '${d.inMinutes}분 전';
    if (d.inHours < 24) return '${d.inHours}시간 전';
    return '${d.inDays}일 전';
  }

  /// 언론사 로고(사이트 아이콘). 못 불러오면 신문 아이콘으로 대신.
  Widget _sourceIcon() {
    final host = Uri.tryParse(n.sourceUrl)?.host ?? '';
    const fallback = Icon(Icons.newspaper, size: 16, color: Colors.grey);
    if (host.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Image.network(
        'https://www.google.com/s2/favicons?domain=$host&sz=64',
        width: 16,
        height: 16,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 8 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ① 언론사
            Row(
              children: [
                _sourceIcon(),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    n.source.isEmpty ? '출처 미상' : n.source,
                    style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // ② 기사 제목
            Text(
              n.title,
              style: (compact ? textTheme.bodyLarge : textTheme.titleMedium)
                  ?.copyWith(height: 1.35),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // ③ 발행 시점
            Text(
              _ago(n.published),
              style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
