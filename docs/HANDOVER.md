# zeroTV 接手开发（Handover ）

> 生成时间：2026-09-24（M3 完成后刷新）。将本文件全文提供给下一会话即可无缝接手。  
> 本文件描述的是"当前真实状态"，与 docs/PLAN.md（长期计划）互补；冲突时以代码为准。

## 0. 接手第一件事

**M3 已全部完成、质量门全绿、已按里程碑粒度提交。** 进入会话后先确认工作树状态  
（`git status` 应为 clean），再开新任务（M4 或平台适配）。  
中文提交信息必须用 `git commit -F <utf8文件>`，且文件须以无 BOM 的 UTF-8 写入  
（PowerShell `Out-File` 管道会丢中文，用 `[System.IO.File]::WriteAllText(..., UTF8Encoding($false))`）。

## 1. 项目一句话

开源免费跨平台 IPTV 播放器：Flutter + media_kit(libmpv)，纯本地零后端，GPL-3.0，  
monorepo（1 个 Flutter App + 4 个纯 Dart 包），P0 平台 Android + Windows。

## 2. 当前进展（已完成）

- **M0 工程骨架（commit dd4a259）**：仓库初始化、CI（GitHub Actions）、  
  very_good_analysis 门禁、四个纯 Dart 包的最小可用实现 + 单测。
- **M1 核心链路（commit b954103）**：订阅添加三形态（URL/文件/粘贴）；  
  同步引擎先取后换、失败保留旧数据；内置默认源；分组频道列表 + media_kit  
  播放页；drift schema v2 + 两处 `PRAGMA foreign_keys = ON`；  
  AndroidManifest 已加 INTERNET + usesCleartextTraffic（勿删）。
- **M2-1 多订阅管理（commit dd62c89）**：管理页 `/settings/subscriptions`；
  启停/改名/删除/单条同步；端口 `rename`/`setEnabled` 靶向更新；默认源复活修复。
- **M2-3 收藏与最近观看（commit cde8ccb）**：sealed `ChannelFilter`（All/Favorites/  
  Recent/Group）；星标收藏；观看历史首次 `playing` 回写。
- **M2-2 频道搜索（commit fdeb406）**：`FilterSearch` 分支；AppBar 搜索模式  
  （进入搜索时隐藏 chips 行）；空结果专属提示。
- **M2-4 上次观看恢复（commit 4985f30）**：`lastWatchedChannelProvider` + 首页  
  「继续观看」横幅（仅 All 过滤、可本会话关闭）。
- **M2-5 自定义添加单频道（commit 79b89f2 + beedd2b）**：`SubscriptionKind.manual`；  
  「我的频道」隐式订阅惰性创建（`AddCustomChannel`）；FAB 改 `MenuAnchor` 双入口  
  （添加订阅 / 添加单频道）；`ChannelRepository.upsertManual`/`deleteManual`；  
  manual 频道 tile 带删除确认（`RemoveCustomChannel`）。
- **M2-6 可用性检测接 UI（commit 1e5c8a0）**：`ProbeResultRepository` 端口 + drift  
  `probe_results`（schema v3）；`RunAvailabilityProbe`/`ProbeScanNotifier`；  
  频道 tile 状态点（可用/超时/失效/不支持）；「可用」过滤 chip；扫描进度条。
- **M2-7 后台同步（commit e37e6a7）**：`workmanager` 依赖；Android WorkManager  
  周期任务（`backgroundSyncDispatcher`，1h，networkType=connected）；  
  桌面应用内 `Timer`；`runBackgroundSync` 可注入容器测试；main.dart 改  
  `UncontrolledProviderScope` + 启动时 `BackgroundSyncScheduler.start()`。
- **M3-1 EPG 数据层（commit d77078a）**：`xmltv_parser` 接入 app；drift `epg_channels`/  
  `epg_programmes`（schema v4）；`EpgRepository` 端口（programmesFor/programmesInWindow/  
  allChannels/replaceFeed/clear）+ drift 实现；`HttpEpgProvider`（dio bytes + gzip 解压）；  
  `EpgSettings`（prefs `epg_url`）+ `SyncEpg`；`EpgGuide`（now/next 计算）。
- **M3-2 EPG UI（commit 948ff58）**：`EpgIndex`（tvgId 优先、频道名规范化回退）；  
  设置页 EPG 源配置页 `/settings/epg`；频道 tile「正在播/接下来」；播放页顶部当前节目。
- **M3-3 多源 failover（commit 14d2bc3）**：`ResolveChannelSources`（按 identityKey  
  去重聚合、探测为 ok 的源提升到次位）；播放器按序打开、`error` 事件自动切下一个源，  
  显示「已切换到源 N/M」。
- **M3-4 播放器 OSD（commit 788e210）**：`player_osd.dart`（`PlayerAspect` 预设、  
  倍速预设、`showTrackMenu`）；底部栏音轨/字幕/宽高比/倍速；`Video.fit` 联动宽高比。
- **M3-5 设置中心（commit f13d861）**：`AppSettings`/`AppSettingsStore`（prefs）+  
  `appSettingsProvider`（Notifier）；设置页同步间隔/检测并发/播放缓冲/主题；  
  联动 `AutoSyncService.syncDue(intervalOverride:)`、`RunAvailabilityProbe` 并发、  
  `PlayerConfiguration.bufferSize`、`MaterialApp.themeMode`；后台同步尊重「仅手动」。
- **M3-6 录制（commit c8eb50d）**：`Recording` 实体 + `RecordingRepository` 端口 +  
  drift `recordings`（schema v5）；`StreamRecorder`（HttpClient 原始字节流落盘，  
  不转码）；`ManageRecording`（start/stop/delete，文档目录 recordings/*.ts）；  
  播放页录制开关；录制管理页 `/recordings`（播放/删除/时长/大小）。

**M3 验收：** 全绿（app 114 例）。

## 3. scripts/ 目录

```
scripts/
  common.ps1          共享函数库（依赖检查/代理绕过/pub get/代码生成），勿直接运行
  run_tests.ps1       一键质量门，与 CI 同构（-SkipCodegen / -Fast）
  build_windows.ps1   Windows 构建（-Mode debug|release，默认 release）
  build_android.ps1   Android 构建（-Target apk|aab、-Mode debug|release）
  README.md           使用说明
```

用法：`powershell -File scripts\run_tests.ps1`（提交前必跑，预判 CI）。  
Windows 插件符号链接预建（`Initialize-WindowsPluginSymlinks`）已下沉到  
`common.ps1` 的 `Invoke-PubGetAll`，所有脚本自动受益。

## 4. 质量验证方式

- 本地：`scripts\run_tests.ps1`（等价于 CI 流水线）。
- 手动等价物：逐目录 `pub get` → app 内 `dart run build_runner build -d`  
  → 根目录 `dart format --set-exit-if-changed .` + `flutter analyze`  
  → 各 packages `dart test` → app `flutter test`。
- 当前状态：全绿（最近一次全量验证 2026-09-24，app 114 例）。

## 5. 下一步待办（M4，按优先级）

M3 已收尾。下一步进入 **M4 — 打磨与发布**：

1. 性能与内存压测（5000+ 频道列表滚动 60fps、长时播放内存稳定）。
2. i18n 中英（flutter_localizations + arb；当前 UI 文案为硬编码中文）。
3. 首次启动流程打磨 + 免责声明（关于页/README 固定展示）。
4. 应用图标（勿用电视台台标）。
5. Release 工作流（tag 触发双端构建并上传 GitHub Releases，含 Android 签名配置）。

**已知未完成/技术债：**
- 录制为「原始字节流直存」：HLS 会存成含 TS 分片的原始响应，播放兼容性取决于源；
  更完善的方案（ffmpeg 转封装/分片重组）留待迭代。
- 定时录制（依赖 EPG 时间段）尚未实现，目前仅手动录制。
- `probe_results` 无过期清理（计划中的 24h 过期未做）。
- Windows 构建在本机受插件符号链接问题阻碍，未做构建冒烟；Android 由用户侧验证。
- 后台同步的 WorkManager 需真机验证。

更远：M5（macOS/Linux/iOS 适配、Android TV D-pad）。

## 6. 关键架构约束（违者必踩坑）

- **依赖解析 standalone**：禁止 Pub Workspaces/melos 共享解析  
  （flutter_test 钉死 test_api 0.7.11，与 test>=1.31 必然冲突）。  
  每目录单独 pub get；库包不提交 lockfile（已 gitignore）。
- **分层**：feature-first + data/application/presentation；领域实体与端口接口  
  在 iptv_core（纯 Dart，禁止 import flutter/*）。
- **drift 生成类型一律 `as db` 前缀**：行类与领域实体同名（Subscription/Channel），  
  Companion 也必须 `db.XxxCompanion.insert(...)`；data 层通常无需 import drift  
  本体，除非用到 OrderingTerm / 聚合（.max()/.count()）/ `Value`（新增列）。
- **仓储更新走靶向方法**：rename/setEnabled/markSynced 模式（SQL UPDATE 单字段），  
  禁止 read-modify-write 整对象 upsert（会覆盖 lastSyncedAt 等并发字段）。
- **端口接口是刻意的单方法抽象**：`one_member_abstracts` 已在根 lint 禁用；  
  `prefer_initializing_formals` 同样禁用（误报）。勿为凑 lint 重构。
- **同步语义**：任何同步失败不得清空已存频道；收藏/历史/探测结果不得挂 channels 表，  
  一律按 `Channel.identityKey`（tvgId ?? 小写 trim 名）独立存表。
- **观看历史在首次 playing 事件回写**，不是进播放页就记。
- **代码生成**：`*.g.dart` 不入库，analyze/test/build 前必须 build_runner。
- **代码规范**：单文件 ≤1500 行、函数 ≤100 行；SOLID + DRY；public API 写 dartdoc；  
  bool 参数一律命名参数（VGA `avoid_positional_boolean_parameters`）。

## 7. 环境与生态版本（2026-09 基线）

- Flutter 3.44.1 / Dart 3.12.1 / JDK17 / VS2022；镜像 pub.flutter-io.cn。
- riverpod 3.x：无 `valueOrNull`（用 `.value`）、`Override` 类型不导出；  
  file_picker 13：`FilePicker.pickFile()` 静态方法；media_kit_video 2：  
  `controls` 传 builder；go_router 18：extra 传对象。
- workmanager 0.10.10：Android 零原生配置；`callbackDispatcher` 必须顶层函数 +  
  `@pragma('vm:entry-point')`；桌面无实现，需 `Platform.isAndroid` 守卫。
- Dart 3.12 集合支持 null-aware 元素 `?expr`（`use_null_aware_elements`  
  要求用它替代 if-null 检查）。
- 本机代理必须 `NO_PROXY=localhost,127.0.0.1`，否则 flutter test 挂（脚本已内置）。
- **widget 测试禁用 drift 活流**（StreamQueryStore 残留 Timer → 假阳性 + 连锁挂死）：  
  用 test/helpers/ 的内存 fake；**渲染频道列表的测试必须 override 六件套**  
  （channelRepositoryProvider / favoritesRepositoryProvider /  
  watchHistoryRepositoryProvider / probeResultRepositoryProvider /  
  subscriptionRepositoryProvider / epgIndexProvider）+ bootstrapProvider；  
  **app 级/设置页测试还需 override `sharedPreferencesProvider`**（app 现在读主题设置）。  
  PopupMenu/对话框流程用 `pumpAndSettle`（菜单动画 ~300ms，固定次数单帧  
  pump 会 tap miss）；纯列表渲染沿用 5 次单帧 pump。
- **Windows 构建遗留问题**：flutter 创建插件符号链接在本机崩溃（errno=2），  
  已用预建目录缓解（见 §3）；沙箱黑名单拦 reg/wmic 导致 flutter doctor  
  部分检查崩溃，属环境噪音可忽略。Android APK 构建链路已被用户验证可用。
- 本机 Bash 工具 shim 残缺（rm/ls/tail 不可用）：优先 PowerShell；  
  长输出重定向到文件（`Out-File -Encoding utf8`，默认 > 是 UTF-16 读不了）；  
  写中文提交信息文件务必用 `[System.IO.File]::WriteAllText` 无 BOM。

## 8. 常用入口

- 计划与里程碑：`docs/PLAN.md`（§8 为最新状态）
- 默认源定义：`apps/player/lib/features/subscription/domain/default_subscription.dart`
- 订阅 DI 装配：`apps/player/lib/features/subscription/application/providers.dart`
- 后台同步：`apps/player/lib/features/subscription/application/background_sync.dart`
- 频道 providers（过滤器/收藏/历史/源解析）：`apps/player/lib/features/channel/application/providers.dart`
- 自定义频道 providers：`apps/player/lib/features/channel/application/custom_channel_providers.dart`
- 检测 providers：`apps/player/lib/features/detection/application/providers.dart`
- EPG providers（索引/now-next/同步）：`apps/player/lib/features/epg/application/providers.dart`
- 录制 providers：`apps/player/lib/features/recording/application/providers.dart`
- 全局设置（主题/同步/并发/缓冲）：`apps/player/lib/core/settings/settings_providers.dart`
- drift schema：`apps/player/lib/core/database/app_database.dart`（当前 v5）
- 项目长期记忆：`.workbuddy/memory/MEMORY.md`（gitignored）
