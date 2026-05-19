import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_view.g.dart';

/// 主内容区当前显示的视图。
///
/// 侧边栏点击清单 → [AppView.list];点击日历图标 → [AppView.calendar]。
enum AppView { list, calendar }

@Riverpod(keepAlive: true)
class CurrentViewNotifier extends _$CurrentViewNotifier {
  @override
  AppView build() => AppView.list;

  void showList() => state = AppView.list;
  void showCalendar() => state = AppView.calendar;
}
