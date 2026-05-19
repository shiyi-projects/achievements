import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_view.g.dart';

/// 主内容区当前显示的视图。
enum AppView { list, calendar, focus, search }

@Riverpod(keepAlive: true)
class CurrentViewNotifier extends _$CurrentViewNotifier {
  @override
  AppView build() => AppView.list;

  void showList() => state = AppView.list;
  void showCalendar() => state = AppView.calendar;
  void showFocus() => state = AppView.focus;
  void showSearch() => state = AppView.search;
}
