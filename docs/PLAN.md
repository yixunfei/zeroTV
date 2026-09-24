# zeroTV 项目计划（v1 草案）

> 状态：待评审。评审通过后进入 M0 开发。
> 最后更新：2026-09-21

---

## 0. 已确认的决策

| 决策点 | 结论 |
|---|---|
| 跨平台框架 | Flutter（稳定版 3.x / Dart 3） |
| 平台优先级 | P0：Android + Windows；P1：macOS / Linux / iOS；P2：Android TV（D-pad 适配） |
| 播放器内核 | media_kit（libmpv），全平台行为一致，支持 HLS / RTSP / UDP 组播 / 主流封装编码 |
| 应用形态 | 纯本地客户端，零后端、零账号体系 |
| 源策略 | 内置默认源（vbskycn/iptv IPv4，主地址+双镜像兜底），首次启动自动播种并同步；用户可删除/替换（2026-09-22 用户拍板，替代原"确认后添加"方案） |
| 开源许可 | 代码 GPL-3.0（防止闭源二改；media_kit/libmpv 为 LGPL，动态链接不冲突） |
| 分发渠道 | GitHub Releases 为主；F-Droid 可评估；Google Play / App Store 高风险，暂缓 |

---

## 1. 定位与原则

**定位**：开源、免费、跨平台的 IPTV 播放器，做到「专业级」—— 对标 TiviMate / IPTV Pro 的可用性，但以开放源码和本地数据主权为差异点。

**原则**：

1. **本地优先**：订阅、收藏、历史、配置全部存本地 SQLite，无遥测、无账号、无云依赖。
2. **源与播放器解耦**：App 是「播放器 + 订阅管理器」，源由用户添加。这是合规底线，也是架构上的天然边界。
3. **内核统一**：全平台只用 media_kit 一套播放栈，禁止平台特例播放器，避免行为分裂。
4. **可扩展**：订阅源解析、EPG 源、检测器均为接口化插件点，社区可扩展。
5. **工程红线**：单文件 ≤1500 行（复杂范式文件 ≤2500），单函数 ≤100 行；SOLID、DRY、高内聚低耦合。

---

## 2. 技术选型

| 层 | 选型 | 理由 |
|---|---|---|
| 状态管理 | flutter_riverpod | 编译期安全、可测试、无 BuildContext 依赖 |
| 架构 | Feature-first + 分层（presentation / application / domain / data） | domain 定义接口，data 实现，依赖倒置 |
| 本地存储 | drift（SQLite） | 类型安全 DAO、支持迁移、支持流式查询（列表自动刷新） |
| 设置存储 | shared_preferences | 简单 KV，无需加密（无敏感数据） |
| 网络 | dio + 重试拦截器 | 拦截器、超时、取消令牌齐全 |
| M3U 解析 | 自研（`packages/m3u_parser`） | M3U 属性语法坑多（tvg-* 属性、分组、多行），自研约 300 行可控可测，避免低质量三方包 |
| EPG 解析 | 自研 XMLTV 解析（支持 gzip） | XMLTV 结构简单，自研流式解析避免大文件 OOM |
| 播放 | media_kit + media_kit_video | 见决策表 |
| 后台任务 | Android: WorkManager；Windows: 应用内定时器 + 启动时同步 | Windows 无可靠后台机制，纯本地应用可接受 |
| 路由 | go_router | 声明式，桌面/移动统一 |
| 序列化 | freezed + json_serializable | 不可变模型，减少样板 |
| 国际化 | flutter_localizations + arb（中/英先行） | 开源项目的基本修养 |
| 日志 | logger + 文件滚动（可关闭） | 用户反馈 bug 时能拿到日志 |

**包体积控制**：Android 按 ABI 拆 APK（arm64-v8a / armeabi-v7a / x86_64），libmpv 只打进对应 ABI，单 APK 增量约 30~50MB。Windows 打包为 zip 便携版 + MSIX（后者可后延）。

---

## 3. 架构设计

### 3.1 仓库结构（monorepo，各包独立解析，无 melos / Pub Workspaces）

> 注：曾尝试 Dart Pub Workspaces 共享解析，但 `flutter_test` 钉死的 `test_api`
> 版本没有对应的 `test` 发行版，共享解析必然冲突，故放弃。

```
zeroTV/
├── apps/
│   └── player/                 # Flutter 应用入口（唯一 app）
├── packages/
│   ├── m3u_parser/             # M3U/M3U8 播放列表解析（纯 Dart，零 Flutter 依赖）
│   ├── xmltv_parser/           # XMLTV EPG 解析（流式，支持 .gz）
│   ├── stream_probe/           # 流可用性检测引擎（并发池、超时、降级策略）
│   └── iptv_core/              # 领域模型 + 仓库接口（domain 层，纯 Dart）
├── docs/
├── .github/workflows/          # CI / Release
└── pubspec.yaml                # 仓库根（仅工具入口，无共享解析）
```

解析器、检测器抽成**纯 Dart 包**，不依赖 Flutter —— 可直接跑在 isolate 里做后台解析，也可独立单测，未来还能发 pub.dev 反哺社区。

### 3.2 应用内分层（feature-first）

```
lib/
├── main.dart / app.dart
├── core/                       # 主题、路由、日志、错误、常量
└── features/
    ├── subscription/           # 订阅管理：添加/删除/同步/导入导出
    │   ├── presentation/       # 页面、widget、riverpod providers
    │   ├── application/        # usecase / service（编排）
    │   ├── domain/             # 实体、仓库接口（依赖倒置）
    │   └── data/               # drift DAO、dio 远程源、仓库实现
    ├── channel/                # 频道列表：分组/搜索/收藏/历史
    ├── player/                 # 播放器：OSD、多源切换、画质、音轨字幕
    ├── epg/                    # 电子节目单：订阅、解析、现在/接下来
    ├── detection/              # 可用性检测：批量检测、结果标记
    ├── recording/              # 录制与回放
    └── settings/               # 设置中心
```

**规则**：
- 跨 feature 只允许通过 `iptv_core` 的实体和接口交互，feature 之间不直接 import 对方 data 层。
- 每个 feature 内部单向依赖：presentation → application → domain ← data。
- 播放器是独立 feature，只接收「流地址 + 元数据」，不认识订阅/频道概念（接口隔离）。

### 3.3 关键接口（插件点）

```dart
abstract class SubscriptionSource {     // 订阅源协议：URL / 本地文件 / 粘贴文本
  Future<RawPlaylist> fetch();
}
abstract class PlaylistParser {         // 可扩展 TXT 分组格式等
  ParsedPlaylist parse(RawPlaylist raw);
}
abstract class StreamProber {           // 检测策略：HEAD / range-GET / ffmpeg 探测
  Future<ProbeResult> probe(String url, {Duration timeout});
}
abstract class EpgProvider {            // EPG 源插件
  Future<XmltvFeed> fetch(Uri uri);
}
```

---

## 4. 核心流程设计

### 4.1 订阅与自动同步

- 上游 vbskycn/iptv 每 6 小时更新，默认同步间隔设为 **6 小时**，可配置（1h/3h/6h/12h/24h/手动）。
- 触发点：应用启动时（距上次同步超过间隔则同步）+ 应用内定时器 + Android WorkManager 后台同步。
- 同步是**增量合并**而非全量替换：按 `tvg-id + name` 匹配，保留用户收藏、自定义排序、手动标记；上游消失的频道标记「已失效」而非直接删除（用户可一键清理）。
- 失败处理：指数退避重试 3 次 → 保留旧数据 → UI 静默标记「上次同步失败」。**永远不因同步失败清空用户数据。**
- 镜像加速：默认源地址支持 gh-proxy 镜像列表，主地址超时自动切镜像（国内直连 GitHub 不稳定是常态）。

### 4.2 可用性检测

- 检测引擎在 isolate 中运行，并发池默认 16（可配），单条超时默认 5s。
- 策略分级：TCP 连通 → HTTP HEAD（或 range-GET 前 512 字节）→ 可选深度探测（读 1 秒流验证非空）。
- 结果三态：可用（含延迟 ms）/ 超时 / 失效，列表页用颜色标记，支持「仅显示可用」过滤。
- 同一频道多源时，检测结果直接驱动播放器的 failover 顺序。
- 直播源时效性强，检测结果**标注时间戳**，超过 24h 的结果视为过期。

### 4.3 播放与多源 failover

- 播放器接收按优先级排序的源列表，当前源失败（超时/HTTP 错误/解码失败）自动切下一个，全程无需用户干预；OSD 显示「已切换到源 2/3」。
- 播放体验标配：硬件解码优先、宽高比切换、音量/亮度手势（移动端）、倍速（回放场景）、音轨/字幕轨选择、播放中锁屏。
- 缓冲策略：直播默认 2~5s 缓冲，可切「低延迟模式」（牺牲流畅换时效）。

### 4.4 EPG

- vbskycn 已于 2025.5 停止 EPG 服务，EPG 需用户另配源（XMLTV 格式，支持 .gz）。设置页提供 EPG URL 配置与示例（如社区公开 EPG）。
- 频道通过 `tvg-id` 匹配，匹配失败回退到频道名模糊匹配。
- 展示：频道列表内嵌「现在/接下来」+ 独立 EPG 时间轴页（后续里程碑）。
- 大文件（几十 MB 的 XMLTV）必须流式解析 + 进 isolate，禁止主 isolate 全量读入。

### 4.5 下载 / 录制 / 回放

先泼冷水：直播流没有「下载」概念，这个需求的真实形态是——

1. **录制**：把当前直播流落盘为 `.ts`（原样写包，不转码，零 CPU 负担），支持手动开始/停止与定时录制（依赖 EPG 时间段）。这是 M3 的核心交付。
2. **回放（时移/catchup）**：只有当源本身带 catchup 属性或提供回放地址时才可能，vbskycn 这类聚合源基本不支持。定位为「尽力而为」：检测到 catchup 参数时启用进度条拖拽，否则隐藏入口。
3. **录制文件管理**：本地列表、播放、删除、系统分享导出。

### 4.6 首次启动流程（2026-09-22 起生效）

```
首次启动（shared_preferences 标志位判定，仅运行一次）
     → 自动播种内置默认源（vbskycn/iptv IPv4，主地址 + gh-proxy/raw 双镜像）
     → 立即同步 → 进入频道列表（失败则展示错误与重试，数据永不清空）
非首次启动：跳过播种，仅同步到期订阅。
```

注意：播种条件是"从未播种过"（持久化标志），不是"订阅库为空"——
用户删除默认源（哪怕是唯一订阅）后它不会在下一次启动复活（2026-09-22 随
M2-1 修正，原实现以空库为条件会导致误复活）。已有订阅的老安装首次走到
新逻辑时直接置标志位、不插入任何数据。

默认源在数据层面就是一条普通订阅：用户可停用、删除、替换为任何其他源。
App 本体仍不存储/分发任何频道内容，只内置"指向公开列表的地址"；
免责声明保留在关于页与 README。

---

## 5. 功能范围与里程碑

### M0 — 工程骨架（预计 1 周）
- monorepo（各包独立解析，无 melos）、CI（analyze + test + 格式化门禁）、lint 规则（very_good_analysis 级）、主题骨架、go_router 空壳、drift schema v1。
- 验收：CI 绿，`flutter run` 能在 Android + Windows 起空壳。

### M1 — 核心链路：能看（预计 2 周）
- m3u_parser 包（含单测）、订阅添加（URL/本地文件/粘贴）、同步落库、分组频道列表、media_kit 播放页、单源播放。
- 验收：粘贴 vbskycn 的 M3U 地址，Android 与 Windows 双端可浏览分组列表并流畅播放。

### M2 — 数据管理：好用（预计 2~3 周）✅ 已完成（2026-09-24）
- 多订阅管理、自动同步（含 WorkManager）、增量合并、收藏、最近观看、搜索、自定义添加单个频道、stream_probe 可用性检测与标记。
- 验收：6h 自动同步不丢用户数据；500 频道批量检测 UI 不卡；收藏跨重启保留。

### M3 — 体验增强：专业（预计 3 周）
- EPG（订阅/解析/现在·接下来）、录制（手动+定时）、录制管理、多源 failover、播放器 OSD 完整版、设置中心（同步间隔/检测并发/缓冲/主题/语言）。
- 验收：EPG 匹配率 ≥80%（对公开 EPG 源）；录制 1 小时文件完整可播；kill 掉当前源 3 秒内自动切换。

### M4 — 打磨与发布（预计 2 周）
- 性能与内存压测（5000+ 频道列表滚动 60fps、长时播放内存稳定）、错误兜底审查、i18n 中英、首次启动流程、应用图标、README/截图/贡献指南、Release 工作流（tag 触发构建双端产物并上传 GitHub Releases）。
- 验收：GitHub Release 发出 v1.0.0，APK（分 ABI）+ Windows zip 可下载安装。

### M5 — 平台铺开（后续迭代）
- macOS / Linux / iOS 构建适配（media_kit 已支持，主要是签名与打包），Android TV 的 D-pad 焦点体系与大屏布局。

**里程碑之外的持续事项**：上游源地址变更跟踪、Flutter/media_kit 版本升级策略（每季度评估一次，不追最新）。

---

## 6. 合规与分发（必须直面）

- **不存储、不分发任何流媒体内容**，App 是工具。README 与关于页固定展示免责声明。
- 示例订阅仅作为「用户可自行添加的公开源之一」在文档中给出，App 内经用户明确同意后添加。
- GPL-3.0 许可证 + NOTICE 文件标注 media_kit/libmpv（LGPL）及所有三方依赖。
- 不分发含源的「预置版」安装包。任何 fork 这么做，与主仓库无关（GPL 允许 fork，但责任自负）。
- 商标风险：不使用任何电视台台标做应用图标；台标图片由订阅源提供、运行时加载，不进仓库。

## 7. 风险清单

| 风险 | 等级 | 对策 |
|---|---|---|
| 上游源域名被运营商污染 / 仓库停更 | 高 | 多镜像切换；订阅可自由替换；UI 暴露「自定义源」入口作为一等公民 |
| libmpv 包体积与杀毒软件误报（Windows） | 中 | 分 ABI 打包；发布页提供哈希；CI 产物直出不经过个人机器 |
| 5000+ 频道列表性能 | 中 | drift 流式分页 + ListView.builder + isolate 解析；M4 专项压测 |
| UDP 组播在校园网/企业网被禁 | 低 | 检测时明确标记协议类型，文档说明 |
| iOS 后台同步与审核 | 中 | iOS 属 P1；到时只做应用内同步，不上架国区 |
| EPG 源不稳定/失效 | 低 | EPG 为增强功能，失效时降级为纯频道列表，不影响播放主链路 |

---

## 8. 下一步

1. ~~你评审本计划~~ 已确认（2026-09-21）。
2. ~~M0 工程骨架~~ 已完成（2026-09-22）：仓库初始化（GPL-3.0、CI、lint 门禁）、
   四个纯 Dart 包（含解析器/检测器最小可用实现与单测）、Flutter 空壳
   （riverpod/go_router/drift schema v1）、`analyze` + 全部测试绿。
   注：依赖解析采用各包 standalone 方案，见 3.1 节注。
3. ~~M1 核心链路~~ 已完成（2026-09-22）：订阅添加（URL/文件/粘贴）→
   同步落库（失败保留旧数据）→ 分组频道列表（分组 chips + 过滤）→
   media_kit 单源播放页（UA/Referer 透传）；**内置默认源**（vbskycn IPv4 +
   双镜像，首启自动播种并同步）；drift schema v2（channels 补 catchup/UA 列）。
   analyze + 全部测试绿。遗留：本机 Windows 构建因 flutter 插件符号链接
   创建失败（环境问题，非代码问题）未做构建冒烟，Android 构建由用户侧验证。
4. ~~M2-1 多订阅管理界面~~ 已完成（2026-09-22）：管理页挂在
   `/settings/subscriptions`（列表含类型/频道数/最近同步、启停开关
   ——仅控制自动同步、改名、删除确认、单条立即同步；粘贴导入类不支持同步，
   开关与同步入口置灰）。端口新增 `rename`/`setEnabled` 靶向更新（避免
   read-modify-write 覆盖 `lastSyncedAt`）与 `watchCountsBySubscription`。
   **默认源复活修复**：seeder 改 shared_preferences 一次性标志（见 4.6）。
   analyze + 全部测试绿（app 33 例，含管理页 widget 5 例与复活回归测试）。
5. ~~M2-3 收藏与最近观看~~ 已完成（2026-09-22）：chips 行新增「收藏/最近」
   特殊分组（过滤器重构为 sealed ChannelFilter）；频道 tile 星标切换收藏；
   播放页首次 playing 时回写观看历史（播放失败不记）。新增 FavoritesRepository /
   WatchHistoryRepository 端口（按 identityKey 独立存表，同步替换不丢），
   无 schema 变更。analyze + 全部测试绿（app 43 例）。
6. ~~M2 剩余~~ 已完成（2026-09-24）：频道搜索（sealed `ChannelFilter` 加
   `FilterSearch` 分支 + AppBar 搜索模式）、上次观看恢复入口（首页「继续观看」
   横幅）、自定义添加单频道（`SubscriptionKind.manual` +「我的频道」隐式订阅 +
   FAB 双入口 + 删除确认）、stream_probe 批量检测接 UI（`probe_results` schema v3
   + 状态点 + 「可用」过滤）、后台同步（Android WorkManager 周期任务 + 桌面
   应用内定时器）。analyze + 全部测试绿（app 72 例）。**M2 全部收尾。**
7. 下一步进入 M3 — 体验增强：专业：EPG（xmltv_parser 已就绪，接端口与 UI）、
   录制（手动 + 定时，原样写 .ts）、录制管理、多源 failover、播放器 OSD 完整版、
   设置中心（同步间隔/检测并发/缓冲/主题/语言）。
