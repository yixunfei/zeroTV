# 贡献指南

感谢你考虑为 zeroTV 贡献代码。这是一个本地优先、零后端、零遥测的开源 IPTV
播放器；改动只要不违背这三条底线，都欢迎讨论。

## 提交前必跑的质量门

CI（`.github/workflows/ci.yaml`）对每个 PR 执行以下检查，本地提前跑一遍可以
省一个来回：

```powershell
# 一键等价物（Windows；含依赖解析 + 代码生成 + 格式 + 分析 + 全部测试）
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_tests.ps1
```

手动等价物（任意平台）：

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze                      # 在仓库根目录
for pkg in packages/*; do (cd "$pkg" && dart test); done
(cd apps/player && flutter test)
```

任一步失败请先修复再提交；CI 会以完全相同的顺序拦截。

## 代码约定

- **质量门**：`very_good_analysis`（见根 `analysis_options.yaml`），公开 API
  需 dartdoc；单文件 ≤1500 行、函数 ≤100 行；bool 参数一律命名参数。
- **生成代码不入库**：`*.g.dart`（drift）与 `lib/l10n/generated/` 由
  build_runner / gen-l10n 生成，已在 `.gitignore` 排除。clone 后先跑
  `scripts\run_tests.ps1`（或手动 `dart run build_runner build` +
  `flutter gen-l10n`）再打开 IDE，否则满屏红。
- **分层**：feature-first，`features/<feature>/{presentation,application,data}`；
  领域实体与端口接口放在 `packages/iptv_core`（纯 Dart，禁止 import
  flutter）。数据层仓储更新走靶向方法（如 `markSynced`），不要
  read-modify-write 整对象 upsert。
- **依赖解析**：各包 standalone `pub get`，不使用 Pub Workspaces/melos
  （flutter_test 与 test 的版本约束在共享解析下必然冲突）。只有
  `apps/player` 提交 lockfile。
- **错误文案**：数据层抛类型化异常（携带机器可读 reason），展示层经
  `localizedErrorText` 翻译；不要在数据层硬编码任何自然语言的用户可见
  文案。UI 文案一律进 ARB（`app_zh.arb` 为模板，`app_en.arb` 同步更新）。
- **测试**：widget 测试禁用 drift 活流（残留 Timer 造成假阳性），用
  `test/helpers/` 的内存 fake 覆盖 provider；渲染频道列表的测试须 override
  全部仓储 provider + `sharedPreferencesProvider`。PopupMenu/对话框流程用
  `pumpAndSettle`，纯列表渲染用固定次数单帧 pump。

## 测试与验证期望

- 新功能附带测试；bug 修复先写一个能复现的失败测试再修。
- 涉及播放/录制的改动在真机或模拟器上冒烟（见
  [`scripts/README.md`](scripts/README.md) 的集成测试章节）；CI 没有显示
  设备，视频相关回归只在本地有意义的跑。

## 提交与 PR

- 提交信息用中文或英文均可，格式 `类型: 摘要`（feat / fix / docs /
  refactor / chore），正文说清动机与验证结果。
- PR 请保持单一主题；CI 绿是合并底线。
- 涉及数据库 schema 的改动需要 `apps/player/lib/core/database/app_database.dart`
  的迁移分支（`schemaVersion` 递增 + `onUpgrade` 补丁），并在
  `test/features/**/drift_*_test.dart` 补迁移覆盖。

## 报告问题

提 issue 时请附：平台与版本、复现步骤、预期与实际行为。频道源本身的可用性
问题（哪个台看不到了）请先向对应订阅源的上游反馈——zeroTV 不托管、不分发
任何频道内容。
