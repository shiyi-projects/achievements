class AuthProfile {
  const AuthProfile({
    required this.id,
    required this.role,
    this.deviceId,
    this.openid,
    this.nickname,
    this.avatarUrl,
    this.platform,
  });

  factory AuthProfile.fromJson(Map<String, dynamic> json) {
    return AuthProfile(
      id: json['id'] as int,
      role: json['role'] as String,
      deviceId: json['device_id'] as String?,
      openid: json['openid'] as String?,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      platform: json['platform'] as String?,
    );
  }

  final int id;
  final String role;
  final String? deviceId;
  final String? openid;
  final String? nickname;
  final String? avatarUrl;
  final String? platform;

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'device_id': deviceId,
    'openid': openid,
    'nickname': nickname,
    'avatar_url': avatarUrl,
    'platform': platform,
  };
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.olibUserId,
    required this.appUserId,
    required this.profile,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String,
      olibUserId: json['olib_user_id'] as int,
      appUserId: json['app_user_id'] as String,
      profile: AuthProfile.fromJson(json['profile'] as Map<String, dynamic>),
    );
  }

  final String token;
  final int olibUserId;
  final String appUserId;
  final AuthProfile profile;

  Map<String, dynamic> toJson() => {
    'token': token,
    'olib_user_id': olibUserId,
    'app_user_id': appUserId,
    'profile': profile.toJson(),
  };
}

sealed class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.session);

  final AuthSession session;
}

class AuthSwitching extends AuthState {
  const AuthSwitching(this.previousSession);

  final AuthSession? previousSession;
}
