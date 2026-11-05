import 'package:flutter/material.dart';

import '../models/favorite_complex.dart';
import '../services/auth_service.dart';
import 'calc_basis_screen.dart';
import 'favorite_screen.dart';
import 'glossary_screen.dart';

/// ⑤ 마이 탭: 프로필 / 내 활동 / 도움말 / 계정
class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  final auth = AuthService.instance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    auth.init();
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Future<void> _login() async {
    setState(() => _busy = true);
    final ok = await auth.login();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(ok ? '로그인했어요' : '로그인에 실패했어요. 다시 시도해 주세요');
  }

  Future<void> _logout() async {
    final yes = await _confirm(
      title: '로그아웃할까요?',
      body: '찜한 단지는 이 기기에 그대로 남아 있어요.',
      action: '로그아웃',
    );
    if (yes != true) return;
    await auth.logout();
    _toast('로그아웃했어요');
  }

  Future<void> _withdraw() async {
    final yes = await _confirm(
      title: '정말 탈퇴할까요?',
      body: '찜한 관심 단지와 로그인 정보가 모두 삭제되고 되돌릴 수 없어요.',
      action: '탈퇴하기',
      danger: true,
    );
    if (yes != true) return;
    await auth.withdraw();
    _toast('탈퇴가 완료됐어요. 그동안 이용해 주셔서 감사해요');
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String action,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: Colors.red) : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('마이')),
      body: ValueListenableBuilder<AppUser?>(
        valueListenable: auth.user,
        builder: (context, user, _) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // ── 프로필 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: user == null
                    ? _LoginCard(busy: _busy, onLogin: _login)
                    : _ProfileCard(user: user),
              ),

              // ── 내 활동 ──
              const _SectionTitle('내 활동'),
              ValueListenableBuilder<List<FavoriteComplex>>(
                valueListenable: FavoriteStore.instance.items,
                builder: (context, items, _) => ListTile(
                  leading: const Icon(Icons.favorite_border),
                  title: const Text('관심 단지'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${items.length}개',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700)),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => _push(const FavoriteScreen()),
                ),
              ),

              // ── 도움말 ──
              const _SectionTitle('도움말'),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('용어 사전'),
                subtitle: const Text('어려운 부동산 용어를 쉽게 풀었어요'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(const GlossaryScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('계산 기준 · 근거 법령'),
                subtitle: const Text('세금·대출 계산이 어떤 기준으로 되는지'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(const CalcBasisScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.smart_toy_outlined),
                title: const Text('AI 상담'),
                subtitle: const Text('준비 중이에요'),
                trailing: const Icon(Icons.chevron_right),
                enabled: false,
              ),

              // ── 계정 (로그인했을 때만) ──
              if (user != null) ...[
                const _SectionTitle('계정'),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('로그아웃'),
                  onTap: _logout,
                ),
                ListTile(
                  leading: Icon(Icons.person_remove_outlined, color: Colors.red[400]),
                  title: Text('회원탈퇴', style: TextStyle(color: Colors.red[400])),
                  onTap: _withdraw,
                ),
              ],

              // ── 앱 정보 ──
              const SizedBox(height: 16),
              Center(
                child: Text('내집마련 A to Z · 버전 1.0.0',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text('세금·대출 계산은 참고용이에요. 실제 금액은 다를 수 있어요.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 로그인 전 카드
class _LoginCard extends StatelessWidget {
  final bool busy;
  final VoidCallback onLogin;
  const _LoginCard({required this.busy, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('로그인하고 관심 단지를 지켜요', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('기기를 바꿔도 찜한 단지를 다시 볼 수 있게 준비 중이에요',
                style: t.bodySmall?.copyWith(color: Colors.grey[700])),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              // 카카오 로그인 버튼 색 (노랑 #FEE500, 글자 검정 85%)
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE500),
                  foregroundColor: const Color(0xD9000000),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: busy ? null : onLogin,
                icon: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chat_bubble, size: 18),
                label: const Text('카카오로 시작하기', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 로그인 후 프로필 카드
class _ProfileCard extends StatelessWidget {
  final AppUser user;
  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.primary.withValues(alpha: 0.2),
              backgroundImage: user.profileImageUrl != null ? NetworkImage(user.profileImageUrl!) : null,
              child: user.profileImageUrl == null
                  ? Icon(Icons.person, size: 30, color: scheme.primary)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${user.nickname} 님', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(user.provider == 'kakao' ? '카카오 계정으로 로그인' : '테스트 로그인 (카카오 연결 전)',
                      style: t.bodySmall?.copyWith(color: Colors.grey[700])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
        child: Text(text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey[700])),
      );
}
