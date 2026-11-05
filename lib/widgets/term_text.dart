// lib/widgets/term_text.dart
//
// 어려운 용어를 굵게 표시하고, 누르면 뜻 풀이 카드를 보여주는 글자 위젯
//
// 사용법:
//   TermText('이 구역은 관리처분인가 단계예요')          // 글 속 용어 자동 찾기
//   TermText('추진 단계', style: ...)                   // Text 대신 그대로 바꿔 쓰면 됨
//   TermLabel('관리처분인가')                            // 단어 하나만 (칩·라벨용)
//   showTermSheet(context, '분담금')                    // 직접 뜻 풀이 열기

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/glossary.dart';
import '../screens/glossary_screen.dart';

/// 글자 속 용어를 찾는 정규식 (긴 단어부터 찾아야 "조합원입주권"이 "입주권"보다 먼저 잡힘)
final RegExp _termPattern = () {
  final words = kGlossaryIndex.entries
      .where((e) => e.value.autoLink)
      .map((e) => e.key)
      .toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return RegExp(words.map(RegExp.escape).join('|'));
}();

class TermText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  /// true면 같은 용어가 여러 번 나와도 처음 한 번만 굵게 (긴 글에서 덜 어지럽게)
  final bool firstOnly;

  const TermText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.firstOnly = true,
  });

  @override
  State<TermText> createState() => _TermTextState();
}

class _TermTextState extends State<TermText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final termStyle = base.copyWith(
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: base.color?.withValues(alpha: 0.5),
    );

    final spans = <InlineSpan>[];
    final seen = <String>{};
    var last = 0;
    for (final m in _termPattern.allMatches(widget.text)) {
      final word = m.group(0)!;
      final term = kGlossaryIndex[word]!;
      if (widget.firstOnly && !seen.add(term.term)) continue;

      if (m.start > last) spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      final r = TapGestureRecognizer()..onTap = () => showTermSheet(context, term.term);
      _recognizers.add(r);
      spans.add(TextSpan(text: word, style: termStyle, recognizer: r));
      last = m.end;
    }
    if (last < widget.text.length) spans.add(TextSpan(text: widget.text.substring(last)));

    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
    );
  }
}

/// 단어 하나짜리 라벨 (칩, 단계 표시 등). 사전에 없는 단어면 그냥 글자만 보여줌.
class TermLabel extends StatelessWidget {
  final String word;
  final TextStyle? style;
  const TermLabel(this.word, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final term = findTerm(word);
    final base = style ?? DefaultTextStyle.of(context).style;
    if (term == null) return Text(word, style: base);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => showTermSheet(context, term.term),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(word, style: base.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 2),
          Icon(Icons.help_outline, size: (base.fontSize ?? 14) + 1, color: base.color?.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}

/// 글자 안에 사전 용어가 들어 있으면 찾아줌 ("관리처분인가 단계" → 관리처분인가)
GlossaryTerm? findTerm(String text) {
  final exact = kGlossaryIndex[text.trim()];
  if (exact != null) return exact;
  final m = _termPattern.firstMatch(text);
  return m == null ? null : kGlossaryIndex[m.group(0)!];
}

/// 용어 뜻 풀이 카드
Future<void> showTermSheet(BuildContext context, String word) {
  final term = findTerm(word);
  if (term == null) return Future.value();
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _TermSheet(term: term, parent: context),
  );
}

class _TermSheet extends StatelessWidget {
  final GlossaryTerm term;
  final BuildContext parent; // 카드를 닫은 뒤에도 쓸 수 있는 바깥 화면의 context
  const _TermSheet({required this.term, required this.parent});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final related = term.related.map((w) => kGlossaryIndex[w]).whereType<GlossaryTerm>().toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(child: Text(term.term, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(term.category.label, style: t.labelSmall),
                ),
              ],
            ),
            if (term.aliases.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('같은 말: ${term.aliases.join(', ')}',
                  style: t.bodySmall?.copyWith(color: Colors.grey[700])),
            ],
            const SizedBox(height: 14),
            Text(term.short, style: t.titleMedium?.copyWith(height: 1.4)),
            const SizedBox(height: 10),
            Text(term.detail, style: t.bodyMedium?.copyWith(height: 1.6, color: Colors.grey[800])),
            if (related.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('함께 보면 좋은 용어', style: t.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in related)
                    ActionChip(
                      label: Text(r.term),
                      onPressed: () {
                        Navigator.of(context).pop();
                        showTermSheet(parent, r.term);
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('용어 사전 전체 보기'),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(parent).push(
                    MaterialPageRoute(builder: (_) => const GlossaryScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
