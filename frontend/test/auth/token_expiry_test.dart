import 'dart:convert';

import 'package:achievements/features/auth/token_expiry.dart';
import 'package:flutter_test/flutter_test.dart';

/// 造一个签名部分是占位的 JWT——客户端只解 payload、不验签,足够测判定逻辑。
String _tokenWithExp(Duration fromNow) {
  final exp =
      DateTime.now().toUtc().add(fromNow).millisecondsSinceEpoch ~/ 1000;
  return _tokenWithPayload({'sub': '42', 'type': 'client', 'exp': exp});
}

String _tokenWithPayload(Map<String, dynamic> payload) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg(payload)}.signature';
}

void main() {
  group('readTokenExpiry', () {
    test('解出 exp', () {
      final expiry = readTokenExpiry(_tokenWithExp(const Duration(hours: 8)));
      expect(expiry, isNotNull);
      expect(
        expiry!.difference(DateTime.now().toUtc()).inMinutes,
        closeTo(480, 2),
      );
    });

    test('非 JWT 形状返回 null', () {
      expect(readTokenExpiry('not-a-jwt'), isNull);
      expect(readTokenExpiry(''), isNull);
    });

    test('缺 exp 返回 null', () {
      expect(readTokenExpiry(_tokenWithPayload({'sub': '42'})), isNull);
    });
  });

  group('shouldRenew', () {
    test('线上 8h TTL 下每次检查都该续', () {
      expect(shouldRenew(_tokenWithExp(const Duration(hours: 8))), isTrue);
    });

    test('TTL 调长到 7 天后不必每次都续', () {
      expect(shouldRenew(_tokenWithExp(const Duration(days: 7))), isFalse);
    });

    test('剩余跌破窗口即续', () {
      expect(shouldRenew(_tokenWithExp(const Duration(hours: 47))), isTrue);
    });

    test('解不出 exp 时宁可多续一次', () {
      expect(shouldRenew('not-a-jwt'), isTrue);
    });
  });

  group('isTokenExpired', () {
    test('已过期', () {
      expect(isTokenExpired(_tokenWithExp(const Duration(hours: -1))), isTrue);
    });

    test('未过期', () {
      expect(
        isTokenExpired(_tokenWithExp(const Duration(minutes: 30))),
        isFalse,
      );
    });

    test('解不出 exp 时不当作过期(交给服务端裁定)', () {
      expect(isTokenExpired('not-a-jwt'), isFalse);
    });
  });
}
