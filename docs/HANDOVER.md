# zeroTV 接手开发提示词（Handover Prompt）

> 生成时间：2026-09-22。将本文件全文提供给下一会话即可无缝接手。
> 本文件描述的是"当前真实状态"，与 docs/PLAN.md（长期计划）互补；冲突时以代码为准。

## 1. 项目一句话

开源免费跨平台 IPTV 播放器：Flutter + media_kit(libmpv)，纯本地零后端，GPL-3.0，
monorepo（1 个 Flutter App + 4 个纯 Dart 包），P0 平台 Android + Windows。

## 2. 当前进展（已完成）

- **M0 工程骨架（commit dd4a259）**：仓库初始化、CI（GitHub Actions）、
  very_good_analysis 门禁、四个纯 Dart 包的最小可用实现 + 单测
  （m3u_parser / xmltv_parser / stream_probe / iptv_core 领域层与端口接口）。
- **M1 核心链路（commit b954103）**：
  - 订阅添加三形态：远程 URL（dio，镜像兜底）/ 本地文件（file_picker 13）/
    粘贴文本（一次性导入，不落库不再同步）。
  - 同步引擎：先取后换，失败保留旧数据；AutoSyncService 按 6h 间隔到期同步。
  - **内置默认源**：首启空库自动播种 vbskycn/iptv IPv4（主地址 live.zbds.top +
    gh-proxy/raw 双镜像），用户可删可换（2026-09-22 用户拍板，替代原"确认后添加"）。
  - 分组频道列表（分组 chips + 过滤）+ media_kit 单流播放页（UA/Referer 透传、点按 OSD）。
  - drift schema v2；两处 NativeDatabase 显式 `PRAGMA foreign_keys = ON`。
  - AndroidManifest 已加 INTERNET + usesCleartextTraffic（勿删，明文源必需）。

## 3. scripts/ 目录（本次新增）

```
scripts/
  common.ps1          共享函数库（依赖检查/代理绕过/pub get/代码生成/符号链接预建），勿直接运行
  run_tests.ps1       一键质量门，与 CI 同构（-SkipCodegen / -Fast）
  build_windows.ps1   Windows 构建（-Mode debug|release，默认 release）
  build_android.ps1   Android 构建（-Target apk|aab、-Mode debug|release）
  README.md           使用说明
```

用法：`powershell -File scripts\run_tests.ps1`（提交前必跑，预判 CI）。
脚本以仓库根为基准，任意目录可调用；失败即停、非零退出。

## 4. 质量验证方式

- 本地：`scripts\run_tests.ps1`（等价于 CI 流水线）。
- 手动等价物：逐目录 `pub get` → app 内 `dart run build_runner build -d`
  → 根目录 `dart format --set-exit-if-changed .` + `flutter analyze`
  → 各 packages `dart test` → app `flutter test`。
- 当前状态：全绿（最近一次全量验证 2026-09-22）。

## 5. 下一步待办（M2，按优先级）

1. 多订阅管理界面（列表/启停/删除/改名，settings 下挂入口）。
2. WorkManager 后台同步（Android）+ Windows 启动时同步补齐。
3. 收藏与最近观看（表结构已有：favorites/watch_history 按 identityKey 独立存表）。
4. 频道搜索（本地 LIKE/拼音可后置）。
5. 自定义添加单频道。
6. stream_probe 批量可用性检测与列表标记（引擎已在 packages/stream_probe，接 UI）。
7. 播放历史驱动"上次观看"恢复。

更远：M3（多源聚合 failover、探测优先选源）、M4（EPG、平板/TV/遥控器、录制）、
M5（性能压测、i18n、图标、Release 工作流含 Android 签名配置）。

## 6. 关键架构约束（违者必踩坑）

- **依赖解析 standalone**：禁止 Pub Workspaces/melos 共享解析
  （flutter_test 钉死 test_api 0.7.11，与 test>=1.31 必然冲突）。
  每目录单独 pub get；库包不提交 lockfile（已 gitignore）。
- **分层**：feature-first + data/application/presentation；领域实体与端口接口
  在 iptv_core（纯 Dart，禁止 import flutter/*）。drift 行类与领域实体同名
  （Subscription/Channel），数据层 import 一律 `as db` 前缀。
- **端口接口是刻意的单方法抽象**：`one_member_abstracts` 已在根 lint 禁用；
  `prefer_initializing_formals` 同样禁用（对私有字段+命名参数误报）。勿为凑 lint 重构。
- **同步语义**：任何同步失败不得清空已存频道；收藏/历史不得挂 channels 表。
- **代码生成**：`*.g.dart` 不入库，analyze/test/build 前必须 build_runner。
- **代码规范**：单文件 ≤1500 行、函数 ≤100 行；SOLID + DRY；public API 写 dartdoc。

## 7. 环境与生态版本（2026-09 基线）

- Flutter 3.44.1 / Dart 3.12.1 / JDK17 / VS2022；镜像 pub.flutter-io.cn。
- riverpod 3.x：无 `valueOrNull`（用 `.value`）、`Override` 类型不导出；
  file_picker 13：`FilePicker.pickFile()` 静态方法（`.platform` 已删）；
  media_kit_video 2：`controls` 传 builder；go_router 18：extra 传对象。
- 本机代理必须 `NO_PROXY=localhost,127.0.0.1`，否则 flutter test 挂（脚本已内置）。
- **widget 测试禁用 drift 活流**（StreamQueryStore 残留 Timer → 假阳性 + 连锁挂死）：
  用 `test/helpers/fake_channel_repository.dart`；drift 行为由仓库单测覆盖。
- **Windows 构建遗留问题**：flutter 创建插件符号链接在本机崩溃
  （plugin_symlinks errno=2，沙箱外同现，M0 即存在）。解法：开开发者模式或
  管理员身份跑首次构建；build_windows.ps1 已预建目录缓解。
  Android APK 构建链路已被用户验证可用。

## 8. 常用入口

- 计划与里程碑：`docs/PLAN.md`（§8 为最新状态）
- 默认源定义：`apps/player/lib/features/subscription/domain/default_subscription.dart`
- 依赖注入装配：`apps/player/lib/features/subscription/application/providers.dart`
- 项目长期记忆：`.workbuddy/memory/MEMORY.md`（gitignored）
