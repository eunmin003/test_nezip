import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../widgets/term_text.dart';

/// AI 상담 화면 (지도·관심 단지 등 모든 탭의 💬 버튼, 마이 > AI 상담에서 열림)
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _waiting = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _waiting) return;
    _input.clear();
    setState(() {
      _messages.add(ChatMessage(fromUser: true, text: q));
      _waiting = true;
    });
    _scrollToBottom();

    String answer;
    try {
      answer = await ChatService.ask(q, history: List.of(_messages));
    } catch (_) {
      answer = '답변을 가져오지 못했어요. 잠시 후 다시 시도해 주세요.';
    }
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(fromUser: false, text: answer));
      _waiting = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI 상담 안내'),
        content: const Text(
          '· 정비사업 절차, 부동산 용어, 세금·대출 제도를 쉽게 설명해 드려요.\n'
          '· 특정 단지 추천, 가격 전망, 투자 판단은 하지 않아요.\n'
          '· 답변은 참고용이에요. 세율·대출 한도는 바뀔 수 있으니 계산기와 공식 기관에서 꼭 확인하세요.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final started = _messages.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 상담'),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), tooltip: '안내', onPressed: _showInfo),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                const _BotBubble(
                  text: '안녕하세요! 정비사업, 세금, 대출에 대해 궁금한 걸 물어보세요.\n'
                      '일반 정보 안내용이에요. 특정 단지 추천이나 투자 판단은 하지 않아요.',
                  showNotice: false,
                ),
                if (!started) ...[
                  const SizedBox(height: 16),
                  _QuestionGroup(title: '추천 질문', questions: kRecommendedQuestions, onTap: _send),
                  const SizedBox(height: 12),
                  _QuestionGroup(title: '자주 묻는 질문', questions: kFrequentQuestions, onTap: _send),
                ],
                for (final m in _messages)
                  m.fromUser ? _UserBubble(m.text) : _BotBubble(text: m.text),
                if (_waiting) const _TypingBubble(),
              ],
            ),
          ),

          // 대화 중에는 질문 버튼을 입력창 위에 한 줄로
          if (started)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final q in [...kRecommendedQuestions, ...kFrequentQuestions])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(q, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        onPressed: _waiting ? null : () => _send(q),
                      ),
                    ),
                ],
              ),
            ),

          // 입력창
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: InputDecoration(
                        hintText: '궁금한 걸 입력하세요',
                        isDense: true,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: '보내기',
                    onPressed: _waiting ? null : () => _send(_input.text),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 질문 버튼 묶음
class _QuestionGroup extends StatelessWidget {
  final String title;
  final List<String> questions;
  final ValueChanged<String> onTap;
  const _QuestionGroup({required this.title, required this.questions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey[700])),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final q in questions)
              ActionChip(
                avatar: const Icon(Icons.chat_bubble_outline, size: 16),
                label: Text(q),
                onPressed: () => onTap(q),
              ),
          ],
        ),
      ],
    );
  }
}

/// 내 질문 말풍선 (오른쪽)
class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 12, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(text, style: TextStyle(color: cs.onPrimary, height: 1.4)),
      ),
    );
  }
}

/// AI 답변 말풍선 (왼쪽) — 어려운 용어는 굵게, 누르면 뜻 풀이
class _BotBubble extends StatelessWidget {
  final String text;
  final bool showNotice;
  const _BotBubble({required this.text, this.showNotice = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: cs.primaryContainer,
            child: Icon(Icons.smart_toy_outlined, size: 18, color: cs.primary),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: TermText(text, style: TextStyle(color: cs.onSurface, height: 1.5)),
                ),
                if (showNotice)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text('참고용 답변이에요 · 정확한 판단은 세무사·은행·구청 확인',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 답변 기다리는 중 표시
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: cs.primaryContainer,
            child: Icon(Icons.smart_toy_outlined, size: 18, color: cs.primary),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const SizedBox(
              width: 28,
              height: 12,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          ),
        ],
      ),
    );
  }
}
