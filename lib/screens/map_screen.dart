import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../models/favorite_complex.dart';
import '../models/redev_zone.dart';
import '../services/complex_repository.dart';
import '../tax/calculator.dart' show formatKorean;
import '../widgets/term_text.dart';
import 'glossary_screen.dart';
import '../services/vworld_services.dart';
import '../services/zone_repository.dart';

/// ① 홈 탭: 도시정비사업 지도
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  NaverMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  /// 이미 지도에 올린 구역 id (같은 구역을 두 번 올리지 않도록)
  final Set<String> _shownZoneIds = {};

  /// 이 줌보다 멀리서 보면 구역을 새로 그리지 않음 (너무 많아져서 느려지는 것 방지)
  static const double _minZoomForZones = 11;

  // ── 실거래가 마커 ──
  /// 이 줌 이상에서만 실거래가 마커를 보여줌 (동네 단위로 확대했을 때)
  static const double _minZoomForTrades = 15;

  /// 이미 지도에 올린 단지 마커 id
  final Set<String> _shownComplexIds = {};
  bool _showTrades = true; // 상단 [실거래가] 칩으로 켜고 끄기
  bool _loadingTrades = false;
  double _zoom = 13;
  NOverlayImage? _aptIcon; // 아파트 마커 점 (파랑)
  NOverlayImage? _villaIcon; // 연립다세대 마커 점 (청록)

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('도시정비사업 구역 지도'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: '용어 사전',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GlossaryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '다시 그리기',
            onPressed: _reloadZones,
          ),
        ],
      ),
      body: Stack(
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(37.5665, 126.9780), // 서울시청
                zoom: 13,
              ),
              locationButtonEnable: true,
            ),
            onMapReady: (controller) {
              setState(() => _mapController = controller);
              ComplexRepository.preload(); // 단지 실거래 데이터 미리 읽기
              _loadZonesInCurrentBounds();
            },
            // 지도 이동이 멈추면 새로 보이는 구역·실거래가를 추가로 그림
            onCameraIdle: _onCameraIdle,
          ),

          // 상단 검색창
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: '지역명 또는 장소 검색 (예: 공덕역)',
                          border: InputBorder.none,
                        ),
                        onSubmitted: _searchAndMoveLocation,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () =>
                          _searchAndMoveLocation(_searchController.text),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 검색창 아래: 실거래가 켜기/끄기 + 안내
          Positioned(
            top: 76,
            left: 16,
            right: 16,
            child: Row(
              children: [
                FilterChip(
                  avatar: const Icon(Icons.sell_outlined, size: 16),
                  label: const Text('실거래가'),
                  selected: _showTrades,
                  showCheckmark: false,
                  backgroundColor: Colors.white,
                  elevation: 2,
                  onSelected: _toggleTrades,
                ),
                const SizedBox(width: 8),
                if (_showTrades)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: _zoom < _minZoomForTrades
                          ? const Text('지도를 더 확대하면 실거래가가 보여요',
                              style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)
                          : const _TradeLegend(),
                    ),
                  ),
              ],
            ),
          ),
          // 오른쪽 아래 확대·축소 버튼
          if (_mapController != null)
            Positioned(
              right: 12,
              bottom: 24,
              child: NaverMapZoomControlWidget(mapController: _mapController!),
            ),
          // 왼쪽 아래 범례
          const Positioned(left: 12, bottom: 16, child: _StageLegend()),

          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  /// 오버레이를 모두 지우고 다시 그리기
  Future<void> _reloadZones() async {
    if (_mapController == null) return;
    await _mapController!.clearOverlays(type: NOverlayType.polygonOverlay);
    await _mapController!.clearOverlays(type: NOverlayType.marker);
    _shownZoneIds.clear();
    _shownComplexIds.clear();
    await _loadZonesInCurrentBounds();
    await _loadTradeMarkers();
  }

  /// 지도 이동이 멈췄을 때
  Future<void> _onCameraIdle() async {
    if (_mapController == null) return;
    final zoom = (await _mapController!.getCameraPosition()).zoom;
    if (mounted && (zoom < _minZoomForTrades) != (_zoom < _minZoomForTrades)) {
      setState(() => _zoom = zoom); // 안내 문구 바꾸기
    } else {
      _zoom = zoom;
    }
    await _loadZonesInCurrentBounds();
    await _loadTradeMarkers();
  }

  /// [실거래가] 칩 켜기/끄기
  Future<void> _toggleTrades(bool on) async {
    setState(() => _showTrades = on);
    if (_mapController == null) return;
    if (on) {
      await _loadTradeMarkers();
    } else {
      await _mapController!.clearOverlays(type: NOverlayType.marker);
      _shownComplexIds.clear();
    }
  }

  /// 마커 점 아이콘 (한 번만 만들어서 모든 마커에 재사용)
  Future<void> _ensureTradeIcons() async {
    if (_aptIcon != null && _villaIcon != null) return;
    final primary = Theme.of(context).colorScheme.primary;
    Widget dot(Color c) => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
          ),
        );
    _aptIcon = await NOverlayImage.fromWidget(
        widget: dot(primary), size: const Size(14, 14), context: context);
    if (!mounted) return;
    _villaIcon = await NOverlayImage.fromWidget(
        widget: dot(Colors.teal), size: const Size(14, 14), context: context);
  }

  /// 화면 안 단지에 실거래가 마커 그리기 (줌 15 이상, 이미 그린 단지는 건너뜀)
  Future<void> _loadTradeMarkers() async {
    if (_mapController == null || !_showTrades || _loadingTrades) return;
    if (_zoom < _minZoomForTrades) return;

    _loadingTrades = true;
    try {
      await _ensureTradeIcons();
      if (!mounted) return;
      final primary = Theme.of(context).colorScheme.primary;

      // 너무 많이 쌓이면 한 번 비우고 다시 (앱이 느려지지 않게)
      if (_shownComplexIds.length > 1500) {
        await _mapController!.clearOverlays(type: NOverlayType.marker);
        _shownComplexIds.clear();
      }

      final bounds = await _mapController!.getContentBounds();
      final complexes = await ComplexRepository.inBounds(bounds, limit: 300);

      final markers = <NAddableOverlay>{};
      for (final c in complexes) {
        final markerId = 'trade_${c.id}';
        if (_shownComplexIds.contains(markerId)) continue;

        final marker = NMarker(
          id: markerId,
          position: NLatLng(c.lat, c.lng),
          icon: c.isApartment ? _aptIcon : _villaIcon,
          size: const Size(14, 14),
          anchor: const NPoint(0.5, 0.5),
          caption: NOverlayCaption(
            text: _shortPrice(c.priceWon),
            textSize: 12,
            color: c.isApartment ? primary : Colors.teal.shade700,
            haloColor: Colors.white,
          ),
          captionAligns: const [NAlign.top],
          isHideCollidedCaptions: true, // 겹치는 가격 글자는 숨김
        );
        marker.setMinZoom(_minZoomForTrades); // 축소하면 지도에서 자동으로 숨김
        marker.setOnTapListener((_) => _showComplexSheet(c));
        markers.add(marker);
        _shownComplexIds.add(markerId);
      }

      if (markers.isNotEmpty) await _mapController!.addOverlayAll(markers);
      debugPrint('[실거래] 화면 안 ${complexes.length}개, 새로 그림 ${markers.length}개');
    } catch (e, st) {
      debugPrint('[실거래] 마커 그리기 오류: $e\n$st');
    } finally {
      _loadingTrades = false;
    }
  }

  /// 마커에 쓰는 짧은 가격 (예: 9.8억, 12억, 4500만)
  static String _shortPrice(int won) {
    if (won >= 100000000) {
      final eok = won / 100000000;
      final s = eok >= 10 ? eok.toStringAsFixed(0) : eok.toStringAsFixed(1);
      return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}억';
    }
    return '${won ~/ 10000}만';
  }

  /// 마커를 눌렀을 때: 단지 정보 + 소속 정비구역 + ♡
  void _showComplexSheet(ComplexInfo c) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ComplexTile(c),
                const Divider(height: 20),
                Row(
                  children: [
                    Icon(Icons.location_city_outlined, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        c.zoneId == null
                            ? '정비구역 밖 단지예요'
                            : '${c.zoneName == null || c.zoneName == '정비구역' ? '정비구역 안' : c.zoneName}'
                                '${c.zoneStage != null ? ' · ${c.zoneStage}' : ''}',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(c.address, style: textTheme.bodySmall?.copyWith(color: Colors.grey[700])),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 현재 화면 안의 정비구역을 지도에 그리기 (이미 그린 구역은 건너뜀)
  Future<void> _loadZonesInCurrentBounds() async {
    if (_mapController == null || _isLoading) return;

    final camera = await _mapController!.getCameraPosition();
    if (camera.zoom < _minZoomForZones) return;

    setState(() => _isLoading = true);
    try {
      final bounds = await _mapController!.getContentBounds();
      final zones = await ZoneRepository.zonesIn(bounds);

      final newOverlays = <NAddableOverlay>{};
      for (final zone in zones) {
        for (var i = 0; i < zone.rings.length; i++) {
          final overlayId = '${zone.id}_$i';
          if (_shownZoneIds.contains(overlayId)) continue;

          final ring = zone.rings[i];
          final polygon = NPolygonOverlay(
            id: overlayId,
            coords: ring.outer,
            holes: ring.holes,
            color: zone.color.withValues(alpha: 0.35),
            outlineColor: zone.color,
            outlineWidth: 2,
          );
          polygon.setOnTapListener((_) => _showZoneSheet(zone));
          newOverlays.add(polygon);
          _shownZoneIds.add(overlayId);
        }
      }

      if (newOverlays.isNotEmpty) {
        await _mapController!.addOverlayAll(newOverlays);
      }
      debugPrint('[ZONE] 화면 안 ${zones.length}개, 새로 그림 ${newOverlays.length}개');
    } catch (e, st) {
      debugPrint('[ZONE] 구역 그리기 오류: $e\n$st');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 구역을 눌렀을 때 하단 정보 카드
  void _showZoneSheet(RedevZone zone) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 위로 끌어올리면 목록이 길어지게
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        builder: (context, scrollController) =>
            _ZoneInfoSheet(zone: zone, scrollController: scrollController),
      ),
    );
  }

  /// 장소 검색 후 카메라 이동
  Future<void> _searchAndMoveLocation(String query) async {
    if (query.trim().isEmpty || _mapController == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    final NLatLng? searchResult = await VworldService.searchLocation(query);
    if (mounted) setState(() => _isLoading = false);

    if (searchResult != null) {
      await _mapController!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: searchResult, zoom: 15),
      );
      // 카메라가 멈추면 onCameraIdle에서 구역을 그림
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검색 결과를 찾을 수 없습니다.')),
      );
    }
  }
}

/// 구역 정보 카드 + 이 구역 단지 최근 실거래 목록
class _ZoneInfoSheet extends StatefulWidget {
  final RedevZone zone;
  final ScrollController scrollController;

  const _ZoneInfoSheet({required this.zone, required this.scrollController});

  @override
  State<_ZoneInfoSheet> createState() => _ZoneInfoSheetState();
}

enum _SortBy { recent, priceHigh, priceLow }

class _ZoneInfoSheetState extends State<_ZoneInfoSheet> {
  late final Future<List<ComplexInfo>> _complexes =
      ComplexRepository.inZone(widget.zone.id);
  _SortBy _sort = _SortBy.recent;

  List<ComplexInfo> _sorted(List<ComplexInfo> list) {
    final l = [...list];
    switch (_sort) {
      case _SortBy.recent:
        l.sort((a, b) => b.dealDate.compareTo(a.dealDate));
      case _SortBy.priceHigh:
        l.sort((a, b) => b.priceWon.compareTo(a.priceWon));
      case _SortBy.priceLow:
        l.sort((a, b) => a.priceWon.compareTo(b.priceWon));
    }
    return l;
  }

  @override
  Widget build(BuildContext context) {
    final zone = widget.zone;
    final textTheme = Theme.of(context).textTheme;
    final location = [zone.sido, zone.sgg].where((s) => s.isNotEmpty).join(' ');

    return FutureBuilder<List<ComplexInfo>>(
      future: _complexes,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final items = _sorted(snap.data ?? const []);

        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            // ── 구역 정보 ──
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: zone.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    zone.hasName ? zone.name : '정비구역 (구역명 미기재)',
                    style: textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(location, style: textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip(zone.bizType ?? zone.type),
                _chip(zone.stage ?? '단계 정보 없음', color: zone.color),
                if (zone.households != null && zone.households != 0)
                  _chip('예정 ${zone.households}세대'),
                if (zone.noticeDate.isNotEmpty) _chip('고시 ${zone.noticeDate}'),
                if (zone.executor != null) _chip('시행 ${zone.executor}'),
              ],
            ),
            const Divider(height: 28),

            // ── 이 구역 최근 실거래 ──
            Row(
              children: [
                Text('이 구역 최근 실거래', style: textTheme.titleMedium),
                const SizedBox(width: 6),
                if (!loading)
                  Text('${items.length}개 단지',
                      style: textTheme.bodySmall?.copyWith(color: Colors.grey[700])),
              ],
            ),
            const SizedBox(height: 8),
            if (!loading && items.isNotEmpty)
              Wrap(
                spacing: 6,
                children: [
                  _sortChip('최근 거래순', _SortBy.recent),
                  _sortChip('높은 가격순', _SortBy.priceHigh),
                  _sortChip('낮은 가격순', _SortBy.priceLow),
                ],
              ),
            const SizedBox(height: 4),

            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    const Text('최근 3개월 동안 이 구역 안의 아파트·연립다세대 거래가 없어요'),
                    const SizedBox(height: 4),
                    Text('단독·다가구 거래는 아직 포함하지 않았어요',
                        style: textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  ],
                ),
              )
            else
              for (final c in items) _ComplexTile(c),

            const SizedBox(height: 12),
            Text(
              '출처: 국토교통부 정비구역(2026-10 기준) · 아파트/연립다세대 매매 실거래가(최근 3개월)',
              style: textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(String text, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (color ?? Colors.grey).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TermText(text, style: const TextStyle(fontSize: 12, color: Colors.black87)), // 어려운 단어는 눌러서 뜻 보기
      );

  Widget _sortChip(String label, _SortBy value) => ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: _sort == value,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => setState(() => _sort = value),
      );
}

/// 단지 한 줄: 이름 · 유형/면적/층 · 최근 거래가 · 거래일 · ♡
class _ComplexTile extends StatelessWidget {
  final ComplexInfo c;
  const _ComplexTile(this.c);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
    final store = FavoriteStore.instance;

    final detail = [
      c.type,
      if (c.areaM2 != null) '${c.areaM2!.toStringAsFixed(1)}㎡(${c.pyeong!.toStringAsFixed(0)}평)',
      if (c.floor != null && c.floor!.isNotEmpty) '${c.floor}층',
      if (c.buildYear != null && c.buildYear!.isNotEmpty) '${c.buildYear}년',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // 유형 표시 (아파트 / 연립다세대)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (c.isApartment ? primary : Colors.teal).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(c.isApartment ? Icons.apartment : Icons.home_work_outlined,
                size: 20, color: c.isApartment ? primary : Colors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(detail, style: textTheme.bodySmall?.copyWith(color: Colors.grey[700])),
                const SizedBox(height: 2),
                Text.rich(TextSpan(children: [
                  TextSpan(
                    text: formatKorean(c.priceWon),
                    style: textTheme.titleSmall?.copyWith(color: primary, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: '  ${c.dealDate.replaceAll('-', '.')}'
                        '${c.dealCount > 1 ? ' · 거래 ${c.dealCount}건' : ''}',
                    style: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                  ),
                ])),
              ],
            ),
          ),
          // ♡ 찜 (관심 단지 탭으로 이어짐)
          ValueListenableBuilder<List<FavoriteComplex>>(
            valueListenable: store.items,
            builder: (context, _, __) {
              final saved = store.contains(c.id);
              return IconButton(
                tooltip: saved ? '관심 단지에서 빼기' : '관심 단지에 추가',
                icon: Icon(saved ? Icons.favorite : Icons.favorite_border,
                    color: saved ? Colors.pink : Colors.grey[600]),
                onPressed: () {
                  store.toggle(ComplexRepository.toFavorite(c));
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      duration: const Duration(seconds: 2),
                      content: Text(saved
                          ? '${c.name}을(를) 관심 단지에서 뺐어요'
                          : '${c.name}을(를) 관심 단지에 담았어요'),
                    ));
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 실거래가 마커 범례 (● 아파트  ● 연립다세대)
class _TradeLegend extends StatelessWidget {
  const _TradeLegend();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        item(primary, '아파트'),
        const SizedBox(width: 10),
        item(Colors.teal, '연립다세대'),
        const SizedBox(width: 10),
        const Text('최근 3개월', style: TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

/// 추진단계 색상 범례
class _StageLegend extends StatelessWidget {
  const _StageLegend();

  static const _items = [
    ('추진위·구역지정', '정비구역지정'),
    ('조합설립', '조합설립인가'),
    ('사업시행인가', '사업시행인가'),
    ('관리처분', '관리처분인가'),
    ('착공', '착공'),
    ('단계 정보 없음', null),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, stage) in _items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      color: RedevZone.stageColor(stage),
                    ),
                    const SizedBox(width: 6),
                    TermText(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}