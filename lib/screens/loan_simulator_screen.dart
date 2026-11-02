import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tax/calculator.dart' show kMan, formatKorean, formatWon, formatPct;
import '../tax/loan_calculator.dart';
import '../tax/policy_loan.dart';
import '../tax/region_rules.dart';
import 'calc_basis_screen.dart';

/// 대출 계산기 (LTV·DSR 한도 + 이자)
class LoanSimulatorScreen extends StatefulWidget {
  final int? initialPrice;
  final Region? initialRegion;
  const LoanSimulatorScreen({super.key, this.initialPrice, this.initialRegion});

  @override
  State<LoanSimulatorScreen> createState() => _LoanSimulatorScreenState();
}

class _LoanSimulatorScreenState extends State<LoanSimulatorScreen>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _price = TextEditingController(
      text: widget.initialPrice == null ? null : '${widget.initialPrice! ~/ kMan}');
  final _income = TextEditingController();
  final _existing = TextEditingController();
  final _rate = TextEditingController(text: '4.0');
  final _desired = TextEditingController();
  // 정책대출 확인용
  final _netAssets = TextEditingController();
  final _myIncome = TextEditingController();
  bool _newlywed = false;
  int _children = 0;
  bool _area85 = true;
  List<PolicyLoanCheck>? _policy;
  late Region _region = widget.initialRegion ?? const Region(Sido.seoul, '강남구');
  HouseStatus _status = HouseStatus.noHouse;
  RepayType _repay = RepayType.equalPayment;
  int _years = 30;
  bool _variable = true;
  LoanResult? _result;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    for (final c in [_price, _income, _existing, _rate, _desired, _netAssets, _myIncome]) {
      c.dispose();
    }
    super.dispose();
  }

  int _won(TextEditingController c) => (int.tryParse(c.text) ?? 0) * kMan;

  void _calc() {
    FocusScope.of(context).unfocus();
    final rate = (double.tryParse(_rate.text) ?? 0) / 100;
    final desired = _won(_desired);
    setState(() {
      _result = calcLoan(LoanInput(
        price: _won(_price),
        regulated: isRegulatedNow(_region),
        status: _status,
        annualIncome: _won(_income),
        existingAnnualRepay: _won(_existing),
        rate: rate,
        years: _years,
        variableRate: _variable,
        repay: _repay,
        desired: desired > 0 ? desired : null,
      ));
    });
  }

  Widget _money(String label, TextEditingController c, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: c,
        builder: (context, v, _) {
          final man = int.tryParse(v.text) ?? 0;
          return TextField(
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: label,
              suffixText: '만원',
              helperText: man > 0 ? formatKorean(man * kMan) : hint,
              border: const OutlineInputBorder(),
            ),
          );
        },
      ),
    );
  }

  void _checkPolicy() {
    FocusScope.of(context).unfocus();
    setState(() {
      _policy = checkPolicyLoans(PolicyLoanInput(
        price: _won(_price),
        householdIncome: _won(_income),
        applicantIncome: _won(_myIncome),
        netAssets: _won(_netAssets),
        status: _status,
        newlywed: _newlywed,
        children: _children,
        area85OrLess: _area85,
        regulated: isRegulatedNow(_region),
        existingAnnualRepay: _won(_existing),
      ));
    });
  }

  /// 정책대출(디딤돌·보금자리론) 대상 확인 카드
  Widget _policySection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(Icons.verified_outlined, color: cs.primary),
        title: const Text('정책대출 대상인지 확인하기', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('디딤돌대출 · 보금자리론', style: TextStyle(fontSize: 12)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('위에 입력한 집값·연소득·주택 보유 상황을 같이 써요.',
              style: TextStyle(fontSize: 12, color: cs.outline)),
          _money('부부합산 순자산', _netAssets, hint: '자산 − 부채 (예: 30000 → 3억)'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('신혼가구'),
            subtitle: const Text('혼인 7년 이내 또는 3개월 안에 결혼 예정', style: TextStyle(fontSize: 12)),
            value: _newlywed,
            onChanged: (v) => setState(() => _newlywed = v),
          ),
          if (_newlywed)
            _money('신청인 본인 연소득 (선택)', _myIncome, hint: '보금자리론 신혼 소득특례 확인용'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: DropdownButtonFormField<int>(
              key: ValueKey('kids-$_children'),
              value: _children,
              decoration:
              const InputDecoration(labelText: '미성년 자녀 수', border: OutlineInputBorder()),
              items: const [0, 1, 2, 3]
                  .map((n) => DropdownMenuItem(value: n, child: Text(n == 3 ? '3명 이상' : '$n명')))
                  .toList(),
              onChanged: (v) => setState(() => _children = v ?? 0),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('전용면적 85㎡ 이하'),
            value: _area85,
            onChanged: (v) => setState(() => _area85 = v),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: _checkPolicy, child: const Text('대상 여부 확인')),
          ),
          if (_policy != null)
            for (final p in _policy!) _PolicyResultTile(p),
          const SizedBox(height: 4),
          Text('※ 대상 여부만 간단히 확인해요. 실제 승인·금리는 주택도시기금(디딤돌), '
              '한국주택금융공사(보금자리론) 심사로 정해져요.',
              style: TextStyle(fontSize: 11, color: cs.outline)),
          const CalcBasisLink(section: BasisSection.policyLoan),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final regulated = isRegulatedNow(_region);
    final cs = Theme.of(context).colorScheme;
    final list = kSigungu[_region.sido]!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 지역
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<Sido>(
                key: ValueKey('loan-sido-${_region.sido}'),
                value: _region.sido,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '시·도', border: OutlineInputBorder()),
                items: Sido.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                    .toList(),
                onChanged: (s) {
                  if (s == null) return;
                  setState(() => _region = Region(s, kSigungu[s]!.first));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                key: ValueKey('loan-sgg-${_region.sido}-${_region.sigungu}'),
                value: list.contains(_region.sigungu) ? _region.sigungu : list.first,
                isExpanded: true,
                decoration:
                const InputDecoration(labelText: '시·군·구', border: OutlineInputBorder()),
                items: list.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (g) {
                  if (g == null) return;
                  setState(() => _region = Region(_region.sido, g));
                },
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Text(
            regulated ? '규제지역 (조정대상지역) · 수도권' : '비규제지역 · 수도권',
            style: TextStyle(fontSize: 12, color: regulated ? cs.error : cs.primary),
          ),
        ),

        // ── 집과 나
        _money('집값 (시세)', _price, hint: '예: 80000 → 8억원'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DropdownButtonFormField<HouseStatus>(
            key: ValueKey('status-$_status'),
            value: _status,
            isExpanded: true,
            decoration:
            const InputDecoration(labelText: '지금 집이 있나요?', border: OutlineInputBorder()),
            items: HouseStatus.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? HouseStatus.noHouse),
          ),
        ),
        _money('연소득 (세전)', _income, hint: '부부 합산이면 합친 금액'),
        _money('기존 대출 1년 원리금', _existing, hint: '신용대출·자동차할부 등, 없으면 비워두세요'),

        // ── 대출 조건
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _rate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(
                    labelText: '금리', suffixText: '%', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('years-$_years'),
                value: _years,
                decoration: const InputDecoration(labelText: '만기', border: OutlineInputBorder()),
                items: const [10, 15, 20, 25, 30]
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y년')))
                    .toList(),
                onChanged: (v) => setState(() => _years = v ?? 30),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DropdownButtonFormField<RepayType>(
            key: ValueKey('repay-$_repay'),
            value: _repay,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '갚는 방식', border: OutlineInputBorder()),
            items: RepayType.values
                .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                .toList(),
            onChanged: (v) => setState(() => _repay = v ?? RepayType.equalPayment),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('변동금리'),
          subtitle: const Text('끄면 고정금리 · 변동금리는 한도 계산 때 3%p를 더해요',
              style: TextStyle(fontSize: 12)),
          value: _variable,
          onChanged: (v) => setState(() => _variable = v),
        ),
        _money('희망 대출액 (선택)', _desired, hint: '비우면 최대 한도로 계산'),
        const SizedBox(height: 8),
        FilledButton(onPressed: _calc, child: const Text('대출 계산하기')),
        if (_result != null) _LoanResultView(_result!),
        const SizedBox(height: 12),
        _policySection(context),
        const SizedBox(height: 8),
        const CalcBasisLink(section: BasisSection.loan),
      ],
    );
  }
}

class _LoanResultView extends StatelessWidget {
  final LoanResult r;
  const _LoanResultView(this.r);

  Widget _row(BuildContext context, String label, String value,
      {String? memo, bool bold = false, Color? color}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
                if (memo != null)
                  Text(memo, style: TextStyle(fontSize: 12, color: cs.outline)),
              ],
            ),
          ),
          Text(value,
              style: TextStyle(fontWeight: bold ? FontWeight.bold : null, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Column(
      children: [
        // ── 한도
        Card(
          margin: const EdgeInsets.only(top: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('대출 한도', style: t.titleMedium),
                const SizedBox(height: 4),
                Text(formatKorean(r.finalLimit),
                    style: t.headlineSmall
                        ?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
                Text('한도를 정한 기준: ${r.limitedBy}',
                    style: TextStyle(fontSize: 12, color: cs.outline)),
                const Divider(height: 24),
                Text('LTV (집값 기준)', style: t.labelLarge),
                _row(context, 'LTV 비율', formatPct(r.ltvRatio)),
                _row(context, '집값 × LTV', formatWon(r.ltvAmount)),
                _row(context, '수도권 금액 상한', formatWon(r.cap), memo: '15억 이하 6억 · 25억 이하 4억 · 초과 2억'),
                _row(context, 'LTV 기준 한도', formatWon(r.ltvLimit), bold: true),
                const Divider(height: 24),
                Text('DSR (소득 기준)', style: t.labelLarge),
                _row(context, '1년에 갚을 수 있는 원리금', formatWon(r.allowedAnnual),
                    memo: '연소득 × 40% − 기존 대출'),
                _row(context, '한도 계산 금리', formatPct(r.dsrRate),
                    memo: r.stressRate > 0 ? '실제 금리 + 스트레스 ${formatPct(r.stressRate)}' : null),
                _row(context, 'DSR 기준 한도', formatWon(r.dsrLimit), bold: true),
                const Divider(height: 24),
                _row(context, '이번 대출', formatWon(r.loan), bold: true),
                _row(context, '예상 DSR', formatPct(r.dsrPercent),
                    color: r.dsrPercent > 0.4 ? cs.error : null),
              ],
            ),
          ),
        ),

        // ── 이자 비교
        Card(
          margin: const EdgeInsets.only(top: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('이자 비교 (${r.years}년 기준)', style: t.titleMedium),
                const SizedBox(height: 8),
                for (final s in r.scenarios) ...[
                  Text(s.label, style: t.labelLarge),
                  _row(context, '대출금', formatWon(s.principal)),
                  _row(context, '첫 달 상환액', formatWon(s.firstMonthly)),
                  _row(context, '총 이자', formatWon(s.totalInterest), bold: true),
                  const Divider(height: 20),
                ],
                ...r.notes.map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $n',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                )),
                const SizedBox(height: 4),
                Text('※ 모의계산 결과예요. 실제 한도와 금리는 은행 심사로 정해져요.',
                    style: TextStyle(fontSize: 11, color: cs.outline)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 정책대출 결과 한 줄
class _PolicyResultTile extends StatelessWidget {
  final PolicyLoanCheck p;
  const _PolicyResultTile(this.p);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ok = p.eligible;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ok ? cs.primary : cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.cancel_outlined,
                  size: 20, color: ok ? cs.primary : cs.outline),
              const SizedBox(width: 6),
              Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(ok ? '대상일 수 있어요' : '조건 미충족',
                  style: TextStyle(fontSize: 12, color: ok ? cs.primary : cs.error)),
            ],
          ),
          if (ok) ...[
            const SizedBox(height: 8),
            Text('예상 최대 한도 ${formatKorean(p.maxLimit)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 6),
          for (final f in p.failed)
            Text('✕ $f', style: TextStyle(fontSize: 12, color: cs.error)),
          for (final s in p.passed)
            Text('✓ $s', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text('금리: ${p.rateText}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          for (final n in p.notes)
            Text('• $n', style: TextStyle(fontSize: 11, color: cs.outline)),
        ],
      ),
    );
  }
}
