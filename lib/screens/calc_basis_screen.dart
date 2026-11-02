import 'package:flutter/material.dart';

/// 계산 기준 · 근거 법령 안내 (이용약관처럼 펼쳐 보는 화면)
/// 세법·규제가 바뀌면 이 파일의 문구와 kBasisDate만 고치면 됨

const String kBasisDate = '2026년 11월 2일';

enum BasisSection { common, acquisition, transfer, right, holding, gift, loan, policyLoan }

extension BasisSectionTitle on BasisSection {
  String get title {
    switch (this) {
      case BasisSection.common:
        return '공통 안내';
      case BasisSection.acquisition:
        return '살 때 · 취득세';
      case BasisSection.transfer:
        return '팔 때 · 양도소득세 (주택)';
      case BasisSection.right:
        return '팔 때 · 조합원입주권 · 분양권';
      case BasisSection.holding:
        return '보유할 때 · 재산세 · 종합부동산세';
      case BasisSection.gift:
        return '증여할 때 · 증여세 · 증여 취득세';
      case BasisSection.loan:
        return '대출 · LTV · DSR · 이자';
      case BasisSection.policyLoan:
        return '정책대출 · 디딤돌 · 보금자리론';
    }
  }
}

/// 계산기 화면 맨 아래에 붙이는 작은 링크
class CalcBasisLink extends StatelessWidget {
  final BasisSection section;
  const CalcBasisLink({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: cs.outline,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CalcBasisScreen(initialSection: section),
        )),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 14),
            SizedBox(width: 4),
            Text(
              '계산 기준 · 근거 법령 보기',
              style: TextStyle(fontSize: 12, decoration: TextDecoration.underline),
            ),
          ],
        ),
      ),
    );
  }
}

/// 계산 기준 안내 화면
class CalcBasisScreen extends StatelessWidget {
  final BasisSection initialSection;
  const CalcBasisScreen({super.key, this.initialSection = BasisSection.common});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 누른 화면의 항목을 맨 위에 펼쳐서 보여주고, 나머지는 접어 둠
    final order = [
      initialSection,
      ...BasisSection.values.where((s) => s != initialSection),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('계산 기준 안내')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '$kBasisDate 시행 중인 법령과 정부 발표를 기준으로 만든 모의계산이에요. '
                  '실제 세금과 대출 한도는 개인 상황과 기관 심사에 따라 달라질 수 있어요.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
          for (final s in order)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                initiallyExpanded: s == initialSection,
                title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: _contentFor(s),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _contentFor(BasisSection s) {
    switch (s) {
      case BasisSection.common:
        return const [
          _H('적용 범위'),
          _B([
            '시범 지역: 서울특별시, 인천광역시, 경기도',
            '개인(1세대) 기준이에요. 법인, 임대사업자, 비거주자는 반영하지 않았어요.',
            '금액은 원 단위로 계산하고 10원 미만은 버렸어요.',
          ]),
          _H('조정대상지역 판단'),
          _B([
            '서울 25개 구 전체 (강남·서초·송파·용산은 2017.8.3부터 계속, 나머지 21개 구는 2025.10.16 재지정)',
            '경기 12곳 (2025.10.16): 과천, 광명, 성남 분당·수정·중원, 수원 영통·장안·팔달, 안양 동안, 용인 수지, 의왕, 하남',
            '경기 3곳 추가 (2026.7.1, 국토교통부공고 제2026-882호): 화성 동탄구, 용인 기흥구, 구리시',
            '인천: 현재 지정된 곳 없음',
            '서울 외 지역의 2023.1.5 이전 지정 이력은 넣지 않아서, 그 전에 산 집은 직접 확인을 받아요.',
          ]),
          _H('참고한 곳'),
          _B([
            '국가법령정보센터 (law.go.kr): 각 세법 조문',
            '국토교통부 조정대상지역 지정 공고',
            '기획재정부(재정경제부)·행정안전부 세제개편 자료, 금융위원회 가계부채 대책',
            '국세청 홈택스·위택스 안내',
            '주택도시기금(디딤돌)·한국주택금융공사(보금자리론) 상품 안내',
            '국토교통부 공동주택가격 정보 (브이월드 API)',
          ]),
          _H('주의'),
          _P('이 계산 결과는 참고용이며 법적 효력이 없어요. 실제 신고·납부 전에는 홈택스, 위택스, '
              '세무사 또는 금융기관에 꼭 확인해 주세요.'),
        ];

      case BasisSection.acquisition:
        return const [
          _Law('지방세법 제11조·제13조의2·제151조, 농어촌특별세법, 지방세특례제한법 제36조의3'),
          _H('계산 순서'),
          _N([
            '취득가액 × 세율 = 취득세',
            '생애최초 대상이면 취득세에서 최대 200만 원 감면 (지방교육세도 같은 비율로 감면)',
            '지방교육세와 농어촌특별세(전용 85㎡ 초과만)를 더해요',
          ]),
          _H('세율'),
          _T([
            ['1주택 · 6억 이하', '1%'],
            ['1주택 · 6억~9억', '(취득가 × 2/3억 − 3) ÷ 100'],
            ['1주택 · 9억 초과', '3%'],
            ['조정지역 2주택', '8% (일시적 2주택은 1~3%)'],
            ['조정지역 3주택 이상', '12%'],
            ['비조정지역 2주택', '1~3%'],
            ['비조정지역 3주택 / 4주택 이상', '8% / 12%'],
          ]),
          _H('함께 붙는 세금'),
          _T([
            ['지방교육세', '일반세율이면 취득세율의 10%, 중과면 0.4%'],
            ['농어촌특별세', '85㎡ 초과만: 일반 0.2%, 8% 중과 0.6%, 12% 중과 1.0%'],
          ]),
          _H('반영하지 않은 것과 이유'),
          _X([
            ['공시가격 1억 이하 주택 등 주택 수 제외 특례', '가진 집마다 공시가격과 종류를 하나씩 입력받아야 해서, 입력이 너무 많아져요.'],
            ['지방 미분양 주택 감면', '시범 지역(서울·인천·경기)에는 해당되지 않아요.'],
            ['입주권·분양권을 살 때', '입주권은 토지분만 취득세를 내고 준공 때 다시 내는 등 구조가 달라서, 이번엔 팔 때만 넣었어요.'],
          ]),
        ];

      case BasisSection.transfer:
        return const [
          _Law('소득세법 제55조·제89조·제95조·제104조, 같은 법 시행령 제155조·제167조의10'),
          _H('계산 순서'),
          _N([
            '양도차익 = 판 가격 − 산 가격 − 필요경비',
            '1세대 1주택 비과세 확인: 2년 이상 보유 (살 때 조정지역이었다면 2년 거주도 필요)',
            '비과세인데 판 가격이 12억을 넘으면, 12억 초과 비율만큼만 과세',
            '장기보유특별공제를 빼요',
            '기본공제 250만 원을 빼서 과세표준을 구해요',
            '세율을 곱하고, 지방소득세 10%를 더해요',
          ]),
          _H('장기보유특별공제'),
          _T([
            ['일반 (3년 이상 보유)', '1년에 2%, 최대 30%'],
            ['1세대 1주택 (3년 보유 + 2년 거주)', '보유 1년에 4% + 거주 1년에 4%, 최대 80%'],
            ['다주택 중과 대상', '공제 없음'],
          ]),
          _H('세율'),
          _T([
            ['기본세율', '6~45% 누진'],
            ['1년 미만 보유', '70%'],
            ['2년 미만 보유', '60%'],
            ['조정지역 2주택 / 3주택 이상', '기본세율 + 20%p / + 30%p'],
          ]),
          _P('단기세율과 중과세율 중 더 큰 금액을 적용해요.'),
          _H('다주택 중과 예외'),
          _B([
            '2026.5.10 양도분부터 중과가 다시 적용돼요.',
            '조정지역 지정 공고 전에 계약하고 계약금을 받은 집은 중과에서 빠져요.',
            '2026.5.9까지 계약하고 기한 안에 판 경우 중과를 피할 수 있어요 (강남·서초·송파·용산 4개월, 그 외 6개월).',
            '일시적 2주택은 중과에서 빠져요. 종전 집 처분 기한은 둘 다 조정지역이면 2년 (2026.10.1 양도분부터), 그 외 3년이에요.',
          ]),
          _H('반영하지 않은 것과 이유'),
          _X([
            ['거주주택 비과세, 상속·혼인 합가 특례', '상속일·혼인일·부모님 주택 수 등 입력이 많이 필요하고, 대부분 세무사 상담이 필요한 경우예요.'],
            ['상생임대 특례', '직전·신규 임대계약의 임대료와 기간이 필요하고, 2026년 말에 종료돼요.'],
            ['2027년부터 바뀌는 내용 (10년 거주 기본공제 2,500만 원, 중과 한시 완화 등)', '아직 시행 전이라 지금 넣으면 오늘 기준으로 틀린 결과가 나와요. 시행 때 바꿀 예정이에요.'],
            ['경기·인천의 2023년 이전 조정대상지역 이력', '지정·해제가 여러 번 바뀌어 정확한 날짜를 확보하지 못했어요. 대신 사용자에게 직접 확인받아요.'],
          ]),
        ];

      case BasisSection.right:
        return const [
          _Law('소득세법 제89조 제1항 제4호·제95조·제100조·제104조'),
          _H('조합원입주권 (원조합원)'),
          _N([
            '양도차익 = 판 가격 − 종전 주택 취득가 − 필요경비 − 낸 추가분담금',
            '관리처분 전 차익(권리가액 − 취득가)과 관리처분 후 차익(나머지)으로 나눠요',
            '관리처분계획인가일에 1주택 비과세 요건(2년 보유, 조정지역 취득이면 2년 거주)을 채웠고 팔 때 다른 집이 없으면 비과세 (12억 초과분만 과세)',
            '장기보유특별공제는 관리처분 전 차익에만, 인가일까지의 보유기간으로 적용해요',
            '기본공제 250만 원을 빼고 세율을 곱해요',
          ]),
          _H('조합원입주권 (승계 취득)'),
          _B([
            '입주권을 산 날부터 보유기간을 계산해요.',
            '아직 집이 아닌 권리라서 장기보유특별공제와 1주택 비과세가 없어요.',
          ]),
          _H('세율'),
          _T([
            ['입주권 1년 미만 / 2년 미만', '70% / 60%'],
            ['입주권 2년 이상', '기본세율 6~45% (다주택 중과 없음)'],
            ['분양권 1년 미만', '70%'],
            ['분양권 1년 이상', '60% (보유기간과 관계없이)'],
          ]),
          _H('반영하지 않은 것과 이유'),
          _X([
            ['청산금을 돌려받은 경우', '돌려받은 청산금은 종전 주택 일부를 판 것으로 보고 따로 계산해야 해요.'],
            ['사업 기간 중 대체주택 비과세 특례', '대체주택 취득·전입·처분 시기를 모두 입력받아야 해서 제외했어요.'],
            ['입주권이 있을 때 다른 집을 파는 경우의 특례', '주택 탭의 계산과 연결이 필요해서 다음 단계로 미뤘어요.'],
          ]),
        ];

      case BasisSection.holding:
        return const [
          _Law('지방세법 제110조~제112조(재산세), 종합부동산세법 제8조·제9조·제10조의2'),
          _P('매년 6월 1일에 집을 가진 사람이 그해 보유세를 내요. '
              '재산세는 7월·9월, 종합부동산세는 12월에 내요.'),
          _H('재산세 계산 순서 (이 집 1채)'),
          _N([
            '과세표준 = 공시가격 × 공정시장가액비율',
            '과세표준에 재산세율을 곱해요',
            '도시지역분(과세표준 × 0.14%)과 지방교육세(재산세 × 20%)를 더해요',
          ]),
          _T([
            ['공정시장가액비율 (1세대 1주택)', '3억 이하 43%, 6억 이하 44%, 6억 초과 45%'],
            ['공정시장가액비율 (그 외)', '60%'],
            ['표준세율', '0.1~0.4% 누진'],
            ['1주택 특례세율 (공시 9억 이하)', '0.05~0.35% 누진'],
          ]),
          _H('종합부동산세 계산 순서 (모든 집 합산)'),
          _N([
            '공시가격 합계에서 기본공제를 빼요 (1세대 1주택 12억, 그 외 9억)',
            '남은 금액 × 60% = 과세표준',
            '세율을 곱하고, 재산세와 겹치는 부분을 빼요',
            '1세대 1주택이면 고령자·장기보유 세액공제 (합산 최대 80%)',
            '농어촌특별세 20%를 더해요',
          ]),
          _T([
            ['2주택 이하 세율', '0.5~2.7%'],
            ['3주택 이상 세율', '0.5~5.0% (과세표준 12억 초과 구간부터 높아짐)'],
            ['고령자 공제', '60세 20%, 65세 30%, 70세 40%'],
            ['장기보유 공제', '5년 20%, 10년 40%, 15년 50%'],
          ]),
          _H('공시가격'),
          _B([
            '관심 단지에서 열면 국토교통부 공동주택가격 API(브이월드)로 공시가격을 불러와요.',
            '불러오지 못하면 실거래가의 약 69%(공시가격 현실화율)로 추정해요.',
          ]),
          _H('반영하지 않은 것과 이유'),
          _X([
            ['세부담 상한', '작년에 낸 재산세·종부세 금액이 필요한데, 대부분 기억하지 못해요.'],
            ['임대주택 감면, 부부 공동명의 특례', '임대 등록 정보와 지분 비율 등 따로 입력할 게 많고, 해당하는 사람이 적어요.'],
            ['재산세 중복분 공제의 정확한 값', '정식 공식은 모든 집의 재산세를 알아야 해서, 단순화한 근사치를 썼어요.'],
            ['2027년부터 바뀌는 종부세 1주택 실거주 공제', '아직 시행 전이에요.'],
          ]),
        ];

      case BasisSection.gift:
        return const [
          _Law('상속세 및 증여세법 제47조·제53조·제53조의2·제56조·제57조·제69조, 지방세법 제11조·제13조의2'),
          _H('증여세 계산 순서'),
          _N([
            '증여재산가액 + 10년 안에 같은 분께 받은 증여액',
            '관계별 증여재산공제를 빼서 과세표준을 구해요 (50만 원 미만은 과세 안 함)',
            '세율을 곱해요. 조부모→손주면 30% 할증 (미성년이고 20억 초과면 40%)',
            '예전에 낸 증여세를 빼요',
            '기한 안에 신고하면 3%를 깎아줘요 (신고세액공제)',
          ]),
          _H('증여재산공제 (10년 합산)'),
          _T([
            ['배우자', '6억'],
            ['부모·조부모 → 성년 자녀', '5천만 (혼인·출산 시 최대 1억 추가)'],
            ['부모·조부모 → 미성년 자녀', '2천만'],
            ['자녀 → 부모', '5천만'],
            ['기타 친족', '1천만'],
          ]),
          _H('증여세율'),
          _T([
            ['1억 이하', '10%'],
            ['5억 이하', '20%'],
            ['10억 이하', '30%'],
            ['30억 이하', '40%'],
            ['30억 초과', '50%'],
          ]),
          _H('주택을 받는 사람이 내는 취득세'),
          _T([
            ['일반', '3.5% + 지방교육세 0.3% (+ 85㎡ 초과 농특세 0.2%)'],
            ['조정지역 + 공시 3억 이상 + 주는 사람 2주택 이상', '12% + 지방교육세 0.4% (+ 농특세 1.0%)'],
          ]),
          _H('반영하지 않은 것과 이유'),
          _X([
            ['부담부증여 (대출·전세금을 함께 넘기는 경우)', '넘기는 빚 부분은 주는 사람의 양도세까지 따로 계산해야 해서, 별도 계산기가 필요해요.'],
            ['증여재산 평가 (감정가·유사매매사례가)', '국세청이 사례를 골라 평가하는 방식이라 앱이 대신 정할 수 없어요. 입력한 시가를 그대로 써요.'],
          ]),
        ];

      case BasisSection.loan:
        return const [
          _Law('금융위원회 가계부채 관리방안 (2025.6.27 대책, 2025.10.15 주택시장 안정화 대책), 은행업감독규정'),
          _H('계산 순서'),
          _N([
            'LTV 한도 = 집값 × LTV 비율',
            '수도권 금액 상한과 비교해서 작은 쪽 = LTV 기준 한도',
            'DSR 한도 = (연소득 × 40% − 기존 대출 1년 원리금)으로 갚을 수 있는 최대 원금',
            'LTV 기준 한도와 DSR 기준 한도 중 작은 쪽 = 최종 한도',
            '각 한도로 빌렸을 때의 월 상환액과 총 이자를 계산해요',
          ]),
          _H('LTV 비율 (수도권)'),
          _T([
            ['생애최초 구입', '70%'],
            ['무주택 · 처분조건부 1주택 (규제지역)', '40%'],
            ['무주택 · 처분조건부 1주택 (비규제지역)', '70%'],
            ['기존 집 유지 1주택 · 2주택 이상', '0% (구입 목적 대출 불가)'],
          ]),
          _H('수도권 · 규제지역 금액 상한'),
          _T([
            ['집값 15억 이하', '6억'],
            ['15억 초과 ~ 25억 이하', '4억'],
            ['25억 초과', '2억'],
          ]),
          _H('DSR'),
          _B([
            '은행 기준 40%로 계산해요 (2금융권은 50%).',
            '변동금리는 실제 금리에 스트레스 금리 3.0%p를 더해서 한도를 계산해요 (수도권·규제지역 하한).',
            '이자는 스트레스 금리 없이 실제 금리로 계산해요.',
            '만기는 수도권 최대 30년이에요.',
          ]),
          _H('상환 방식별 계산'),
          _T([
            ['원리금균등', '매달 같은 금액: 원금 × r(1+r)^n ÷ ((1+r)^n − 1)'],
            ['원금균등', '원금은 매달 같게, 이자는 남은 원금에만'],
            ['만기일시', '매달 이자만, 마지막에 원금 (DSR은 원금을 최대 10년으로 나눠 반영)'],
          ]),
          _P('r은 월 금리(연 금리 ÷ 12), n은 총 개월 수예요.'),
          _H('반영하지 않은 것과 이유'),
          _X([
            ['은행별 자체 한도', '은행마다 다르고 수시로 바뀌며, 공개된 기준이 없어요.'],
            ['방공제 (소액임차보증금 차감)', '지역·주택 종류와 보증보험 가입 여부에 따라 달라서 은행 심사 단계에서 정해져요.'],
            ['혼합형·주기형 금리의 스트레스 가산 비율', '고정 기간과 상품마다 비율이 달라서, 변동/고정으로만 나눴어요.'],
            ['생애최초 일반 주담대의 소득·주택가격 요건', '은행 상품마다 기준이 달라요. 정책대출 확인 기능에서 대표 요건을 볼 수 있어요.'],
          ]),
        ];

      case BasisSection.policyLoan:
        return const [
          _Law('주택도시기금 디딤돌대출 상품 기준, 한국주택금융공사 보금자리론 상품 기준 (2026년 10월 공시)'),
          _P('대상인지 아닌지만 빠르게 확인해요. 실제 승인과 금리는 각 기관 심사로 정해져요.'),
          _H('디딤돌대출'),
          _T([
            ['대상', '무주택 세대주'],
            ['부부합산 소득', '6천만 이하 (생애최초·2자녀 이상 7천만, 신혼 8,500만)'],
            ['순자산', '5.11억 이하 (매년 바뀜)'],
            ['집값 · 면적', '5억 이하 (신혼·2자녀 이상 6억), 전용 85㎡ 이하'],
            ['최대 한도', '2억 (생애최초 2.4억, 신혼·2자녀 이상 3.2억)'],
            ['금리', '연 2.85~4.15% (우대 전)'],
          ]),
          _H('보금자리론'),
          _T([
            ['대상', '무주택 또는 기존 집을 파는 조건의 1주택'],
            ['부부합산 소득', '7천만 이하 (신혼 8,500만, 자녀 1명 9천만, 2명 이상 1억)'],
            ['신혼 소득특례', '2026.10.19 신청분부터 본인 소득 7천만 이하면 충족'],
            ['집값', '6억 이하'],
            ['최대 한도', '3.6억 (다자녀 4억, 생애최초 4.2억)'],
            ['금리', '연 4.90~5.20%, 우대 최대 1.0%p, 규제지역 +0.2%p'],
          ]),
          _H('한도 계산'),
          _P('상품 한도, LTV 70%(수도권·규제지역), DTI 60%(30년 원리금균등 기준) 중 가장 작은 금액을 보여줘요.'),
          _H('반영하지 않은 것과 이유'),
          _X([
            ['신생아 특례 대출, 전세사기 피해자 우대', '대상이 좁고 요건이 자주 바뀌어서 이번엔 대표 상품 두 개만 넣었어요.'],
            ['우대금리 종류별 계산', '청약저축 기간·자녀·생애최초 등 조합이 많아서 범위로만 보여줘요.'],
            ['다자녀 기준', '자녀 2명 이상으로 계산했어요. 기관별 기준이 다를 수 있어 확인이 필요해요.'],
          ]),
        ];
    }
  }
}

// ───────────── 안내 문구용 작은 위젯 ─────────────

/// 소제목
class _H extends StatelessWidget {
  final String text;
  const _H(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
  );
}

/// 문단
class _P extends StatelessWidget {
  final String text;
  const _P(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(text,
        style: TextStyle(
            fontSize: 13, height: 1.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
  );
}

/// 근거 법령 표시
class _Law extends StatelessWidget {
  final String text;
  const _Law(this.text);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('근거: $text', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
    );
  }
}

/// 점 목록
class _B extends StatelessWidget {
  final List<String> items;
  const _B(this.items);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final t in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: TextStyle(fontSize: 13)),
              Expanded(child: Text(t, style: const TextStyle(fontSize: 13, height: 1.5))),
            ],
          ),
        ),
    ],
  );
}

/// 번호 목록 (계산 순서)
class _N extends StatelessWidget {
  final List<String> items;
  const _N(this.items);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (int i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text('${i + 1}.',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                  child: Text(items[i], style: const TextStyle(fontSize: 13, height: 1.5))),
            ],
          ),
        ),
    ],
  );
}

/// 2칸 표
class _T extends StatelessWidget {
  final List<List<String>> rows;
  const _T(this.rows);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(rows[i][0],
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6,
                    child: Text(rows[i][1], style: const TextStyle(fontSize: 12, height: 1.4)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 반영하지 않은 것 + 이유
class _X extends StatelessWidget {
  final List<List<String>> items; // [항목, 이유]
  const _X(this.items);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it[0], style: const TextStyle(fontSize: 13, height: 1.4)),
                      Text('이유: ${it[1]}',
                          style: TextStyle(fontSize: 11.5, height: 1.4, color: cs.outline)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
