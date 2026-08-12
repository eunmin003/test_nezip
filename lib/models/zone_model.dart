// lib/models/zone_model.dart

import 'package:flutter_naver_map/flutter_naver_map.dart';

/// CSV 데이터셋의 구역 상세 정보 모델
class ZoneDetailInfo {
  final String sido; // 시도
  final String sigungu; // 시군구
  final String zoneName; // 구역명칭
  final String stage; // 현 사업 추진단계 (예: 조합설립인가, 관리처분계획 등)
  final String type; // 사업유형 (재개발, 재건축, 주거환경개선 등)
  final String executor; // 사업시행자
  final String householdCount; // 공급 예정 세대 수

  ZoneDetailInfo({
    required this.sido,
    required this.sigungu,
    required this.zoneName,
    required this.stage,
    required this.type,
    required this.executor,
    required this.householdCount,
  });
}

/// 브이월드 다각형(Polygon) 좌표 + CSV 상세 정보가 결합된 최종 모델
class ZonePolygonModel {
  final String name;
  final List<NLatLng> coordinates;
  ZoneDetailInfo? detailInfo; // CSV 매칭 상세 정보

  ZonePolygonModel({
    required this.name,
    required this.coordinates,
    this.detailInfo,
  });
}