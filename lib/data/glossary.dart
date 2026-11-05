// lib/data/glossary.dart
//
// 어려운 부동산 용어 사전
// - 화면 글 속에서 여기 있는 단어(또는 aliases)가 나오면 TermText가 굵게 표시하고,
//   누르면 뜻 풀이 카드를 보여줍니다.
// - 세율·한도처럼 자주 바뀌는 숫자는 설명에 넣지 않았습니다. (계산기 화면의 기준 안내 참고)
// - 단어를 추가하려면 아래 목록에 GlossaryTerm 하나를 더 넣으면 됩니다.

enum TermCategory { redevelopment, rights, tax, loan, basic }

extension TermCategoryLabel on TermCategory {
  String get label => switch (this) {
        TermCategory.redevelopment => '정비사업',
        TermCategory.rights => '권리·분양',
        TermCategory.tax => '세금',
        TermCategory.loan => '대출·규제',
        TermCategory.basic => '기본 용어',
      };
}

class GlossaryTerm {
  final String term; // 대표 단어
  final List<String> aliases; // 같은 뜻으로 쓰는 다른 표현 (글에서 이것도 찾아 굵게 표시)
  final String short; // 한 줄 뜻
  final String detail; // 조금 더 자세한 설명
  final TermCategory category;
  final List<String> related; // 함께 보면 좋은 용어
  final bool autoLink; // false면 글 속에서 자동으로 굵게 표시하지 않음 (한 글자라 다른 단어와 겹치는 경우)

  const GlossaryTerm({
    required this.term,
    this.aliases = const [],
    required this.short,
    required this.detail,
    required this.category,
    this.related = const [],
    this.autoLink = true,
  });
}

const List<GlossaryTerm> kGlossary = [
  // ───────── 정비사업 ─────────
  GlossaryTerm(
    term: '정비구역',
    short: '낡은 동네를 새로 고치기로 법적으로 정한 구역',
    detail: '시·도나 시·군이 「도시 및 주거환경정비법」에 따라 재개발·재건축 등을 하기로 지정하고 고시한 구역이에요. '
        '지정·고시가 되어야 본격적인 사업 절차가 시작돼요.',
    category: TermCategory.redevelopment,
    related: ['재개발', '재건축', '신속통합기획'],
  ),
  GlossaryTerm(
    term: '정비사업',
    short: '낡은 주거지를 새로 정비하는 사업 전체를 부르는 말',
    detail: '재개발, 재건축, 주거환경개선사업처럼 오래된 주택이나 기반시설을 정비하는 사업을 통틀어 말해요.',
    category: TermCategory.redevelopment,
    related: ['재개발', '재건축', '주거환경개선사업'],
  ),
  GlossaryTerm(
    term: '재개발',
    aliases: ['주택정비형 재개발', '도시정비형 재개발'],
    short: '도로·상하수도 같은 기반시설까지 낡은 동네를 통째로 새로 만드는 사업',
    detail: '주택뿐 아니라 좁은 길, 부족한 주차장·공원 같은 기반시설이 열악한 지역을 대상으로 해요. '
        '주로 단독·다세대 주택이 모인 동네에서 진행돼요.',
    category: TermCategory.redevelopment,
    related: ['재건축', '정비구역'],
  ),
  GlossaryTerm(
    term: '재건축',
    short: '기반시설은 괜찮은데 오래된 아파트(건물)를 허물고 새로 짓는 사업',
    detail: '주로 오래된 아파트 단지에서 진행돼요. 재개발보다 기반시설 상태가 양호한 지역이 대상이에요.',
    category: TermCategory.redevelopment,
    related: ['재개발', '재건축진단', '재건축초과이익환수제'],
  ),
  GlossaryTerm(
    term: '주거환경개선사업',
    aliases: ['주거환경개선'],
    short: '저소득층이 많이 사는 낡은 동네의 생활환경을 개선하는 사업',
    detail: '기반시설이 매우 열악하고 노후 주택이 많은 지역에서 공공이 중심이 되어 환경을 개선해요.',
    category: TermCategory.redevelopment,
  ),
  GlossaryTerm(
    term: '재정비촉진지구',
    aliases: ['뉴타운', '재정비촉진구역'],
    short: '여러 정비구역을 묶어 넓은 범위로 함께 개발하는 지구 (흔히 "뉴타운")',
    detail: '「도시재정비 촉진을 위한 특별법」에 따라 지정돼요. 지구 안의 여러 구역이 하나의 계획 아래 정비돼요.',
    category: TermCategory.redevelopment,
  ),
  GlossaryTerm(
    term: '신속통합기획',
    aliases: ['신통기획'],
    short: '서울시가 정비계획 수립을 도와 사업 기간을 줄여주는 제도',
    detail: '서울시가 계획 단계부터 참여해 가이드라인을 제시하고 심의 절차를 통합해서, 정비구역 지정까지 걸리는 시간을 줄이는 방식이에요. '
        '"후보지 선정"은 아직 정비구역 지정 전 단계라는 뜻이에요.',
    category: TermCategory.redevelopment,
    related: ['정비구역'],
  ),
  GlossaryTerm(
    term: '추진위원회',
    aliases: ['추진위'],
    short: '조합을 만들기 전에 주민들이 꾸리는 준비 모임',
    detail: '토지등소유자 과반수의 동의를 받아 승인받아요. 조합 설립을 준비하고 정비업체 선정 등을 맡아요.',
    category: TermCategory.redevelopment,
    related: ['조합설립인가', '토지등소유자'],
  ),
  GlossaryTerm(
    term: '조합설립인가',
    aliases: ['조합설립'],
    short: '사업을 직접 진행할 조합을 정식으로 인정받는 단계',
    detail: '정해진 비율 이상의 토지등소유자 동의를 받아 조합을 만들고 구청 등의 인가를 받아요. '
        '이때부터 조합이 사업의 주체가 돼요.',
    category: TermCategory.redevelopment,
    related: ['추진위원회', '사업시행인가'],
  ),
  GlossaryTerm(
    term: '사업시행인가',
    aliases: ['사업시행'],
    short: '건물을 어떻게 지을지 구체적인 계획을 허가받는 단계',
    detail: '건물 배치, 층수, 세대수, 기반시설 계획 등을 담은 사업시행계획을 인가받아요. 건축 허가와 비슷한 단계예요.',
    category: TermCategory.redevelopment,
    related: ['조합설립인가', '관리처분인가'],
  ),
  GlossaryTerm(
    term: '관리처분인가',
    aliases: ['관리처분'],
    short: '누가 어떤 새 집을 받고 얼마를 더 낼지 정하는 단계',
    detail: '조합원 각자의 기존 재산 가치(권리가액), 새로 받을 집, 추가로 낼 돈(분담금)을 정한 계획을 인가받아요. '
        '이후 이주·철거가 시작돼요.',
    category: TermCategory.redevelopment,
    related: ['권리가액', '분담금', '이주·철거'],
  ),
  GlossaryTerm(
    term: '이주·철거',
    aliases: ['이주', '철거'],
    short: '기존 주민이 이사 나가고 낡은 건물을 허무는 단계',
    detail: '관리처분인가 뒤에 진행돼요. 조합원은 이주비 대출 등을 받아 임시 거처로 옮겨요.',
    category: TermCategory.redevelopment,
  ),
  GlossaryTerm(
    term: '착공',
    short: '새 건물 공사를 시작하는 단계',
    detail: '철거가 끝나면 착공 신고를 하고 공사를 시작해요. 보통 이 무렵 일반분양을 해요.',
    category: TermCategory.redevelopment,
    related: ['일반분양', '준공'],
  ),
  GlossaryTerm(
    term: '준공',
    short: '공사가 끝나고 입주할 수 있게 되는 단계',
    detail: '준공 인가를 받으면 입주가 시작되고, 이후 이전고시·조합 청산 절차로 사업이 마무리돼요.',
    category: TermCategory.redevelopment,
  ),
  GlossaryTerm(
    term: '재건축진단',
    aliases: ['안전진단'],
    short: '아파트가 재건축할 만큼 낡았는지 확인하는 검사',
    detail: '건물의 구조 안전성, 주거 환경 등을 평가해요. 예전에는 "안전진단"이라고 불렀어요.',
    category: TermCategory.redevelopment,
    related: ['재건축'],
  ),
  GlossaryTerm(
    term: '재건축초과이익환수제',
    aliases: ['초과이익환수'],
    short: '재건축으로 생긴 이익이 일정 수준을 넘으면 일부를 부담금으로 내는 제도',
    detail: '재건축 조합원이 얻은 집값 상승 이익 가운데 기준을 넘는 부분에 부담금을 매겨요. 기준과 비율은 법 개정에 따라 바뀌어요.',
    category: TermCategory.redevelopment,
  ),
  GlossaryTerm(
    term: '용적률',
    short: '땅 넓이에 비해 건물 전체 바닥 면적이 얼마나 되는지의 비율',
    detail: '모든 층 바닥 면적을 더해서 땅 넓이로 나눈 값이에요. 용적률이 높을수록 더 높게, 더 많은 세대를 지을 수 있어요.',
    category: TermCategory.redevelopment,
    related: ['건폐율'],
  ),
  GlossaryTerm(
    term: '건폐율',
    short: '땅 넓이에 비해 건물이 땅을 덮는 면적의 비율',
    detail: '건물을 위에서 내려다봤을 때 차지하는 면적을 땅 넓이로 나눈 값이에요. 낮을수록 공원·공터가 넓어요.',
    category: TermCategory.redevelopment,
    related: ['용적률'],
  ),

  // ───────── 권리·분양 ─────────
  GlossaryTerm(
    term: '토지등소유자',
    short: '정비구역 안의 땅이나 건물을 가진 사람',
    detail: '추진위원회·조합 설립 동의 같은 절차에서 동의 비율을 셀 때 기준이 되는 사람이에요.',
    category: TermCategory.rights,
  ),
  GlossaryTerm(
    term: '조합원입주권',
    aliases: ['입주권'],
    short: '조합원이 새 아파트에 들어갈 수 있는 권리',
    detail: '관리처분인가 이후 기존 집이 "새 집을 받을 권리"로 바뀐 것이에요. 세금에서는 주택 수에 포함되는 경우가 많아요.',
    category: TermCategory.rights,
    related: ['분양권', '관리처분인가'],
  ),
  GlossaryTerm(
    term: '분양권',
    short: '새로 짓는 아파트를 분양받아 입주할 수 있는 권리',
    detail: '일반분양에 당첨되어 계약한 사람이 갖는 권리예요. 입주권과 비슷하지만 조합원이 아닌 사람이 갖는다는 점이 달라요.',
    category: TermCategory.rights,
    related: ['조합원입주권', '일반분양'],
  ),
  GlossaryTerm(
    term: '감정평가액',
    short: '전문 감정평가사가 매긴 기존 집·땅의 가치',
    detail: '정비사업에서 조합원의 기존 재산이 얼마인지 정하는 기준이 돼요. 시세와 차이가 날 수 있어요.',
    category: TermCategory.rights,
    related: ['권리가액', '비례율'],
  ),
  GlossaryTerm(
    term: '비례율',
    short: '사업이 끝난 뒤 남는 이익을 조합원 재산에 얼마나 반영하는지의 비율',
    detail: '(사업 후 총가치 − 총사업비) ÷ 사업 전 총가치로 계산해요. 100%보다 높으면 사업성이 좋다는 뜻이에요.',
    category: TermCategory.rights,
    related: ['권리가액', '감정평가액'],
  ),
  GlossaryTerm(
    term: '권리가액',
    short: '조합원이 새 집을 받을 때 인정받는 기존 재산 가치',
    detail: '감정평가액에 비례율을 곱해서 계산해요. 권리가액이 클수록 분담금이 줄어요.',
    category: TermCategory.rights,
    related: ['감정평가액', '비례율', '분담금'],
  ),
  GlossaryTerm(
    term: '분담금',
    aliases: ['추가분담금'],
    short: '조합원이 새 집을 받기 위해 더 내야 하는 돈',
    detail: '새 집 조합원 분양가에서 권리가액을 뺀 금액이에요. 공사비가 오르면 늘어날 수 있어요.',
    category: TermCategory.rights,
    related: ['권리가액', '조합원분양'],
  ),
  GlossaryTerm(
    term: '조합원분양',
    short: '조합원에게 먼저 새 집을 나눠주는 것',
    detail: '보통 일반분양보다 싼 가격과 좋은 동·호수를 먼저 받을 수 있어요.',
    category: TermCategory.rights,
    related: ['일반분양'],
  ),
  GlossaryTerm(
    term: '일반분양',
    short: '조합원 몫을 빼고 남은 집을 일반인에게 파는 것',
    detail: '청약을 통해 분양해요. 일반분양 수입이 많을수록 조합원 분담금이 줄어들어요.',
    category: TermCategory.rights,
    related: ['조합원분양', '분양권'],
  ),
  GlossaryTerm(
    term: '현금청산',
    short: '새 집 대신 기존 재산을 돈으로 정산받는 것',
    detail: '분양 신청을 하지 않았거나 조합원 자격이 없는 경우 등에 해당돼요. 받는 금액이 기대보다 낮을 수 있어요.',
    category: TermCategory.rights,
  ),

  // ───────── 세금 ─────────
  GlossaryTerm(
    term: '취득세',
    short: '집을 살 때 한 번 내는 세금',
    detail: '집값과 보유 주택 수, 규제지역 여부에 따라 세율이 달라져요. 지방교육세 등이 함께 붙어요.',
    category: TermCategory.tax,
    related: ['조정대상지역'],
  ),
  GlossaryTerm(
    term: '재산세',
    short: '집을 가지고 있으면 매년 내는 지방세',
    detail: '매년 6월 1일에 집을 가진 사람에게 부과돼요. 공시가격을 기준으로 계산해요.',
    category: TermCategory.tax,
    related: ['공시가격', '종합부동산세'],
  ),
  GlossaryTerm(
    term: '종합부동산세',
    aliases: ['종부세'],
    short: '가진 집의 공시가격 합계가 기준을 넘으면 추가로 내는 국세',
    detail: '재산세와 별도로 매겨져요. 1세대 1주택자는 공제 금액이 더 커요.',
    category: TermCategory.tax,
    related: ['재산세', '공시가격'],
  ),
  GlossaryTerm(
    term: '양도소득세',
    aliases: ['양도세'],
    short: '집을 팔아서 생긴 이익에 내는 세금',
    detail: '판 가격에서 산 가격과 필요경비를 뺀 이익에 매겨요. 보유·거주 기간과 주택 수에 따라 크게 달라져요.',
    category: TermCategory.tax,
    related: ['장기보유특별공제', '1세대 1주택 비과세'],
  ),
  GlossaryTerm(
    term: '장기보유특별공제',
    aliases: ['장특공'],
    short: '집을 오래 가지고 있을수록 양도세 계산 때 이익을 깎아주는 제도',
    detail: '보유 기간(1주택자는 거주 기간도)에 따라 공제율이 올라가요.',
    category: TermCategory.tax,
    related: ['양도소득세'],
  ),
  GlossaryTerm(
    term: '1세대 1주택 비과세',
    aliases: ['1세대1주택', '비과세'],
    short: '한 가구가 집 한 채만 가지고 일정 조건을 채우면 양도세를 안 내는 제도',
    detail: '보유 기간 등 조건을 채워야 하고, 집값이 기준을 넘으면 넘는 부분에는 세금이 붙어요.',
    category: TermCategory.tax,
    related: ['양도소득세'],
  ),
  GlossaryTerm(
    term: '증여세',
    short: '재산을 대가 없이 받았을 때 받은 사람이 내는 세금',
    detail: '가족 관계에 따라 일정 금액까지 공제돼요. 집을 증여받으면 증여 취득세도 따로 내요.',
    category: TermCategory.tax,
  ),
  GlossaryTerm(
    term: '공시가격',
    aliases: ['공동주택가격'],
    short: '정부가 매년 발표하는 집의 공식 가격',
    detail: '재산세·종부세 같은 보유세를 계산하는 기준이에요. 보통 실제 거래 가격보다 낮아요.',
    category: TermCategory.tax,
    related: ['재산세', '종합부동산세', '실거래가'],
  ),
  GlossaryTerm(
    term: '공정시장가액비율',
    short: '보유세를 계산할 때 공시가격 중 실제로 세금을 매기는 비율',
    detail: '공시가격에 이 비율을 곱한 금액이 과세표준이 돼요. 정부가 해마다 정해요.',
    category: TermCategory.tax,
    related: ['공시가격', '재산세'],
  ),

  // ───────── 대출·규제 ─────────
  GlossaryTerm(
    term: 'LTV',
    aliases: ['주택담보인정비율'],
    short: '집값 대비 대출받을 수 있는 최대 비율',
    detail: '예를 들어 LTV 40%면 10억짜리 집으로 최대 4억까지 빌릴 수 있다는 뜻이에요. 지역과 주택 수에 따라 한도가 달라요.',
    category: TermCategory.loan,
    related: ['DSR'],
  ),
  GlossaryTerm(
    term: 'DSR',
    aliases: ['총부채원리금상환비율'],
    short: '내 연 소득 대비 1년에 갚는 모든 대출 원금·이자의 비율',
    detail: '주택담보대출뿐 아니라 신용대출, 자동차 대출 등을 모두 합쳐 계산해요. 소득이 적으면 집값과 상관없이 대출이 줄어요.',
    category: TermCategory.loan,
    related: ['LTV', '스트레스 DSR'],
  ),
  GlossaryTerm(
    term: '스트레스 DSR',
    short: '앞으로 금리가 오를 수 있다고 보고 금리를 더 높게 잡아 DSR을 계산하는 방식',
    detail: '실제 금리에 가산 금리를 더해서 계산하기 때문에 대출 한도가 그만큼 줄어요.',
    category: TermCategory.loan,
    related: ['DSR'],
  ),
  GlossaryTerm(
    term: '조정대상지역',
    short: '집값이 많이 오른 곳으로 정부가 지정한 규제 지역',
    detail: '세금(취득세·양도세 중과 등)과 대출 규제가 더 강하게 적용돼요. 지정과 해제가 자주 바뀌어요.',
    category: TermCategory.loan,
    related: ['투기과열지구', '토지거래허가구역'],
  ),
  GlossaryTerm(
    term: '투기과열지구',
    short: '조정대상지역보다 더 강한 규제를 받는 지역',
    detail: '대출, 청약, 재건축 조합원 지위 양도 등에 추가 제한이 생겨요.',
    category: TermCategory.loan,
    related: ['조정대상지역'],
  ),
  GlossaryTerm(
    term: '토지거래허가구역',
    aliases: ['토허제', '토허구역'],
    short: '일정 면적 이상 집·땅을 사려면 구청 허가를 받아야 하는 구역',
    detail: '허가를 받으면 정해진 기간 직접 살아야 하는 등 실거주 의무가 생겨요. 갭투자가 어려워요.',
    category: TermCategory.loan,
    related: ['조정대상지역'],
  ),
  GlossaryTerm(
    term: '생애최초',
    aliases: ['생애최초 주택구입'],
    short: '본인과 배우자 모두 지금까지 집을 가져본 적이 없는 경우',
    detail: '취득세 감면, 대출 한도 우대 같은 혜택을 받을 수 있어요.',
    category: TermCategory.loan,
  ),

  // ───────── 기본 용어 ─────────
  GlossaryTerm(
    term: '실거래가',
    short: '실제로 사고판 가격 (국토교통부에 신고된 금액)',
    detail: '계약 후 신고된 금액이라 신고까지 시간 차이가 있어요. 앱에서는 최근 3개월 거래를 보여줘요.',
    category: TermCategory.basic,
    related: ['공시가격'],
  ),
  GlossaryTerm(
    term: '전용면적',
    short: '현관문 안쪽, 우리 집만 쓰는 실제 면적',
    detail: '거실·방·주방·화장실 등을 포함해요. 계단·복도 같은 공용 부분은 빠져요.',
    category: TermCategory.basic,
    related: ['공급면적', '평'],
  ),
  GlossaryTerm(
    term: '공급면적',
    short: '전용면적에 계단·복도 같은 공용 면적을 더한 면적',
    detail: '아파트 광고에서 "34평" 같이 부를 때 주로 이 면적을 기준으로 해요.',
    category: TermCategory.basic,
    related: ['전용면적'],
  ),
  GlossaryTerm(
    term: '평',
    short: '넓이를 재는 옛 단위, 1평은 약 3.3㎡',
    detail: '공식 단위는 ㎡지만 생활에서는 아직 많이 써요. 앱에서는 전용면적 ㎡를 평으로 바꿔서 함께 보여줘요.',
    category: TermCategory.basic,
    related: ['전용면적'],
    autoLink: false, // '평택', '감정평가'처럼 다른 단어 속 '평'까지 잡히지 않게
  ),
];

/// 단어(대표어·다른 표현) → 용어 정보
final Map<String, GlossaryTerm> kGlossaryIndex = {
  for (final t in kGlossary) ...{
    t.term: t,
    for (final a in t.aliases) a: t,
  },
};
