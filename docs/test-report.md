# 测试报告

更新日期：2026-11-16。当前阶段：Phase 2 review 修复；Phase 3 未开始。

产品结论：**Phase 1/2 代码已实现，硬件与完整产品验收未完成，不能发布 v1.0。**

| 范围 | 状态 | 说明 |
|---|---|---|
| Swift 编译 | PASS | 已有完整核心，本轮 make build 通过 |
| 自动化测试 | PASS | 35 项核心断言及 87 项扩展集成检查 |
| T01–T31 | 未验证 | 见验收测试规范 |
| 真实鼠标/触摸板 | 未验证 | 不得从模拟测试推断 |
| Apple Silicon / Intel | 未验证 | 需分别记录 |
| 快捷指令/iCloud | 未验证 | 未生成或创建快捷指令 |
| 性能/权限/生命周期 | 未验证 | 需实际测量与操作 |

## 执行记录模板

- 日期、执行人、Git 提交、载荷哈希：
- macOS / Swift / 架构 / 设备与连接方式：
- 用例编号、前置条件、步骤：
- 预期与实际结果：
- 结论：PASS / FAIL / BLOCKED / 未验证
- 证据、缺陷、复测结果：

## 历史：初始化验证

初始化当时尚无实现及测试代码；初始化检查只验证目录、需求原文一致性、文档链接与 Makefile 入口，不代表产品验收通过。具体检查结果见本次交付说明。

## Phase 1 实施记录（2026-11-16）

- 环境：Apple Silicon arm64；Swift 6.4.2，编译器目标 arm64-apple-macosx27.2.0。
- `make build`：PASS，优化编译生成 build/mousescrolltoggle。
- `make test`：PASS，35 项断言；覆盖 T17/T18 的最小事件/纯函数范围与 T19 的恢复预算部分。
- `zsh -n Scripts/build.sh Tests/run-tests.sh`：PASS。
- `--help`、`--version`：PASS。
- `--check-permission`：输出未授权；实际启动返回 2，并输出系统设置授权指引。权限失败路径符合预期。
- 实际服务未进入运行状态；T01–T06、真实 Tap 创建、禁用恢复、信号清理、权限撤销、性能和 Intel 均未验证。
- Phase 1 实现已交付，但“鼠标反转、触摸板不变”的硬件验收未完成；不宣称整个 Phase 1 验收或 v1.0 发布完成。

以上新记录更新初始化快照中编译与自动化测试的状态；其他未验证项目保持原状。

## Phase 2 实施记录（2026-11-16）

- make build：PASS；make test：PASS（35 项）；make integration-test：PASS（24 项隔离模拟检查）。
- Zsh 语法检查及 git diff --check：PASS。
- 真实系统测试：临时 HOME、独立 local.mousescrolltoggle.test.<pid>，使用实际 /bin/launchctl 和本机核心；install 成功，bootstrap 后核心报缺少辅助功能权限；start=1、status=ERROR/1；stop 与 uninstall 成功，临时目录已清理。没有修改真实用户安装。
- 未验证：健康 Tap 的真实 SIGUSR1 响应、实际单实例争用、信号释放 Tap、系统禁用恢复、权限撤销、硬件滚动、休眠、登录退出/重新登录、Intel 和性能。
- 人工步骤：授权稳定二进制，start/status 应 RUNNING；再次 start PID 应不变；直接运行第二实例应返回 5；发送 TERM 后 status 应 ERROR；再次 start 可恢复；撤销权限后查询应 ERROR；stop 后不应重启。开启后退出登录再登录，应 STOPPED；休眠唤醒、设备重连后按 T01–T06/T19/T22–T24 检查鼠标与触摸板。记录实际结果，不将此步骤表视为通过。

## Phase 2 review 回归记录

- `make build`、`make test`（35 项）、`make integration-test`（87 项）、全部脚本 Zsh 语法检查和 `git diff --check` 通过。扩展集成测试覆盖前台锁占用、陈旧 PID 不被信号终止、更新启动失败后 bootout 失败/停止超时、恢复文件失败、旧服务恢复失败、完整备份保留、执行恢复脚本及成功后清理。
- 模拟层：临时 HOME、独立服务名、mock launchctl/core；失败注入仅在 MST_TEST_MODE=1 下启用。不能据此宣称真实 Tap 或硬件通过。
- 真实核心层：同一隔离 HOME 下持有实际内核 core.lock，运行本机编译的真实核心返回 5；证明 Swift/Zsh 锁互通。该测试未创建 Tap，不属于真实健康前台实例验证。
- 仍未验证：获授权的真实前台核心持续运行与 Tap 清理、真实 launchctl 故障恢复、Tap 禁用恢复、权限撤销、鼠标/触摸板、休眠、退出登录、Intel 及性能。权限阻塞保持原记录。

- 本轮真实 launchctl 复测：临时 HOME、独立服务名、实际 launchctl 与本机编译核心。缺少辅助功能权限，start=1、status=ERROR/1；stop、uninstall 成功，临时安装和测试服务已清理。仍不表示真实 Tap 成功运行。
