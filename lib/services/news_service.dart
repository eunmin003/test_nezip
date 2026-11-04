// lib/services/news_service.dart
//
// 부동산 정책·정비사업 뉴스 가져오기 (구글 뉴스 RSS 검색, 인증키 필요 없음)
//   https://news.google.com/rss/search?q=검색어&hl=ko&gl=KR&ceid=KR:ko
//
// - 분야별 검색어로 최근 7일 기사를 가져와 최신순으로 정렬합니다.
// - 같은 기사가 여러 분야에 걸리면 한 번만 보여줍니다.
// - 나중에 서버(교수님 서버)를 붙이면 네이버 뉴스 검색 API로 바꿀 수 있게
//   화면은 NewsItem만 쓰도록 분리해 두었습니다.

import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

enum NewsCategory { all, redevelopment, loan, tax }

extension NewsCategoryLabel on NewsCategory {
  String get label => switch (this) {
        NewsCategory.all => '전체',
        NewsCategory.redevelopment => '재개발·재건축',
        NewsCategory.loan => '대출·규제',
        NewsCategory.tax => '세금',
      };
}

class NewsItem {
  final String title;
  final String source; // 언론사
  final String sourceUrl; // 언론사 홈페이지 (로고 아이콘용)
  final String link;
  final DateTime? published;
  final NewsCategory category;

  const NewsItem({
    required this.title,
    required this.source,
    required this.sourceUrl,
    required this.link,
    required this.published,
    required this.category,
  });
}

class NewsService {
  /// 분야별 검색어 (OR로 묶으면 그중 하나만 들어가도 검색됨)
  static const Map<NewsCategory, String> _queries = {
    NewsCategory.redevelopment: '재개발 OR 재건축 OR 정비사업 OR 신속통합기획 OR 정비구역',
    NewsCategory.loan: '주택담보대출 OR LTV OR DSR OR 부동산 대출 규제 OR 토지거래허가구역',
    NewsCategory.tax: '취득세 OR 양도소득세 OR 종합부동산세 OR 재산세 OR 부동산 세제',
  };

  /// 같은 검색을 10분 안에 다시 하면 저장해 둔 결과를 씀
  static final Map<String, (DateTime, List<NewsItem>)> _cache = {};
  static const _cacheTime = Duration(minutes: 10);

  /// 분야별 뉴스. [NewsCategory.all]이면 세 분야를 합쳐서 최신순.
  static Future<List<NewsItem>> fetch(NewsCategory category, {bool refresh = false}) async {
    if (category != NewsCategory.all) {
      return _search(_queries[category]!, category, refresh: refresh);
    }
    final results = await Future.wait([
      for (final c in _queries.keys) _search(_queries[c]!, c, refresh: refresh),
    ]);
    return _dedupeAndSort(results.expand((l) => l).toList());
  }

  /// 관심 단지·정비구역 이름으로 관련 기사 찾기 (이름 최대 5개)
  static Future<List<NewsItem>> forNames(List<String> names, {bool refresh = false}) async {
    final clean = names
        .map((n) => n.trim())
        .where((n) => n.length >= 2 && n != '정비구역')
        .toSet()
        .take(5)
        .map((n) => '"$n"')
        .toList();
    if (clean.isEmpty) return [];
    return _search(clean.join(' OR '), NewsCategory.redevelopment, refresh: refresh, days: 30);
  }

  static Future<List<NewsItem>> _search(
    String query,
    NewsCategory category, {
    bool refresh = false,
    int days = 7,
  }) async {
    final key = '$query|$days';
    final cached = _cache[key];
    if (!refresh && cached != null && DateTime.now().difference(cached.$1) < _cacheTime) {
      return cached.$2;
    }

    final uri = Uri.https('news.google.com', '/rss/search', {
      'q': '$query when:${days}d',
      'hl': 'ko',
      'gl': 'KR',
      'ceid': 'KR:ko',
    });

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        debugPrint('[뉴스] HTTP ${res.statusCode}');
        return cached?.$2 ?? [];
      }
      final doc = XmlDocument.parse(utf8.decode(res.bodyBytes));
      final items = <NewsItem>[];
      for (final it in doc.findAllElements('item')) {
        String text(String tag) => it.getElement(tag)?.innerText.trim() ?? '';
        final source = text('source');
        final sourceUrl = it.getElement('source')?.getAttribute('url') ?? '';
        var title = text('title');
        // 구글 뉴스 제목 끝의 " - 언론사" 떼기
        if (source.isNotEmpty && title.endsWith(' - $source')) {
          title = title.substring(0, title.length - source.length - 3);
        }
        DateTime? published;
        try {
          published = HttpDate.parse(text('pubDate')).toLocal();
        } catch (_) {}
        items.add(NewsItem(
          title: title,
          source: source,
          sourceUrl: sourceUrl,
          link: text('link'),
          published: published,
          category: category,
        ));
      }
      final sorted = _dedupeAndSort(items);
      _cache[key] = (DateTime.now(), sorted);
      debugPrint('[뉴스] ${category.label}: ${sorted.length}건');
      return sorted;
    } catch (e) {
      debugPrint('[뉴스] 가져오기 실패: $e');
      return cached?.$2 ?? [];
    }
  }

  static List<NewsItem> _dedupeAndSort(List<NewsItem> items) {
    final seen = <String>{};
    final out = items.where((n) => seen.add(n.title)).toList();
    out.sort((a, b) =>
        (b.published ?? DateTime(2000)).compareTo(a.published ?? DateTime(2000)));
    return out;
  }
}
