# 引用说明：dev-assets

记录本项目对全局复用资产库 **dev-assets** 的引用，便于后续复用与维护。

## 基本信息

| 项 | 内容 |
| --- | --- |
| 被引用项目 | `dev-assets`（全局可复用资产库） |
| 本地路径 | `D:\SoftwareData\dev-assets` |
| 用途 | 提供品牌/平台 logo 等通用视觉资产（GitHub、哔哩哔哩等） |
| 引用方式 | **源码拷贝**（把所需 SVG 复制进本项目 `frontend/assets/logos/`），非子模块、非依赖 |

## 已引用资产

| 来源文件 | 拷入位置 | 用途 | 着色策略 |
| --- | --- | --- | --- |
| `logos/github.svg` | `frontend/assets/logos/github.svg` | 设置页「关于」GitHub 外链图标 | 纯黑单色，渲染时用 `ColorFilter` 着成 `onSurfaceVariant` 跟随主题（深色模式下黑色不可见，必须着色） |
| `logos/bilibili.svg` | `frontend/assets/logos/bilibili.svg` | 设置页「关于」哔哩哔哩外链图标 | 品牌蓝 `#20B0E3`，保留原色（明暗主题均可辨识） |

## 接入方式

1. SVG 复制到 `frontend/assets/logos/`，并在 `pubspec.yaml` 的 `flutter > assets` 声明 `- assets/logos/`。
2. 路径常量集中在 `lib/core/theme/app_icons.dart`：`AppIcons.github` / `AppIcons.bilibili`。
3. 渲染统一走 `AppIcons.svgIcon(path, size:, color:)`：
   - `color` 传非空 → 单色图标整体着色（GitHub）。
   - `color` 省略 → 保留多色原貌（哔哩哔哩）。
4. 设置页 `_LinkTile` 通过 `tinted` 标志决定是否着色。

## 更新维护

- 上游 dev-assets 更新 logo 时，需手动重新拷贝覆盖 `frontend/assets/logos/` 下对应文件（源码拷贝方式不会自动同步）。
- 新增其它品牌图标时，按同样四步接入，并在本表追加一行。
