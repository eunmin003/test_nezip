import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tax/calculator.dart';
import '../tax/region_rules.dart';
import '../tax/holding_tax.dart';
import '../tax/right_transfer_tax.dart';
import '../widgets/term_text.dart';
import 'calc_basis_screen.dart';

/// 세금 계산 시뮬레이터 (계산기 탭 > 세금 탭 안에 들어감)
/// [initialPrice]: 관심 단지 실거래가(원)
/// [initialRegion]: 관심 단지 주소의 시·도/시·군·구
class TaxSimulatorScreen extends StatelessWidget {
  final int? initialPrice;
  final Region? initialRegion;
  final int? initialOfficialPrice; // 공시가격 API로 불러온 값 (원)
  final int? officialPriceYear;
  const TaxSimulatorScreen({
    super.key,
    this.initialPrice,
    this.initialRegion,
    this.initialOfficialPrice,
    this.officialPriceYear,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '살 때'),
              Tab(text: '팔 때'),
              Tab(text: '보유할 때'),
              Tab(text: '증여할 때'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _AcquisitionForm(initialPrice: initialPrice, initialRegion: initialRegion),
                _SellTab(initialPrice: initialPrice, initialRegion: initialRegion),
                _HoldingForm(
                  initialPrice: initialPrice,
                  officialPrice: initialOfficialPrice,
                  officialYear: officialPriceYear,
                ),
                _GiftForm(initialPrice: initialPrice, initialRegion: initialRegion),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const Region _defaultRegion = Region(Sido.seoul, '강남구');

// ───────────────────── 공통 위젯 ─────────────────────
int _wonFrom(TextEditingController c) => (int.tryParse(c.text) ?? 0) * kMan;

String? _manText(int? won) => won == null ? null : (won ~/ kMan).toString();

Future<DateTime?> _pickDate(BuildContext context, DateTime initial) => showDatePicker(
  context: context,
  initialDate: initial,
  firstDate: DateTime(1980),
  lastDate: DateTime(2100),
);

class _MoneyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  const _MoneyField({required this.label, required this.controller, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, v, _) {
          final man = int.tryParse(v.text) ?? 0;
          return TextField(
            controller: controller,
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
}

class _Toggle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.title, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: TermText(title),
      subtitle: subtitle == null ? null : TermText(subtitle!, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _HouseCountField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _HouseCountField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<int>(
        key: ValueKey('houses-$value'),
        value: value,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 1, child: Text('1주택')),
          DropdownMenuItem(value: 2, child: Text('2주택')),
          DropdownMenuItem(value: 3, child: Text('3주택')),
          DropdownMenuItem(value: 4, child: Text('4주택 이상')),
        ],
        onChanged: (v) => onChanged(v ?? 1),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DateButton({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      child: Text('$label  ${date == null ? '선택' : formatDate(date!)}'),
    );
  }
}

/// 시·도 + 시·군·구 선택 + 조정대상지역 표시
class _RegionPicker extends StatelessWidget {
  final Region region;
  final ValueChanged<Region> onChanged;
  final bool? regulated;
  final String statusLabel; // 예: '오늘 기준', '취득일 기준'
  const _RegionPicker({
    required this.region,
    required this.onChanged,
    required this.regulated,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = kSigungu[region.sido]!;

    String status;
    Color color;
    if (regulated == true) {
      status = '조정대상지역이에요 ($statusLabel)';
      color = cs.error;
    } else if (regulated == false) {
      status = '비조정지역이에요 ($statusLabel)';
      color = cs.primary;
    } else {
      status = '그때 조정대상지역이었는지 확인이 필요해요';
      color = cs.outline;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<Sido>(
                  key: ValueKey('sido-${region.sido}'),
                  value: region.sido,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '시·도', border: OutlineInputBorder()),
                  items: Sido.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                      .toList(),
                  onChanged: (s) {
                    if (s == null) return;
                    onChanged(Region(s, kSigungu[s]!.first));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('sigungu-${region.sido}-${region.sigungu}'),
                  value: list.contains(region.sigungu) ? region.sigungu : list.first,
                  isExpanded: true,
                  decoration:
                  const InputDecoration(labelText: '시·군·구', border: OutlineInputBorder()),
                  items: list.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (g) {
                    if (g == null) return;
                    onChanged(Region(region.sido, g));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(regulated == true ? Icons.warning_amber_rounded : Icons.info_outline,
                  size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(child: Text(status, style: TextStyle(fontSize: 12, color: color))),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final TaxResult result;
  final List<String> extraNotes;
  const _ResultCard(this.result, {this.extraNotes = const []});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final notes = [...extraNotes, ...result.notes];
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TermText(result.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              formatWon(result.total),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            ...result.lines.map((l) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TermText(l.label,
                            style: TextStyle(
                                fontWeight: l.emphasize ? FontWeight.bold : FontWeight.normal)),
                        if (l.memo != null)
                          TermText(l.memo!, style: TextStyle(fontSize: 12, color: cs.outline)),
                      ],
                    ),
                  ),
                  Text(
                    formatWon(l.amount),
                    style: TextStyle(
                      fontWeight: l.emphasize ? FontWeight.bold : FontWeight.normal,
                      color: l.amount < 0 ? cs.error : null,
                    ),
                  ),
                ],
              ),
            )),
            if (notes.isNotEmpty) ...[
              const Divider(height: 24),
              ...notes.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: TermText('• $n', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              )),
            ],
            const SizedBox(height: 8),
            Text(
              '※ 모의계산 결과예요. 실제 신고 전에는 홈택스·위택스 또는 세무사 확인이 필요해요.',
              style: TextStyle(fontSize: 11, color: cs.outline),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════ 탭 1: 살 때 (취득세) ═════════════════════
class _AcquisitionForm extends StatefulWidget {
  final int? initialPrice;
  final Region? initialRegion;
  const _AcquisitionForm({this.initialPrice, this.initialRegion});
  @override
  State<_AcquisitionForm> createState() => _AcquisitionFormState();
}

class _AcquisitionFormState extends State<_AcquisitionForm> with AutomaticKeepAliveClientMixin {
  late final TextEditingController _price =
  TextEditingController(text: _manText(widget.initialPrice));
  late Region _region = widget.initialRegion ?? _defaultRegion;
  int _houses = 1;
  bool _over85 = false, _temp = false, _first = false;
  TaxResult? _result;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _calc() {
    FocusScope.of(context).unfocus();
    setState(() {
      _result = calcAcquisitionTax(AcquisitionInput(
        price: _wonFrom(_price),
        housesAfter: _houses,
        regulated: isRegulatedNow(_region),
        over85: _over85,
        temporaryTwo: _temp,
        firstHome: _first,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _RegionPicker(
          region: _region,
          regulated: isRegulatedNow(_region),
          statusLabel: '오늘 기준',
          onChanged: (r) => setState(() {
            _region = r;
            _result = null;
          }),
        ),
        _MoneyField(label: '매수 가격', controller: _price, hint: '예: 65000 → 6억 5천만원'),
        _HouseCountField(
            label: '사고 난 뒤 우리 가족 주택 수',
            value: _houses,
            onChanged: (v) => setState(() => _houses = v)),
        _Toggle(
            title: '전용면적 85㎡ 초과',
            value: _over85,
            onChanged: (v) => setState(() => _over85 = v)),
        if (_houses == 2)
          _Toggle(
              title: '일시적 2주택',
              subtitle: '기존 집을 기한 내 팔 예정 (조정→조정 갈아타기는 2년, 그 외 3년)',
              value: _temp,
              onChanged: (v) => setState(() => _temp = v)),
        if (_houses == 1)
          _Toggle(
              title: '생애최초 주택 구입',
              subtitle: '본인·배우자 모두 집을 가진 적 없음',
              value: _first,
              onChanged: (v) => setState(() => _first = v)),
        const SizedBox(height: 8),
        FilledButton(onPressed: _calc, child: const Text('취득세 계산하기')),
        if (_result != null)
          _ResultCard(_result!, extraNotes: ['지역: ${_region.label}']),
        const SizedBox(height: 8),
        const CalcBasisLink(section: BasisSection.acquisition),
      ],
    );
  }
}

// ═════════════════════ 탭 2: 팔 때 (양도세) ═════════════════════
class _TransferForm extends StatefulWidget {
  final int? initialPrice;
  final Region? initialRegion;
  const _TransferForm({this.initialPrice, this.initialRegion});
  @override
  State<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<_TransferForm> with AutomaticKeepAliveClientMixin {
  late final TextEditingController _sale =
  TextEditingController(text: _manText(widget.initialPrice));
  final _buy = TextEditingController();
  final _expense = TextEditingController();
  final _liveYears = TextEditingController();
  late Region _region = widget.initialRegion ?? _defaultRegion;
  DateTime? _buyDate;
  DateTime _saleDate = DateTime.now();
  DateTime? _contractDate; // 매도 계약일 (비우면 양도일과 같다고 봄)
  int _houses = 1;
  bool _temp = false;
  bool _regBuyManual = false; // 기록이 없는 과거일 때 사용자가 직접 입력
  bool _joint = false; // 공동명의 여부
  double _myShare = 50; // 본인 지분 (%) — 나머지는 배우자
  TaxResult? _result;
  List<String> _extraNotes = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _sale.dispose();
    _buy.dispose();
    _expense.dispose();
    _liveYears.dispose();
    super.dispose();
  }

  bool? get _regulatedAtBuy => _buyDate == null ? null : isRegulatedOn(_region, _buyDate!);

  void _calc() {
    FocusScope.of(context).unfocus();
    if (_buyDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('취득일을 선택해 주세요.')));
      return;
    }

    final saleCheck = checkSaleZone(_region, _saleDate, _contractDate ?? _saleDate);
    final regAtBuy = _regulatedAtBuy ?? _regBuyManual;

    final notes = <String>[
      '지역: ${_region.label}',
      '취득 당시 ${regAtBuy ? '조정대상지역' : '비조정지역'}으로 판단했어요.',
      if (_houses >= 2 && saleCheck.note != null) saleCheck.note!,
    ];

    setState(() {
      _extraNotes = notes;
      _result = calcTransferTax(TransferInput(
        salePrice: _wonFrom(_sale),
        buyPrice: _wonFrom(_buy),
        expenses: _wonFrom(_expense),
        holdMonths: monthsBetween(_buyDate!, _saleDate),
        liveMonths: (int.tryParse(_liveYears.text) ?? 0) * 12,
        houses: _houses,
        regulatedNow: saleCheck.heavyZone,
        regulatedAtBuy: regAtBuy,
        temporaryTwo: _temp,
        shares: _joint ? [_myShare / 100, (100 - _myShare) / 100] : const [1.0],
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final regAtBuy = _regulatedAtBuy;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _RegionPicker(
          region: _region,
          regulated: _buyDate == null ? isRegulatedNow(_region) : regAtBuy,
          statusLabel: _buyDate == null ? '오늘 기준' : '취득일 기준',
          onChanged: (r) => setState(() {
            _region = r;
            _result = null;
          }),
        ),
        _MoneyField(label: '파는 가격', controller: _sale),
        _MoneyField(label: '샀던 가격', controller: _buy),
        _MoneyField(label: '필요경비', controller: _expense, hint: '취득세, 중개수수료, 확장공사비 등'),
        Row(
          children: [
            Expanded(
              child: _DateButton(
                label: '취득일',
                date: _buyDate,
                onTap: () async {
                  final d = await _pickDate(context, _buyDate ?? DateTime(2018, 1, 1));
                  if (d != null) setState(() => _buyDate = d);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DateButton(
                label: '양도일',
                date: _saleDate,
                onTap: () async {
                  final d = await _pickDate(context, _saleDate);
                  if (d != null) setState(() => _saleDate = d);
                },
              ),
            ),
          ],
        ),
        if (_buyDate != null && regAtBuy == null)
          _Toggle(
              title: '살 때 조정대상지역이었나요?',
              subtitle: '2023년 이전 경기·인천 지정 이력은 직접 확인해 주세요',
              value: _regBuyManual,
              onChanged: (v) => setState(() => _regBuyManual = v)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextField(
            controller: _liveYears,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
                labelText: '실제 거주한 기간', suffixText: '년', border: OutlineInputBorder()),
          ),
        ),
        _HouseCountField(
            label: '팔 때 우리 가족 주택 수 (파는 집 포함)',
            value: _houses,
            onChanged: (v) => setState(() => _houses = v)),
        if (_houses == 2)
          _Toggle(
              title: '일시적 2주택 (갈아타기)',
              subtitle: '둘 다 조정지역이면 2년, 아니면 3년 안에 기존 집을 파는 경우',
              value: _temp,
              onChanged: (v) => setState(() => _temp = v)),
        if (_houses >= 2)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _DateButton(
              label: '매도 계약일 (선택)',
              date: _contractDate,
              onTap: () async {
                final d = await _pickDate(context, _contractDate ?? _saleDate);
                if (d != null) setState(() => _contractDate = d);
              },
            ),
          ),
        _Toggle(
            title: '공동명의 (부부 등)',
            subtitle: '지분만큼 차익을 나눠 사람마다 따로 계산해요',
            value: _joint,
            onChanged: (v) => setState(() {
                  _joint = v;
                  _result = null;
                })),
        if (_joint)
          _ShareSelector(
            myShare: _myShare,
            onChanged: (v) => setState(() {
              _myShare = v;
              _result = null;
            }),
          ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _calc, child: const Text('양도세 계산하기')),
        if (_result != null) _ResultCard(_result!, extraNotes: _extraNotes),
        const SizedBox(height: 8),
        const CalcBasisLink(section: BasisSection.transfer),
      ],
    );
  }
}

/// 공동명의 지분 고르기 (본인 : 배우자)
class _ShareSelector extends StatelessWidget {
  final double myShare; // 본인 %
  final ValueChanged<double> onChanged;
  const _ShareSelector({required this.myShare, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final me = myShare.round();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('본인 $me%', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
              const Text('  :  '),
              Text('배우자 ${100 - me}%', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: myShare,
            min: 5,
            max: 95,
            divisions: 18, // 5% 단위
            label: '본인 $me%',
            onChanged: onChanged,
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final v in const [50, 60, 70, 80])
                ChoiceChip(
                  label: Text('$v : ${100 - v}'),
                  selected: me == v,
                  onSelected: (_) => onChanged(v.toDouble()),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════ 탭 3: 증여할 때 ═════════════════════
class _GiftForm extends StatefulWidget {
  final int? initialPrice;
  final Region? initialRegion;
  const _GiftForm({this.initialPrice, this.initialRegion});
  @override
  State<_GiftForm> createState() => _GiftFormState();
}

class _GiftFormState extends State<_GiftForm> with AutomaticKeepAliveClientMixin {
  late final TextEditingController _value =
  TextEditingController(text: _manText(widget.initialPrice));
  final _prior = TextEditingController();
  final _priorTax = TextEditingController();
  late Region _region = widget.initialRegion ?? _defaultRegion;
  GiftRelation _rel = GiftRelation.ascendantToChild;
  bool _minor = false, _marriage = false, _skip = false;
  bool _housing = true, _over3 = true, _giverMulti = false, _over85 = false;
  TaxResult? _result;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _value.dispose();
    _prior.dispose();
    _priorTax.dispose();
    super.dispose();
  }

  void _calc() {
    FocusScope.of(context).unfocus();
    setState(() {
      _result = calcGiftTax(GiftInput(
        value: _wonFrom(_value),
        relation: _rel,
        recipientMinor: _minor,
        marriageBirth: _marriage,
        generationSkip: _skip,
        priorGifts: _wonFrom(_prior),
        priorGiftTax: _wonFrom(_priorTax),
        isHousing: _housing,
        regulated: isRegulatedNow(_region),
        officialOver3: _over3,
        giverMultiHome: _giverMulti,
        over85: _over85,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isAscendant = _rel == GiftRelation.ascendantToChild;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MoneyField(label: '증여하는 재산 시가', controller: _value),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DropdownButtonFormField<GiftRelation>(
            key: ValueKey('rel-$_rel'),
            value: _rel,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: '주는 사람 → 받는 사람', border: OutlineInputBorder()),
            items: GiftRelation.values
                .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                .toList(),
            onChanged: (v) => setState(() {
              _rel = v ?? GiftRelation.ascendantToChild;
              if (_rel != GiftRelation.ascendantToChild) {
                _marriage = false;
                _skip = false;
              }
            }),
          ),
        ),
        _Toggle(
            title: '받는 사람이 미성년자',
            value: _minor,
            onChanged: (v) => setState(() {
              _minor = v;
              if (v) _marriage = false;
            })),
        if (isAscendant && !_minor)
          _Toggle(
              title: '혼인·출산 증여공제',
              subtitle: '혼인신고 전후 2년 또는 출산 후 2년 이내, 최대 1억 추가',
              value: _marriage,
              onChanged: (v) => setState(() => _marriage = v)),
        if (isAscendant)
          _Toggle(
              title: '조부모 → 손주 (세대생략)',
              subtitle: '증여세 30% 할증',
              value: _skip,
              onChanged: (v) => setState(() => _skip = v)),
        _MoneyField(label: '10년 내 같은 분께 받은 증여', controller: _prior, hint: '없으면 비워두세요'),
        _MoneyField(label: '그때 낸 증여세', controller: _priorTax, hint: '없으면 비워두세요'),
        const Divider(height: 24),
        _Toggle(
            title: '주택 증여 (취득세도 함께 계산)',
            value: _housing,
            onChanged: (v) => setState(() => _housing = v)),
        if (_housing) ...[
          _RegionPicker(
            region: _region,
            regulated: isRegulatedNow(_region),
            statusLabel: '오늘 기준',
            onChanged: (r) => setState(() {
              _region = r;
              _result = null;
            }),
          ),
          _Toggle(
              title: '공시가격 3억 이상',
              value: _over3,
              onChanged: (v) => setState(() => _over3 = v)),
          _Toggle(
              title: '주는 사람이 2주택 이상',
              value: _giverMulti,
              onChanged: (v) => setState(() => _giverMulti = v)),
          _Toggle(
              title: '전용면적 85㎡ 초과',
              value: _over85,
              onChanged: (v) => setState(() => _over85 = v)),
        ],
        const SizedBox(height: 8),
        FilledButton(onPressed: _calc, child: const Text('증여세 계산하기')),
        if (_result != null)
          _ResultCard(_result!, extraNotes: [if (_housing) '지역: ${_region.label}']),
        const SizedBox(height: 8),
        const CalcBasisLink(section: BasisSection.gift),
      ],
    );
  }
}

// ═════════════════════ 탭 3: 보유할 때 (재산세·종부세) ═════════════════════
class _HoldingForm extends StatefulWidget {
  final int? initialPrice;
  final int? officialPrice; // 공시가격 API 값이 있으면 이걸 우선 사용
  final int? officialYear;
  const _HoldingForm({this.initialPrice, this.officialPrice, this.officialYear});
  @override
  State<_HoldingForm> createState() => _HoldingFormState();
}

class _HoldingFormState extends State<_HoldingForm> with AutomaticKeepAliveClientMixin {
  // 공시가격 API 값이 있으면 그대로, 없으면 실거래가의 약 69%로 추정
  late final TextEditingController _official = TextEditingController(
      text: widget.officialPrice != null
          ? (widget.officialPrice! ~/ kMan).toString()
          : (widget.initialPrice == null
          ? null
          : ((widget.initialPrice! * 0.69) ~/ kMan).toString()));
  final _others = TextEditingController();
  final _age = TextEditingController();
  final _hold = TextEditingController();
  int _houses = 1;
  bool _urban = true;
  TaxResult? _result;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _official.dispose();
    _others.dispose();
    _age.dispose();
    _hold.dispose();
    super.dispose();
  }

  void _calc() {
    FocusScope.of(context).unfocus();
    setState(() {
      _result = calcHoldingTax(HoldingInput(
        officialPrice: _wonFrom(_official),
        houses: _houses,
        otherOfficialTotal: _houses >= 2 ? _wonFrom(_others) : 0,
        age: int.tryParse(_age.text) ?? 0,
        holdYears: int.tryParse(_hold.text) ?? 0,
        urbanArea: _urban,
      ));
    });
  }

  Widget _numberField(String label, TextEditingController c, String suffix) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
            labelText: label, suffixText: suffix, border: const OutlineInputBorder()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MoneyField(
          label: '이 집 공시가격',
          controller: _official,
          hint: widget.officialPrice != null
              ? '${widget.officialYear ?? ''}년 공시가격을 불러왔어요 (국토교통부)'
              : (widget.initialPrice != null
              ? '실거래가의 약 69%로 추정했어요 · 정확한 값은 부동산공시가격알리미'
              : '부동산공시가격알리미에서 확인할 수 있어요'),
        ),
        _HouseCountField(
            label: '6월 1일 기준 우리 가족 주택 수',
            value: _houses,
            onChanged: (v) => setState(() => _houses = v)),
        if (_houses >= 2)
          _MoneyField(label: '다른 집 공시가격 합계', controller: _others),
        if (_houses == 1) ...[
          _numberField('나이', _age, '세'),
          _numberField('이 집 보유기간', _hold, '년'),
        ],
        _Toggle(
            title: '도시지역',
            subtitle: '서울·인천·경기 아파트는 대부분 도시지역이에요',
            value: _urban,
            onChanged: (v) => setState(() => _urban = v)),
        const SizedBox(height: 8),
        FilledButton(onPressed: _calc, child: const Text('보유세 계산하기')),
        if (_result != null) _ResultCard(_result!),
        const SizedBox(height: 8),
        const CalcBasisLink(section: BasisSection.holding),
      ],
    );
  }
}

// ═════════════════════ 탭 2: 팔 때 (주택 / 입주권·분양권 선택) ═════════════════════
class _SellTab extends StatefulWidget {
  final int? initialPrice;
  final Region? initialRegion;
  const _SellTab({this.initialPrice, this.initialRegion});
  @override
  State<_SellTab> createState() => _SellTabState();
}

class _SellTabState extends State<_SellTab> with AutomaticKeepAliveClientMixin {
  int _kind = 0; // 0: 주택, 1: 입주권·분양권

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('주택')),
                ButtonSegment(value: 1, label: Text('입주권 · 분양권')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _kind,
            sizing: StackFit.expand,
            children: [
              _TransferForm(initialPrice: widget.initialPrice, initialRegion: widget.initialRegion),
              _RightTransferForm(initialPrice: widget.initialPrice),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════ 팔 때: 조합원입주권 · 분양권 ═════════════════════
class _RightTransferForm extends StatefulWidget {
  final int? initialPrice;
  const _RightTransferForm({this.initialPrice});
  @override
  State<_RightTransferForm> createState() => _RightTransferFormState();
}

class _RightTransferFormState extends State<_RightTransferForm>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _sale =
  TextEditingController(text: _manText(widget.initialPrice));
  final _buy = TextEditingController();
  final _expense = TextEditingController();
  final _rightValue = TextEditingController();
  final _settlement = TextEditingController();
  final _liveYears = TextEditingController();
  RightType _type = RightType.memberOriginal;
  DateTime? _buyDate;
  DateTime? _approvalDate;
  DateTime _saleDate = DateTime.now();
  int _houses = 1;
  bool _regBuy = false;
  TaxResult? _result;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    for (final c in [_sale, _buy, _expense, _rightValue, _settlement, _liveYears]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isOriginal => _type == RightType.memberOriginal;
  bool get _isMember => _type != RightType.presale;

  void _calc() {
    FocusScope.of(context).unfocus();
    String? missing;
    if (_buyDate == null) missing = _isOriginal ? '종전 주택 취득일' : '취득일';
    if (_isOriginal && _approvalDate == null) missing = '관리처분계획인가일';
    if (missing != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$missing을 선택해 주세요.')));
      return;
    }
    setState(() {
      _result = calcRightTransferTax(RightTransferInput(
        type: _type,
        salePrice: _wonFrom(_sale),
        buyPrice: _wonFrom(_buy),
        expenses: _wonFrom(_expense),
        rightValue: _isOriginal ? _wonFrom(_rightValue) : 0,
        paidSettlement: _isMember ? _wonFrom(_settlement) : 0,
        buyDate: _buyDate!,
        saleDate: _saleDate,
        approvalDate: _approvalDate,
        liveMonths: _isOriginal ? (int.tryParse(_liveYears.text) ?? 0) * 12 : 0,
        houses: _houses,
        regulatedAtBuy: _regBuy,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DropdownButtonFormField<RightType>(
            key: ValueKey('right-$_type'),
            value: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '무엇을 파나요?', border: OutlineInputBorder()),
            items: RightType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (v) => setState(() {
              _type = v ?? RightType.memberOriginal;
              _result = null;
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: TermText(_type.help, style: TextStyle(fontSize: 12, color: cs.outline)),
        ),
        _MoneyField(label: '파는 가격', controller: _sale, hint: '프리미엄을 포함한 실제 거래 금액'),
        _MoneyField(
          label: _isOriginal ? '종전 주택을 샀던 가격' : '샀던 가격 (프리미엄 포함)',
          controller: _buy,
        ),
        _MoneyField(label: '필요경비', controller: _expense, hint: '취득세, 중개수수료 등'),
        if (_isOriginal)
          _MoneyField(
            label: '권리가액',
            controller: _rightValue,
            hint: '관리처분계획서에 적힌 종전 주택 평가액',
          ),
        if (_isMember)
          _MoneyField(label: '낸 추가분담금 (청산금)', controller: _settlement, hint: '없으면 비워두세요'),
        const SizedBox(height: 6),
        _DateButton(
          label: _isOriginal ? '종전 주택 취득일' : '취득일',
          date: _buyDate,
          onTap: () async {
            final d = await _pickDate(context, _buyDate ?? DateTime(2015, 1, 1));
            if (d != null) setState(() => _buyDate = d);
          },
        ),
        if (_isOriginal) ...[
          const SizedBox(height: 6),
          _DateButton(
            label: '관리처분계획인가일',
            date: _approvalDate,
            onTap: () async {
              final d = await _pickDate(context, _approvalDate ?? DateTime(2022, 1, 1));
              if (d != null) setState(() => _approvalDate = d);
            },
          ),
        ],
        const SizedBox(height: 6),
        _DateButton(
          label: '양도일',
          date: _saleDate,
          onTap: () async {
            final d = await _pickDate(context, _saleDate);
            if (d != null) setState(() => _saleDate = d);
          },
        ),
        if (_isOriginal) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: TextField(
              controller: _liveYears,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: '종전 주택에 실제 거주한 기간',
                  suffixText: '년',
                  border: OutlineInputBorder()),
            ),
          ),
          _HouseCountField(
              label: '팔 때 우리 가족 주택 수 (입주권 포함)',
              value: _houses,
              onChanged: (v) => setState(() => _houses = v)),
          _Toggle(
              title: '종전 주택을 살 때 조정대상지역이었음',
              subtitle: '1주택 비과세에 2년 거주 요건이 붙어요',
              value: _regBuy,
              onChanged: (v) => setState(() => _regBuy = v)),
        ],
        const SizedBox(height: 8),
        FilledButton(onPressed: _calc, child: const Text('양도세 계산하기')),
        if (_result != null) _ResultCard(_result!),
        const SizedBox(height: 8),
        const CalcBasisLink(section: BasisSection.right),
      ],
    );
  }
}
