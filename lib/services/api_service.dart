// lib/services/api_service.dart

import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import '../models/zone_model.dart';

class ApiService {
  /// assets에 저장된 전국 도시정비사업 통합 CSV 데이터를 로드하여 구역명 기준 Map으로 반환
  static Future<Map<String, ZoneDetailInfo>> loadCsvData() async {
    Map<String, ZoneDetailInfo> infoMap = {};

    try {
      final rawData = await rootBundle.loadString('assets/data/redevelopment_info.csv');
      // 줄바꿈 기준으로 CSV 파싱
      List<List<dynamic>> csvRows = const CsvToListConverter(eol: '\n').convert(rawData);

      if (csvRows.isEmpty) return infoMap;

      // 0번 인덱스(헤더) 제외 후 데이터 매핑
      // 컬럼 순서: 0:시도, 1:시군구, 2:구역명칭, 3:현 사업 추진단계, 4:사업유형, 5:사업시행자, 6:공급 예정 세대 수
      for (int i = 1; i < csvRows.length; i++) {
        final row = csvRows[i];
        if (row.length >= 7) {
          final zoneName = row[2].toString().trim();
          final info = ZoneDetailInfo(
            sido: row[0].toString().trim(),
            sigungu: row[1].toString().trim(),
            zoneName: zoneName,
            stage: row[3].toString().trim(),
            type: row[4].toString().trim(),
            executor: row[5].toString().trim(),
            householdCount: row[6].toString().trim(),
          );
          infoMap[zoneName] = info;
        }
      }
      print("CSV 데이터셋 로드 완료: ${infoMap.length}건");
    } catch (e) {
      print("CSV 로딩 중 오류 발생 (인코딩 UTF-8 확인 필요): $e");
    }

    return infoMap;
  }
}