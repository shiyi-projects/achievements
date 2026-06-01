# 发布与打包流程文档

> 本文是发布链路的**权威文档**:涵盖版本号管理、tag 触发的多平台构建分发、签名配置、
> 以及拆分发布分支同步。落地于 `.github/workflows/release.yml` 与 `sync-split-branches.yml`。

## 1. 总体流程

```
改版本号(脚本) → commit → 打 v* tag → push tag
        └─ 触发 release.yml:
             ├─ Windows job:  flutter build windows → 便携 zip + Inno Setup 安装包
             ├─ Android job:  flutter build apk(release 签名) → APK
             └─ publish job:  汇总三个产物发布到 GitHub Release
push main 时另触发 sync-split-branches.yml,把 main 同步到 frontend / backend 发布分支。
```

## 2. 版本号管理

**禁止手动逐个文件改版本号**,统一用脚本:

```bash
python scripts/bump_version.py --bump minor     # 0.0.x → 0.1.0
python scripts/bump_version.py 1.2.3            # 显式指定
python scripts/bump_version.py --bump patch --dry-run
```

脚本以 `frontend/pubspec.yaml` 的 `version: X.Y.Z+BUILD` 为单一真源,一次性同步到三处:

| 文件 | 字段 |
|---|---|
| `frontend/pubspec.yaml` | `version: X.Y.Z+BUILD`(构建号默认自增) |
| `backend/pyproject.toml` | `version = "X.Y.Z"` |
| `frontend/installer/achievements.iss` | `#define MyAppVersion "X.Y.Z"` |

任一文件匹配数不为 1 即中止,防止漏改/误改。

## 3. 发布一个版本(操作步骤)

```bash
python scripts/bump_version.py --bump minor      # 1. 升版本
git add -A && git commit -m "chore(release): bump version to X.Y.Z"
git push origin main                              # 2. 合并/推送到 main
git tag -a vX.Y.Z -m "Release vX.Y.Z"            # 3. 打 tag(必须 v 前缀)
git push origin vX.Y.Z                            # 4. 推 tag → 自动构建分发
```

产物自动发布到 `https://github.com/<owner>/achievements/releases/tag/vX.Y.Z`:
`AchievementsSetup-X.Y.Z.exe` / `Achievements-X.Y.Z-windows-portable.zip` / `Achievements-X.Y.Z-android.apk`。

> 注意:tag 一旦推送、且 Release 已发布,**不要再移动 tag**;补救只在调试期可接受。正式发版请打新版本号。

## 4. CI 环境约束

- **Flutter 版本必须与本地一致(当前 `3.44.0`)**,在 `release.yml` 的 `env.FLUTTER_VERSION` 统一控制。
  旧版(如 3.32.2)的 Flutter Gradle Plugin **不注册 `kotlin {}` 扩展访问器**,会导致
  `android/app/build.gradle.kts` 里的 `kotlin { compilerOptions { jvmTarget } }` 编译报
  *Unresolved reference*。升级本地 Flutter 时记得同步改这里。
- `assets/icons/` 目录必须保留 `.gitkeep`:pubspec 把它声明为资源目录,但 git 不追踪空目录,
  缺失会让 Windows 构建报 `unable to find directory entry in pubspec.yaml`。

## 5. Android 签名

- `android/app/build.gradle.kts` 从 `android/key.properties` 读取 release 签名配置;
  **文件缺失时回退 debug 签名**(本地 `flutter run` 与未配 Secrets 的构建仍可跑,但产物不可分发)。
- CI 通过 4 个 **GitHub Secrets** 注入(`release.yml` 的 Android job):

  | Secret | 内容 |
  |---|---|
  | `KEYSTORE_BASE64` | keystore 文件的 base64(单行,纯 ASCII) |
  | `KEY_ALIAS` | 密钥别名 |
  | `KEY_PASSWORD` | key 密码 |
  | `STORE_PASSWORD` | store 密码 |

- 生成与配置(在仓库外目录):
  ```powershell
  keytool -genkeypair -v -keystore achievements-release.keystore -alias achievements `
    -keyalg RSA -keysize 2048 -validity 10000 -storepass "<store>" -keypass "<key>" `
    -dname "CN=Achievements, O=shiyi, C=CN"
  $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("achievements-release.keystore"))
  gh secret set KEYSTORE_BASE64 --body $b64     # 用 --body 传参,避免文件编码问题
  gh secret set KEY_ALIAS --body "achievements"
  gh secret set STORE_PASSWORD --body "<store>"
  gh secret set KEY_PASSWORD --body "<key>"
  ```
  > **Windows 编码坑**:不要用 `Set-Content keystore.base64.txt` 再 `gh secret set < 文件` ——
  > Windows PowerShell 5.1 默认写 UTF-16+BOM,CI 端 `base64 -d` 会解码失败。用 `--body $b64`
  > 直接传参(纯 ASCII)最稳。workflow 解码前也做了 `tr -d '\r\n '` 兜底 CRLF。
- keystore 与密码**务必备份**:丢失则无法再给同一应用发升级包。`key.properties` / `*.keystore` / `*.base64.txt` 均已在 `.gitignore`。

## 6. Windows 安装包(Inno Setup)

- 脚本:`frontend/installer/achievements.iss`(`AppId` GUID 固定不可改,改了等于新应用,老用户升不了)。
- CI 里 `choco install innosetup` 装官方 Inno Setup 6,再 `ISCC.exe installer\achievements.iss` 编译,
  产出 `installer/Output/AchievementsSetup-<ver>.exe`。
- **关键坑**:`ChineseSimplified.isl` 是**非官方翻译**,Inno Setup 安装包**不自带**(CI runner 上也没有)。
  因此该文件**内置在仓库** `frontend/installer/ChineseSimplified.isl`,`.iss` 用相对路径引用
  (`MessagesFile: "ChineseSimplified.isl"`,而非 `compiler:Languages\...`),与编译机环境无关。
  英文 `Default.isl` 是官方自带,仍用 `compiler:` 引用。
- 本机 Inno Setup 与工具链速查:见全局记忆 / `D:\Software\tools\Inno Setup 6\`。

## 7. 拆分发布分支同步(`sync-split-branches.yml`)

- `main` 是单仓真源;`frontend` / `backend` 是「只保留各自子目录」的发布分支
  (`frontend` 去掉 `backend/`,`backend` 去掉 `frontend/`)。
- **每次 push `main` 自动同步**:合并式保留历史,对方目录的 modify/delete 冲突统一按删除解决;
  出现真正内容冲突则**失败报错**,不静默提交。手动改这两个分支无意义。

## 8. 历史决策与备注

- 原 `ci.yml`(ruff/mypy/pytest + dart analyze/test)**已删除**(2026-06-01):本地已做检查门禁,
  且拆分发布分支各缺一侧目录会让对应 job 必然失败。**不要再加回 CI 语法检查。**
- 现存 workflow 仅 `release.yml` 与 `sync-split-branches.yml`。
- CI actions 仍用 Node 20(GitHub 2026-06-16 起将强制 Node 24),后续顺手升 `actions/*` 版本。
