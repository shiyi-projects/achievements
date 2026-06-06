#!/usr/bin/env python3
"""统一升级前后端所有版本号。

单一真源：以 `frontend/pubspec.yaml` 的 `version: X.Y.Z+BUILD` 为基准，
一条命令把语义版本号同步写入下列所有位置，避免手动逐个文件改动导致的漏改 / 不同步：

  - frontend/pubspec.yaml            version: X.Y.Z+BUILD   (Dart：含构建号)
  - backend/pyproject.toml           version = "X.Y.Z"
  - frontend/installer/achievements.iss   #define MyAppVersion "X.Y.Z"
  - frontend/lib/core/app_info.dart  const String kAppVersion = 'X.Y.Z'

用法：
  python scripts/bump_version.py --bump patch        # 0.0.2 -> 0.0.3
  python scripts/bump_version.py --bump minor        # 0.0.2 -> 0.1.0
  python scripts/bump_version.py --bump major        # 0.0.2 -> 1.0.0
  python scripts/bump_version.py 0.1.0               # 显式指定版本
  python scripts/bump_version.py --bump patch --dry-run   # 只预览不写入

构建号（pubspec 的 +N）默认自增 1；可用 --build N 显式指定，或 --keep-build 保持不变。
脚本不做 git 提交 / 打 tag；版本号确认无误后再人工提交并 `git tag vX.Y.Z`。
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

PUBSPEC = REPO_ROOT / "frontend" / "pubspec.yaml"
PYPROJECT = REPO_ROOT / "backend" / "pyproject.toml"
ISS = REPO_ROOT / "frontend" / "installer" / "achievements.iss"
APP_INFO = REPO_ROOT / "frontend" / "lib" / "core" / "app_info.dart"

SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")


@dataclass
class Edit:
    """一处待替换：文件 + 匹配正则 + 用 new_version 生成替换串的函数。"""

    path: Path
    pattern: re.Pattern[str]
    replacement: object  # Callable[[str], str]：传入 new_version 返回整行替换文本
    label: str


def read_current() -> tuple[str, int]:
    """从 pubspec 读出当前 (语义版本, 构建号)。"""
    text = PUBSPEC.read_text(encoding="utf-8")
    m = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", text, re.MULTILINE)
    if not m:
        sys.exit(f"无法从 {PUBSPEC} 解析 'version: X.Y.Z+BUILD'")
    return m.group(1), int(m.group(2))


def compute_version(current: str, args: argparse.Namespace) -> str:
    if args.version:
        if not SEMVER_RE.match(args.version):
            sys.exit(f"版本号格式非法（应为 X.Y.Z）：{args.version}")
        return args.version
    major, minor, patch = (int(x) for x in current.split("."))
    if args.bump == "major":
        return f"{major + 1}.0.0"
    if args.bump == "minor":
        return f"{major}.{minor + 1}.0"
    return f"{major}.{minor}.{patch + 1}"  # patch


def build_edits(new_version: str, build: int) -> list[Edit]:
    return [
        Edit(
            PUBSPEC,
            re.compile(r"^version:\s*\d+\.\d+\.\d+\+\d+\s*$", re.MULTILINE),
            lambda v: f"version: {v}+{build}",
            f"pubspec.yaml  version → {new_version}+{build}",
        ),
        Edit(
            PYPROJECT,
            # 仅匹配行首的 `version = "..."`（[project] 段），不碰 target-version / python_version
            re.compile(r'^version\s*=\s*"\d+\.\d+\.\d+"\s*$', re.MULTILINE),
            lambda v: f'version = "{v}"',
            f"pyproject.toml  version → {new_version}",
        ),
        Edit(
            ISS,
            re.compile(r'^#define\s+MyAppVersion\s+"\d+\.\d+\.\d+"\s*$', re.MULTILINE),
            lambda v: f'#define MyAppVersion         "{v}"',
            f"achievements.iss  MyAppVersion → {new_version}",
        ),
        Edit(
            APP_INFO,
            re.compile(r"^const String kAppVersion = '\d+\.\d+\.\d+';\s*$", re.MULTILINE),
            lambda v: f"const String kAppVersion = '{v}';",
            f"app_info.dart  kAppVersion → {new_version}",
        ),
    ]


def apply_edit(edit: Edit, new_version: str, dry_run: bool) -> None:
    if not edit.path.exists():
        sys.exit(f"找不到文件：{edit.path}")
    text = edit.path.read_text(encoding="utf-8")
    new_line = edit.replacement(new_version)
    new_text, n = edit.pattern.subn(new_line, text)
    if n != 1:
        sys.exit(f"在 {edit.path} 中匹配到 {n} 处（应为 1 处），中止以防误改")
    if not dry_run:
        edit.path.write_text(new_text, encoding="utf-8")
    print(f"  ✓ {edit.label}")


def main() -> None:
    # Windows 控制台默认 GBK，无法输出 ✓ 与中文；统一切到 UTF-8。
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, OSError):
        pass

    parser = argparse.ArgumentParser(description="统一升级前后端版本号")
    parser.add_argument("version", nargs="?", help="显式语义版本号 X.Y.Z")
    parser.add_argument(
        "--bump",
        choices=["major", "minor", "patch"],
        help="按级别自增（与显式版本号二选一）",
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--build", type=int, help="显式设置 pubspec 构建号")
    group.add_argument(
        "--keep-build", action="store_true", help="保持 pubspec 构建号不变"
    )
    parser.add_argument("--dry-run", action="store_true", help="只预览不写入")
    args = parser.parse_args()

    if bool(args.version) == bool(args.bump):
        parser.error("请二选一：显式版本号 或 --bump <level>")

    current, current_build = read_current()
    new_version = compute_version(current, args)

    if args.build is not None:
        build = args.build
    elif args.keep_build:
        build = current_build
    else:
        build = current_build + 1

    print(f"版本号：{current}+{current_build}  →  {new_version}+{build}")
    if args.dry_run:
        print("（dry-run：以下为将要进行的改动，未写入文件）")

    for edit in build_edits(new_version, build):
        apply_edit(edit, new_version, args.dry_run)

    print()
    if args.dry_run:
        print("dry-run 完成，未改动任何文件。")
    else:
        print(f"完成。建议下一步：git commit 后  git tag v{new_version}")


if __name__ == "__main__":
    main()
