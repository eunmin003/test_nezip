"""
공공데이터포털 실거래가 API에서 최근 거래를 받아 '단지 목록 CSV'를 만듭니다.
(다음 단계 geocode_complexes.py 의 입력으로 그대로 씁니다)

  대상: 아파트 매매 + 연립다세대 매매
  결과: 단지마다 한 줄 (가장 최근 거래 1건 + 기간 내 거래 수)

사용법 (PowerShell, 프로젝트 폴더에서):
  $env:DATA_GO_KR_KEY="공공데이터포털_Decoding키"          # 키가 하나일 때
  (아파트·연립다세대 키가 서로 다르면 아래 두 줄로 따로 넣기)
  $env:DATA_GO_KR_KEY_APT="아파트_Decoding키"
  $env:DATA_GO_KR_KEY_RH="연립다세대_Decoding키"
  python tools/fetch_trades.py tools/complexes_raw.csv                 # 서울 25개 구, 최근 6개월
  python tools/fetch_trades.py tools/complexes_raw.csv --months 3 --gu 11440,11170,11200
                                                                       # 마포·용산·성동만, 최근 3개월
  python tools/fetch_trades.py tools/complexes_raw.csv --months 3 --zones-only
                                                                       # 정비구역 있는 서울·인천·경기 시군구 전체

- 외부 패키지 없이 파이썬 기본 기능만 씁니다.
- 받은 원본 응답은 tools/trade_cache/ 에 저장해서, 다시 실행하면 API를 또 부르지 않습니다.
"""
import argparse
import csv
import datetime as dt
import os
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE_DIR = os.path.join(HERE, 'trade_cache')
COMMON_KEY = os.environ.get('DATA_GO_KR_KEY', '')

# 공공데이터포털에서 '활용신청'한 API 주소
APIS = {
    '아파트': {
        'url': 'https://apis.data.go.kr/1613000/RTMSDataSvcAptTrade/getRTMSDataSvcAptTrade',
        'name_field': 'aptNm',
        'key': os.environ.get('DATA_GO_KR_KEY_APT') or COMMON_KEY,
    },
    '연립다세대': {
        'url': 'https://apis.data.go.kr/1613000/RTMSDataSvcRHTrade2/getRTMSDataSvcRHTrade2',
        'name_field': 'mhouseNm',
        'key': os.environ.get('DATA_GO_KR_KEY_RH') or COMMON_KEY,
    },
}

SEOUL_GU = {
    '11110': '종로구', '11140': '중구', '11170': '용산구', '11200': '성동구', '11215': '광진구',
    '11230': '동대문구', '11260': '중랑구', '11290': '성북구', '11305': '강북구', '11320': '도봉구',
    '11350': '노원구', '11380': '은평구', '11410': '서대문구', '11440': '마포구', '11470': '양천구',
    '11500': '강서구', '11530': '구로구', '11545': '금천구', '11560': '영등포구', '11590': '동작구',
    '11620': '관악구', '11650': '서초구', '11680': '강남구', '11710': '송파구', '11740': '강동구',
}
INCHEON_GU = {  # 2026.7 행정체제 개편 반영 (정비구역 파일 기준 코드)
    '28125': '제물포구', '28177': '미추홀구', '28185': '연수구', '28200': '남동구', '28237': '부평구',
    '28245': '계양구', '28275': '서해구', '28710': '강화군', '28720': '옹진군',
}
GYEONGGI = {
    '41111': '수원시 장안구', '41113': '수원시 권선구', '41115': '수원시 팔달구', '41117': '수원시 영통구',
    '41131': '성남시 수정구', '41133': '성남시 중원구', '41135': '성남시 분당구',
    '41150': '의정부시', '41171': '안양시 만안구', '41173': '안양시 동안구',
    '41192': '부천시 원미구', '41194': '부천시 소사구', '41196': '부천시 오정구',
    '41210': '광명시', '41220': '평택시', '41250': '동두천시',
    '41271': '안산시 상록구', '41273': '안산시 단원구',
    '41281': '고양시 덕양구', '41285': '고양시 일산동구', '41287': '고양시 일산서구',
    '41290': '과천시', '41310': '구리시', '41360': '남양주시', '41370': '오산시', '41390': '시흥시',
    '41410': '군포시', '41430': '의왕시', '41450': '하남시',
    '41461': '용인시 처인구', '41463': '용인시 기흥구', '41465': '용인시 수지구',
    '41480': '파주시', '41500': '이천시', '41550': '안성시', '41570': '김포시',
}
SGG_NAMES = {**SEOUL_GU, **INCHEON_GU, **GYEONGGI}
SIDO_NAMES = {'11': '서울특별시', '28': '인천광역시', '41': '경기도'}

# 정비구역 파일은 구가 있는 시를 '시' 코드로 적어 둠 → 실거래 API는 '구' 코드로 조회해야 함
CITY_TO_GU = {
    '41110': ['41111', '41113', '41115', '41117'],
    '41130': ['41131', '41133', '41135'],
    '41170': ['41171', '41173'],
    '41190': ['41192', '41194', '41196'],
    '41270': ['41271', '41273'],
    '41280': ['41281', '41285', '41287'],
    '41460': ['41461', '41463', '41465'],
}
ZONES_PATH = os.path.join(HERE, '..', 'assets', 'data', 'redevelopment_zones.geojson')


def zone_sgg_codes():
    """정비구역이 하나라도 있는 시군구 코드 목록 (실거래 API 조회용)"""
    import json
    with open(ZONES_PATH, encoding='utf-8') as f:
        codes = {ft['properties'].get('sggCode', '') for ft in json.load(f)['features']}
    out = []
    for c in sorted(c for c in codes if c):
        out.extend(CITY_TO_GU.get(c, [c]))
    return out


def recent_months(n):
    """최근 n개월의 'YYYYMM' 목록 (이번 달 포함)"""
    today = dt.date.today()
    y, m = today.year, today.month
    out = []
    for _ in range(n):
        out.append(f'{y}{m:02d}')
        m -= 1
        if m == 0:
            y, m = y - 1, 12
    return out


def fetch_xml(api, lawd_cd, ymd):
    """한 구 × 한 달 응답(XML 문자열). 캐시가 있으면 캐시 사용. (이번 달은 매번 새로 받음)"""
    os.makedirs(CACHE_DIR, exist_ok=True)
    cache = os.path.join(CACHE_DIR, f'{api}_{lawd_cd}_{ymd}.xml')
    this_month = dt.date.today().strftime('%Y%m')
    if os.path.exists(cache) and ymd != this_month:
        with open(cache, encoding='utf-8') as f:
            return f.read()

    pages, page = [], 1
    while True:
        params = urllib.parse.urlencode({
            'serviceKey': APIS[api]['key'], 'LAWD_CD': lawd_cd, 'DEAL_YMD': ymd,
            'numOfRows': 1000, 'pageNo': page,
        })
        text = None
        for attempt in range(3):
            try:
                with urllib.request.urlopen(f'{APIS[api]["url"]}?{params}', timeout=20) as r:
                    text = r.read().decode('utf-8')
                break
            except Exception as e:
                print(f'  ! 요청 실패({attempt + 1}/3): {e}')
                time.sleep(2 * (attempt + 1))
        if text is None:
            return None
        check_error(text)
        pages.append(text)
        root = ET.fromstring(text)
        total = int(root.findtext('.//totalCount') or 0)
        if page * 1000 >= total:
            break
        page += 1
        time.sleep(0.2)

    joined = '\n<!--PAGE-->\n'.join(pages)
    with open(cache, 'w', encoding='utf-8') as f:
        f.write(joined)
    return joined


def check_error(text):
    """인증키 오류 등은 바로 멈추고 이유를 보여줌"""
    if '<resultCode>' in text:
        root = ET.fromstring(text)
        code = (root.findtext('.//resultCode') or '').strip()
        if code not in ('', '00', '000'):
            msg = root.findtext('.//resultMsg')
            sys.exit(f'API 오류 {code}: {msg}\n(신청 직후라면 키가 활성화될 때까지 조금 기다렸다가 다시 실행하세요)')
    if 'SERVICE_KEY_IS_NOT_REGISTERED' in text or 'SERVICE KEY IS NOT REGISTERED' in text:
        sys.exit('등록되지 않은 인증키입니다. Decoding 키를 넣었는지, 활용신청이 승인됐는지 확인하세요.')


def parse_items(xml_text, api):
    name_field = APIS[api]['name_field']
    for part in xml_text.split('<!--PAGE-->'):
        part = part.strip()
        if not part:
            continue
        for it in ET.fromstring(part).iter('item'):
            g = lambda k: (it.findtext(k) or '').strip()
            if g('cdealType'):  # 해제된 거래(계약 취소)는 제외
                continue
            price = g('dealAmount').replace(',', '')
            if not price.isdigit():
                continue
            yield {
                'type': api,
                'sggCd': g('sggCd'),
                'dong': g('umdNm'),
                'jibun': g('jibun'),
                'name': g(name_field),
                'price': int(price),  # 만원
                'date': f'{g("dealYear")}-{int(g("dealMonth") or 0):02d}-{int(g("dealDay") or 0):02d}',
                'area': g('excluUseAr'),
                'floor': g('floor'),
                'buildYear': g('buildYear'),
            }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out_csv')
    ap.add_argument('--months', type=int, default=6)
    ap.add_argument('--gu', default='', help='시군구코드 5자리, 쉼표로 구분 (생략하면 서울 25개 구)')
    ap.add_argument('--zones-only', action='store_true',
                    help='정비구역이 있는 서울·인천·경기 시군구 전체를 자동으로 조회')
    args = ap.parse_args()

    for name, a in APIS.items():
        if not a['key']:
            sys.exit(f'{name} API 키가 비어 있습니다.  $env:DATA_GO_KR_KEY="Decoding키"  를 먼저 실행하세요.')
        if '%' in a['key']:
            sys.exit(f'{name} 키에 %가 들어 있어요. Encoding 키 말고 Decoding 키를 넣어 주세요.')

    if args.zones_only:
        gus = zone_sgg_codes()
        print(f'정비구역이 있는 시군구 {len(gus)}곳을 조회합니다.')
    elif args.gu:
        gus = [g.strip() for g in args.gu.split(',') if g.strip()]
    else:
        gus = list(SEOUL_GU)
    months = recent_months(args.months)
    complexes = {}  # 단지 키 → 정보
    total_deals = 0

    for gu in gus:
        for api in APIS:
            for ymd in months:
                xml_text = fetch_xml(api, gu, ymd)
                if xml_text is None:
                    print(f'  ! {gu} {api} {ymd} 건너뜀')
                    continue
                n = 0
                for d in parse_items(xml_text, api):
                    n += 1
                    if not d['name'] or not d['jibun']:
                        continue
                    key = (gu, d['dong'], d['jibun'], d['name'])
                    c = complexes.get(key)
                    if c is None:
                        complexes[key] = {**d, 'count': 1}
                    else:
                        c['count'] += 1
                        if d['date'] > c['date']:  # 더 최근 거래로 교체
                            c.update({k: d[k] for k in ('price', 'date', 'area', 'floor')})
                total_deals += n
                print(f'{SGG_NAMES.get(gu, gu)} {api} {ymd}: {n}건')
                time.sleep(0.2)

    with open(args.out_csv, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.writer(f)
        w.writerow(['sido', 'sgg', 'dong', 'jibun', 'name',
                    'type', 'price', 'date', 'area', 'floor', 'buildYear', 'count'])
        for (gu, dong, jibun, name), c in sorted(complexes.items()):
            w.writerow([SIDO_NAMES.get(gu[:2], ''), SGG_NAMES.get(gu, ''), dong, jibun, name,
                        c['type'], c['price'], c['date'], c['area'], c['floor'], c['buildYear'], c['count']])

    print(f'\n완료: 거래 {total_deals}건 → 단지 {len(complexes)}개')
    print(f'결과: {args.out_csv}')
    print('다음: python tools/geocode_complexes.py', args.out_csv, 'assets/data/complexes.json')


if __name__ == '__main__':
    main()
