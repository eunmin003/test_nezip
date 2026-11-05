// lib/services/auth_service.dart
//
// 로그인 상태 관리 (화면은 이 클래스만 봄)
//
// ⚠️ 지금은 "가짜 로그인"입니다. 버튼을 누르면 테스트 사용자로 로그인돼요.
//    카카오 로그인을 붙일 때는 아래 [TODO 카카오] 표시가 있는 세 곳만 바꾸면 되고,
//    마이 페이지 화면 코드는 그대로 둡니다.
//    (kakao_flutter_sdk_user 패키지: login → UserApi.instance.loginWithKakaoTalk / loginWithKakaoAccount,
//     logout → UserApi.instance.logout, 회원탈퇴 → UserApi.instance.unlink)

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/favorite_complex.dart';

class AppUser {
  final String id; // 카카오 회원번호 (가짜 로그인은 'test-user')
  final String nickname;
  final String? profileImageUrl;
  final String provider; // 'kakao' / 'test'

  const AppUser({
    required this.id,
    required this.nickname,
    this.profileImageUrl,
    required this.provider,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'profileImageUrl': profileImageUrl,
        'provider': provider,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: (j['id'] ?? '').toString(),
        nickname: (j['nickname'] ?? '').toString(),
        profileImageUrl: j['profileImageUrl'] as String?,
        provider: (j['provider'] ?? 'test').toString(),
      );
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _prefsKey = 'auth_user_v1';
  bool _loaded = false;

  /// 로그인한 사용자 (null이면 로그인 안 함). 화면은 이걸 ValueListenableBuilder로 지켜봄.
  final ValueNotifier<AppUser?> user = ValueNotifier(null);

  bool get isLoggedIn => user.value != null;

  /// 앱을 다시 켰을 때 로그인 상태 복원
  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        user.value = AppUser.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
        debugPrint('[로그인] 저장된 로그인 복원: ${user.value!.nickname}');
      }
      // [TODO 카카오] 저장된 토큰이 아직 유효한지 확인 (AuthApi.instance.hasToken / UserApi.instance.accessTokenInfo)
    } catch (e) {
      debugPrint('[로그인] 복원 실패: $e');
    }
  }

  /// 로그인. 성공하면 true.
  Future<bool> login() async {
    try {
      // [TODO 카카오] 여기서 카카오 로그인 → UserApi.instance.me()로 id·닉네임·프로필 사진 받기
      const fake = AppUser(id: 'test-user', nickname: '테스트 사용자', provider: 'test');
      await _setUser(fake);
      debugPrint('[로그인] 로그인: ${fake.nickname}');
      return true;
    } catch (e) {
      debugPrint('[로그인] 실패: $e');
      return false;
    }
  }

  /// 로그아웃 (찜 목록은 기기에 그대로 남음)
  Future<void> logout() async {
    // [TODO 카카오] UserApi.instance.logout()
    await _setUser(null);
    debugPrint('[로그인] 로그아웃');
  }

  /// 회원탈퇴: 찜 목록 삭제 + 로그인 정보 삭제
  Future<void> withdraw() async {
    // [TODO 카카오] UserApi.instance.unlink()  (카카오와 앱 연결 끊기)
    final store = FavoriteStore.instance;
    for (final id in store.items.value.map((c) => c.id).toList()) {
      store.remove(id);
    }
    await _setUser(null);
    debugPrint('[로그인] 회원탈퇴 완료 (찜 목록 삭제)');
  }

  Future<void> _setUser(AppUser? u) async {
    user.value = u;
    final prefs = await SharedPreferences.getInstance();
    if (u == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, jsonEncode(u.toJson()));
    }
  }
}
