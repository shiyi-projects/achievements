import 'package:achievements/features/sidebar/widgets/sidebar_tile.dart';
import 'package:flutter/material.dart';

/// 通用顶部导航条目(日历 / 专注 / 成就)。对应 AppView 切换,而不是清单切换。
///
/// 与清单行共用 [SidebarTileShell],保证两类入口在同一列里的排版完全一致。
class ViewNavTile extends StatelessWidget {
  const ViewNavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SidebarTileShell(
      icon: icon,
      title: label,
      selected: selected,
      onTap: () {
        onTap();
        closeDrawerIfOpen(context);
      },
    );
  }
}
