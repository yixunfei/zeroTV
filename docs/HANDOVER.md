# zeroTV 接手开发（Handover ）

> 生成时间：2026-09-22（M2-3 完成后刷新）。将本文件全文提供给下一会话即可无缝接手。  
> 本文件描述的是"当前真实状态"，与 docs/PLAN.md（长期计划）互补；冲突时以代码为准。

## 0. 接手第一件事

**M2-3 已完成、质量门全绿、但尚未提交。** 进入会话后先确认工作树状态，  
按里程碑粒度提交（建议信息：`feat: M2-3 收藏与最近观看`），再开新任务。  
中文提交信息必须用 `git commit -F <utf8文件>`，HEREDOC 会乱码。

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
- **M2-1 多订阅管理（commit dd62c89）**：
  - 管理页 `/settings/subscriptions`（settings 页入口）：列表（类型/频道数/  
    最近同步）、启停（仅停自动同步，频道仍可见）、改名、删除确认、单条立即同步；  
    粘贴导入类不支持同步，开关与入口置灰。
  - 端口新增 `rename`/`setEnabled` 靶向更新与 `watchCountsBySubscription`。
  - **默认源复活修复**：seeder 改 shared_preferences 一次性标志  
    （`DefaultSourceSeeder.seededKey`），用户删除默认源不再复活；  
    main.dart 为 async 并 override `sharedPreferencesProvider`。
- **M2-3 收藏与最近观看（未提交）**：
  - 过滤器重构为 sealed `ChannelFilter`（All/Favorites/Recent/Group），  
    chips 行新增「收藏/最近」特殊分组。
  - 频道 tile 星标切换收藏（`ToggleFavorite` 用例 + `FavoritesRepository`）。
  - 观看历史：播放页首次 `playing` 事件回写（播放失败不记）；  
    `WatchHistoryRepository.watchRecent` 按 identityKey 去重取最新，limit 50。
  - 收藏/历史按 `Channel.identityKey` 独立存表，同步整表替换不丢；无 schema 变更。

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
- 当前状态：全绿（最近一次全量验证 2026-09-22，app 43 例）。

## 5. 下一步待办（M2 剩余，按优先级）

1. WorkManager 后台同步（Android）+ Windows 启动时同步补齐。
2. 频道搜索（本地 LIKE；ChannelFilter 已是 sealed，加分支即可）。
3. 自定义添加单频道。
4. stream_probe 批量可用性检测与列表标记（引擎已在 packages/stream_probe，接 UI）。
5. 播放历史驱动"上次观看"恢复（历史已在记录，只差入口）。

更远：M3（多源聚合 failover、探测优先选源）、M4（EPG、平板/TV/遥控器、录制）、  
M5（性能压测、i18n、图标、Release 工作流含 Android 签名配置）。

## 6. 关键架构约束（违者必踩坑）

- **依赖解析 standalone**：禁止 Pub Workspaces/melos 共享解析  
  （flutter_test 钉死 test_api 0.7.11，与 test>=1.31 必然冲突）。  
  每目录单独 pub get；库包不提交 lockfile（已 gitignore）。
- **分层**：feature-first + data/application/presentation；领域实体与端口接口  
  在 iptv_core（纯 Dart，禁止 import flutter/*）。
- **drift 生成类型一律 `as db` 前缀**：行类与领域实体同名（Subscription/Channel），  
  Companion 也必须 `db.XxxCompanion.insert(...)`；data 层通常无需 import drift  
  本体，除非用到 OrderingTerm / 聚合（.max()/.count()）。
- **仓储更新走靶向方法**：rename/setEnabled/markSynced 模式（SQL UPDATE 单字段），  
  禁止 read-modify-write 整对象 upsert（会覆盖 lastSyncedAt 等并发字段）。
- **端口接口是刻意的单方法抽象**：`one_member_abstracts` 已在根 lint 禁用；  
  `prefer_initializing_formals` 同样禁用（误报）。勿为凑 lint 重构。
- **同步语义**：任何同步失败不得清空已存频道；收藏/历史不得挂 channels 表，  
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
- Dart 3.12 集合支持 null-aware 元素 `?expr`（`use_null_aware_elements`  
  要求用它替代 if-null 检查）。
- 本机代理必须 `NO_PROXY=localhost,127.0.0.1`，否则 flutter test 挂（脚本已内置）。
- **widget 测试禁用 drift 活流**（StreamQueryStore 残留 Timer → 假阳性 + 连锁挂死）：  
  用 test/helpers/ 的内存 fake；**渲染频道列表的测试必须 override 三件套**  
  （channelRepositoryProvider / favoritesRepositoryProvider /  
  watchHistoryRepositoryProvider）+ bootstrapProvider。  
  PopupMenu/对话框流程用 `pumpAndSettle`（菜单动画 ~300ms，固定次数单帧  
  pump 会 tap miss）；纯列表渲染沿用 5 次单帧 pump。
- **Windows 构建遗留问题**：flutter 创建插件符号链接在本机崩溃（errno=2），  
  已用预建目录缓解（见 §3）；沙箱黑名单拦 reg/wmic 导致 flutter doctor  
  部分检查崩溃，属环境噪音可忽略。Android APK 构建链路已被用户验证可用。
- 本机 Bash 工具 shim 残缺（rm/ls/tail 不可用）：优先 PowerShell；  
  长输出重定向到文件（`Out-File -Encoding utf8`，默认 > 是 UTF-16 读不了）。

## 8. 常用入口

- 计划与里程碑：`docs/PLAN.md`（§8 为最新状态）
- 默认源定义：`apps/player/lib/features/subscription/domain/default_subscription.dart`
- 订阅 DI 装配：`apps/player/lib/features/subscription/application/providers.dart`
- 频道 providers（过滤器/收藏/历史）：`apps/player/lib/features/channel/application/providers.dart`
- 项目长期记忆：`.workbuddy/memory/MEMORY.md`（gitignored）
