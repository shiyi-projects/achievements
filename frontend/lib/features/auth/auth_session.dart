class AuthProfile {
  const AuthProfile({
    required this.id,
    this.openid,
    this.unionid,
    this.nickname,
    this.avatarUrl,
    this.inWecom = false,
  });

  factory AuthProfile.fromJson(Map<String, dynamic> json) {
    return AuthProfile(
      id: json['id'] as int,
      openid: json['openid'] as String?,
      unionid: json['unionid'] as String?,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      inWecom: json['in_wecom'] as bool? ?? false,
    );
  }

  /// SCC user_id
  final int id;
  final String? openid;
  final String? unionid;
  final String? nickname;
  final String? avatarUrl;
  final bool inWecom;

  Map<String, dynamic> toJson() => {
    'id': id,
    'openid': openid,
    'unionid': unionid,
    'nickname': nickname,
    'avatar_url': avatarUrl,
    'in_wecom': inWecom,
  };
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.appUserId,
    required this.profile,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String,
      appUserId: json['app_user_id'] as String,
      profile: AuthProfile.fromJson(json['profile'] as Map<String, dynamic>),
    );
  }

  /// SCC client token(全局唯一鉴权凭据)
  final String token;
  final String appUserId;
  final AuthProfile profile;

  Map<String, dynamic> toJson() => {
    'token': token,
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
