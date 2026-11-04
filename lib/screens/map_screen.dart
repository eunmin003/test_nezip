import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../models/favorite_complex.dart';
import '../models/redev_zone.dart';
import '../services/complex_repository.dart';
import '../tax/calculator.dart' show formatKorean;
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
              _mapController = controller;
              ComplexRepository.preload(); // 단지 실거래 데이터 미리 읽기
              _loadZonesInCurrentBounds();
            },
            // 지도 이동이 멈추면 새로 보이는 구역을 추가로 그림
            onCameraIdle: _loadZonesInCurrentBounds,
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
    _shownZoneIds.clear();
    await _loadZonesInCurrentBounds();
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
        child: Text(text, style: const TextStyle(fontSize: 12)),
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
                    Text(label, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}