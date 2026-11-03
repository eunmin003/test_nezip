"""
단지 목록(CSV)에 V-world 지오코더로 좌표를 붙이고, 소속 정비구역을 찾아 JSON으로 저장합니다.

  입력 CSV (UTF-8, 첫 줄 헤더):  sido,sgg,dong,jibun,name  (+ 선택: type,price,date,area,floor,buildYear,count)
      예) 서울특별시,마포구,공덕동,123-45,○○아파트
      fetch_trades.py 가 만든 CSV를 그대로 넣으면 실거래 정보까지 함께 저장됩니다.
  출력 JSON:  앱의 assets/data/complexes.json 에 넣을 단지 목록

사용법 (PowerShell, 프로젝트 폴더에서):
  $env:VWORLD_KEY="브이월드개발키"
  python tools/geocode_complexes.py 단지목록.csv assets/data/complexes.json

- 한 번 변환한 주소는 tools/geocode_cache.json 에 저장해서 다시 호출하지 않습니다.
  (API 호출 수 절약 + 중간에 끊겨도 이어서 실행 가능)
- 좌표를 못 찾은 단지는 tools/geocode_failed.csv 에 따로 모아 둡니다.
- 외부 패키지 없이 파이썬 기본 기능만 씁니다.
"""
import csv
import json
import os
import sys
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE_PATH = os.path.join(HERE, 'geocode_cache.json')
FAILED_PATH = os.path.join(HERE, 'geocode_failed.csv')
ZONES_PATH = os.path.join(HERE, '..', 'assets', 'data', 'redevelopment_zones.geojson')

API_KEY = os.environ.get('VWORLD_KEY', '')
DELAY_SEC = 0.15  # 요청 사이 간격 (너무 빠르게 보내지 않도록)


# ───────────────────────── 1. 지오코더 ─────────────────────────
def geocode(address, addr_type):
    """주소 → (경도, 위도). 실패하면 None.  addr_type: 'PARCEL'(지번) / 'ROAD'(도로명)"""
    params = {
        'service': 'address',
        'request': 'getcoord',
        'version': '2.0',
        'crs': 'epsg:4326',
        'address': address,
        'refine': 'true',
        'simple': 'false',
        'format': 'json',
        'type': addr_type,
        'key': API_KEY,
    }
    url = 'https://api.vworld.kr/req/address?' + urllib.parse.urlencode(params)
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=10) as r:
                data = json.loads(r.read().decode('utf-8'))
            res = data.get('response', {})
            status = res.get('status')
            if status == 'OK':
                p = res['result']['point']
                return float(p['x']), float(p['y'])
            if status == 'NOT_FOUND':
                return None
            # INCORRECT_KEY, 요청 한도 초과 등
            print(f'  ! V-world 오류: {status} {res.get("error")}')
            if status == 'ERROR' and 'KEY' in json.dumps(res.get('error', {})).upper():
                sys.exit('인증키 오류입니다. VWORLD_KEY 값을 확인하세요.')
        except Exception as e:  # 네트워크 일시 오류 → 잠깐 쉬고 재시도
            print(f'  ! 요청 실패({attempt + 1}/3): {e}')
            time.sleep(1.5 * (attempt + 1))
    return None

# 2026.7 인천 행정체제 개편: 주소 데이터가 옛 이름/새 이름 중 무엇을 쓰는지 달라서 둘 다 시도
RENAMED = {
    '인천광역시 서구 ': ['인천광역시 서해구 ', '인천광역시 검단구 '],
    '인천광역시 서해구 ': ['인천광역시 서구 '],
    '인천광역시 검단구 ': ['인천광역시 서구 '],
    '인천광역시 중구 ': ['인천광역시 제물포구 ', '인천광역시 영종구 '],
    '인천광역시 동구 ': ['인천광역시 제물포구 '],
    '인천광역시 제물포구 ': ['인천광역시 중구 ', '인천광역시 동구 '],
    '인천광역시 영종구 ': ['인천광역시 중구 '],
}


def address_variants(address, sido, sgg, dong, jibun):
    """원래 주소가 안 될 때 시도할 다른 표기들"""
    out = []
    for old, news in RENAMED.items():
        if address.startswith(old):
            out += [new + address[len(old):] for new in news]
    out.append(f'{sido} {dong} {jibun}')  # 마지막 수단: 구 이름 빼고 (지오코더가 동으로 찾음)
    return out
# ───────────────────────── 2. 정비구역 안에 있는지 ─────────────────────────

def point_in_ring(x, y, ring):
    inside = False
    j = len(ring) - 1
    for i in range(len(ring)):
        xi, yi = ring[i]
        xj, yj = ring[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def load_zones():
    with open(ZONES_PATH, encoding='utf-8') as f:
        features = json.load(f)['features']
    zones = []
    for f in features:
        g = f['geometry']
        polys = [g['coordinates']] if g['type'] == 'Polygon' else g['coordinates']
        xs = [c[0] for poly in polys for c in poly[0]]
        ys = [c[1] for poly in polys for c in poly[0]]
        zones.append({'props': f['properties'], 'polys': polys,
                      'bbox': (min(xs), min(ys), max(xs), max(ys))})
    return zones


def find_zone(x, y, zones):
    for z in zones:
        x0, y0, x1, y1 = z['bbox']
        if not (x0 <= x <= x1 and y0 <= y <= y1):
            continue
        for poly in z['polys']:
            outer, holes = poly[0], poly[1:]
            if point_in_ring(x, y, outer) and not any(point_in_ring(x, y, h) for h in holes):
                return z['props']
    return None


# ───────────────────────── 3. 실행 ─────────────────────────
def main(in_csv, out_json):
    if not API_KEY:
        sys.exit('VWORLD_KEY 환경변수가 비어 있습니다.  $env:VWORLD_KEY="키"  를 먼저 실행하세요.')

    cache = {}
    if os.path.exists(CACHE_PATH):
        with open(CACHE_PATH, encoding='utf-8') as f:
            cache = json.load(f)

    zones = load_zones()
    with open(in_csv, encoding='utf-8-sig') as f:
        rows = list(csv.DictReader(f))

    out, failed, seen = [], [], set()
    for n, r in enumerate(rows, 1):
        sido, sgg, dong = r['sido'].strip(), r['sgg'].strip(), r['dong'].strip()
        jibun, name = r['jibun'].strip(), r['name'].strip()
        key = f'{sido}|{sgg}|{dong}|{jibun}|{name}'  # 단지 구분 키
        if key in seen:
            continue
        seen.add(key)

        address = f'{sido} {sgg} {dong} {jibun}'

        def lookup(addr):
            if addr not in cache:
                cache[addr] = geocode(addr, 'PARCEL')
                time.sleep(DELAY_SEC)
            return cache[addr]

        pt = lookup(address)
        if not pt:  # 실패하면 바뀐 구 이름 등 다른 표기로 다시 시도
            for alt in address_variants(address, sido, sgg, dong, jibun):
                pt = lookup(alt)
                if pt:
                    break
        if n % 20 == 0:  # 중간 저장
            with open(CACHE_PATH, 'w', encoding='utf-8') as f:
                json.dump(cache, f, ensure_ascii=False)

        if not pt:
            failed.append(r)
            print(f'[{n}/{len(rows)}] 실패  {address} {name}')
            continue

        lng, lat = pt
        zone = find_zone(lng, lat, zones)
        item = {
            'id': key,
            'name': name,
            'address': address,
            'lat': round(lat, 6),
            'lng': round(lng, 6),
            'zoneId': zone['id'] if zone else None,
            'zoneName': zone['name'] if zone else None,
            'zoneStage': zone.get('stage') if zone else None,
        }
        # fetch_trades.py 가 만든 실거래 정보가 있으면 함께 담기
        for col, conv in (('type', str), ('price', int), ('date', str), ('area', float),
                          ('floor', str), ('buildYear', str), ('count', int)):
            v = (r.get(col) or '').strip()
            if v:
                try:
                    item[col] = conv(v)
                except ValueError:
                    item[col] = v
        out.append(item)
        print(f'[{n}/{len(rows)}] OK    {name} → ({lat:.5f}, {lng:.5f})'
              + (f'  · {zone["name"]}' if zone else ''))

    with open(CACHE_PATH, 'w', encoding='utf-8') as f:
        json.dump(cache, f, ensure_ascii=False)
    with open(out_json, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    if failed:
        with open(FAILED_PATH, 'w', encoding='utf-8-sig', newline='') as f:
            w = csv.DictWriter(f, fieldnames=list(failed[0].keys()))
            w.writeheader()
            w.writerows(failed)

    in_zone = sum(1 for c in out if c['zoneId'])
    print(f'\n완료: 성공 {len(out)}개 (정비구역 안 {in_zone}개), 실패 {len(failed)}개')
    print(f'결과: {out_json}')
    if failed:
        print(f'실패 목록: {FAILED_PATH}  (주소 표기를 고쳐서 다시 실행하면 돼요)')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
