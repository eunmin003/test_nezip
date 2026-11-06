// lib/services/auth_service.dart
//
// 로그인 상태 관리 (화면은 이 클래스만 봄) — 카카오 로그인 연결 (kakao_flutter_sdk_user 2.x)
//
// - 로그인: 카카오톡 앱이 있으면 카카오톡으로, 없거나 실패하면 카카오계정(웹)으로
// - 로그아웃: 카카오 토큰 삭제 → 기기용 찜 목록으로 (내 찜은 다시 로그인하면 돌아옴)
// - 회원탈퇴: 카카오와 앱 연결 끊기(unlink) + 내 찜 목록·로그인 정보 삭제
// - 사용자 구분은 카카오 회원번호(id)로 함 → 찜 목록도 회원번호별로 따로 저장
//
// 마이 페이지 화면(my_screen.dart)은 이 파일의 user / login / logout / withdraw만 사용해요.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/favorite_complex.dart';

class AppUser {
  final String id; // 카카오 회원번호
  final String nickname;
  final String? profileImageUrl;
  final String provider; // 'kakao'

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

  /// 앱을 다시 켰을 때 로그인 상태 복원 + 카카오 토큰이 아직 살아 있는지 확인
  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) {
        debugPrint('[로그인] 저장된 로그인 없음');
        return;
      }
      final saved = AppUser.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));

      // 예전 '가짜 로그인'(test)으로 저장된 정보는 지움
      if (saved.provider != 'kakao') {
        debugPrint('[로그인] 테스트 로그인 정보 삭제');
        await _setUser(null);
        return;
      }

      // 카카오 토큰이 없으면 로그아웃 상태로
      if (!await AuthApi.instance.hasToken()) {
        debugPrint('[로그인] 카카오 토큰 없음 → 로그아웃 상태');
        await _setUser(null);
        return;
      }

      // 일단 화면에 바로 보여주고, 찜 목록도 내 목록으로
      user.value = saved;
      await FavoriteStore.instance.switchUser(saved.id);
      try {
        await UserApi.instance.accessTokenInfo(); // 토큰 유효성 확인 (만료면 SDK가 자동 갱신 시도)
        debugPrint('[로그인] 카카오 로그인 복원: ${saved.nickname}');
      } on KakaoApiException catch (e) {
        if (e.code == ApiErrorCause.invalidToken) {
          debugPrint('[로그인] 카카오 토큰 만료 → 다시 로그인 필요');
          await _setUser(null);
        } else {
          debugPrint('[로그인] 토큰 확인 오류(로그인 유지): $e');
        }
      } on KakaoAuthException catch (e) {
        debugPrint('[로그인] 토큰 갱신 실패 → 다시 로그인 필요: $e');
        await _setUser(null);
      } catch (e) {
        // 인터넷이 끊긴 경우 등 → 로그인은 유지
        debugPrint('[로그인] 토큰 확인 실패(로그인 유지): $e');
      }
    } catch (e) {
      debugPrint('[로그인] 복원 실패: $e');
    }
  }

  /// 카카오 로그인. 성공하면 true, 취소·실패하면 false.
  Future<bool> login() async {
    try {
      await _loginWithKakao();
      final me = await UserApi.instance.me();
      final profile = me.kakaoAccount?.profile;
      final u = AppUser(
        id: me.id.toString(),
        nickname: profile?.nickname ?? '카카오 사용자',
        profileImageUrl: (profile?.isDefaultImage ?? true)
            ? null
            : (profile?.thumbnailImageUrl ?? profile?.profileImageUrl),
        provider: 'kakao',
      );
      await _setUser(u);
      debugPrint('[로그인] 카카오 로그인 성공: ${u.nickname} (회원번호 ${u.id})');
      return true;
    } catch (e) {
      debugPrint('[로그인] 실패 또는 취소: $e');
      return false;
    }
  }

  /// 카카오톡 앱이 있으면 카카오톡으로, 없으면 카카오계정으로 로그인
  Future<void> _loginWithKakao() async {
    if (await isKakaoTalkInstalled()) {
      try {
        await UserApi.instance.loginWithKakaoTalk();
        debugPrint('[로그인] 카카오톡으로 로그인');
        return;
      } catch (e) {
        // 사용자가 직접 취소한 경우는 계정 로그인으로 넘어가지 않음
        if (_isCancelled(e)) rethrow;
        debugPrint('[로그인] 카카오톡 로그인 실패 → 카카오계정으로 시도: $e');
      }
    }
    await UserApi.instance.loginWithKakaoAccount();
    debugPrint('[로그인] 카카오계정으로 로그인');
  }

  bool _isCancelled(Object e) {
    if (e is KakaoClientException && e.reason == ClientErrorCause.cancelled) return true;
    if (e is PlatformException && e.code == 'CANCELED') return true;
    return false;
  }

  /// 로그아웃 (내 찜 목록은 기기에 저장돼 있다가 다시 로그인하면 돌아옴)
  Future<void> logout() async {
    try {
      await UserApi.instance.logout(); // 실패해도 SDK가 기기의 토큰은 지움
    } catch (e) {
      debugPrint('[로그인] 카카오 로그아웃 요청 실패(기기에서는 로그아웃 처리): $e');
    }
    await _setUser(null);
    debugPrint('[로그인] 로그아웃');
  }

  /// 회원탈퇴: 카카오 연결 끊기 + 내 찜 목록·로그인 정보 삭제.
  /// 카카오 연결 끊기에 성공하면 true (실패해도 기기 정보는 지움).
  Future<bool> withdraw() async {
    var unlinked = true;
    try {
      await UserApi.instance.unlink(); // 카카오와 우리 앱의 연결 끊기
      debugPrint('[로그인] 카카오 연결 끊기 완료');
    } catch (e) {
      unlinked = false;
      debugPrint('[로그인] 카카오 연결 끊기 실패: $e');
    }

    final id = user.value?.id;
    if (id != null) await FavoriteStore.instance.deleteUserData(id);
    await _setUser(null);
    debugPrint('[로그인] 회원탈퇴 완료 (찜 목록 삭제)');
    return unlinked;
  }

  Future<void> _setUser(AppUser? u) async {
    user.value = u;
    await FavoriteStore.instance.switchUser(u?.id); // 찜 목록도 이 사람 것으로
    final prefs = await SharedPreferences.getInstance();
    if (u == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, jsonEncode(u.toJson()));
    }
  }
}