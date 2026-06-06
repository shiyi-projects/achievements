import 'package:achievements/core/update/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateChecker.isNewer', () {
    test('更高的 major/minor/patch 判为更新', () {
      expect(UpdateChecker.isNewer('0.2.0', '0.1.1'), isTrue);
      expect(UpdateChecker.isNewer('1.0.0', '0.9.9'), isTrue);
      expect(UpdateChecker.isNewer('0.1.2', '0.1.1'), isTrue);
    });

    test('相等或更低判为非更新', () {
      expect(UpdateChecker.isNewer('0.2.0', '0.2.0'), isFalse);
      expect(UpdateChecker.isNewer('0.1.1', '0.2.0'), isFalse);
      expect(UpdateChecker.isNewer('0.1.0', '0.1.1'), isFalse);
    });

    test('忽略 +build / -pre 后缀,缺位补 0', () {
      expect(UpdateChecker.isNewer('0.2.0+5', '0.2.0'), isFalse);
      expect(UpdateChecker.isNewer('0.2', '0.1.9'), isTrue);
      expect(UpdateChecker.isNewer('0.2.0-beta', '0.1.0'), isTrue);
    });
  });
}
