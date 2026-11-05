import 'package:flutter/material.dart';

import '../data/glossary.dart';
import '../widgets/term_text.dart';

/// 용어 사전 전체 보기 (검색 + 분야별)
/// 나중에 마이 페이지 메뉴에서도 이 화면으로 연결하면 됩니다.
class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  String _query = '';
  TermCategory? _category; // null이면 전체

  List<GlossaryTerm> get _filtered {
    final q = _query.trim();
    return kGlossary.where((t) {
      if (_category != null && t.category != _category) return false;
      if (q.isEmpty) return true;
      return t.term.contains(q) ||
          t.aliases.any((a) => a.contains(q)) ||
          t.short.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('용어 사전')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: '궁금한 용어 검색 (예: 분담금, LTV)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Text('전체'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                ),
                for (final c in TermCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(c.label),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('찾는 용어가 없어요'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final term = items[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        title: Text(term.term, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        subtitle: Text(term.short),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showTermSheet(context, term.term),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
