# MouseScrollToggle

macOS 普通鼠标滚轮反转工具，使用 Swift + Zsh，由一条 macOS 快捷指令手动切换，触摸板继续保持自然滚动。

**当前状态：Phase 4 诊断与测试已实施。本机真实 Tap、生命周期及用户确认的鼠标/触摸板基本功能已通过；快捷指令正常开关及显示也获用户确认；跨 Mac 同步及完整兼容/稳定性验收仍未完成，不发布 v1.0。**

## 文档导航

- [完整需求与原始开发规划](docs/requirements.md)：原文完整保留，作为需求基线。
- [架构与实现约束](docs/architecture.md)
- [开发阶段与任务清单](docs/development-plan.md)
- [验收测试规范](docs/acceptance-tests.md)
- [测试报告](docs/test-report.md)
- [安装与卸载](docs/installation.md)
- [权限说明](docs/permissions.md)
- [故障排查](docs/troubleshooting.md)
- [快捷指令集成](Shortcuts/README.md)
- [已知限制与待决策项](docs/known-limitations.md)

## 仓库布局

`Sources/` 保存 Swift 核心；`Scripts/` 保存 Zsh 控制脚本；`Shortcuts/` 保存自包含载荷与操作说明；`Tests/` 保存自动化用例；`docs/` 保存需求、设计和验收记录。已提供 Swift 核心、编译脚本与最小测试；安装和启停脚本已实现。

执行 `make help` 查看当前入口。功能开发后必须尝试编译和自动化测试，真实硬件测试单独记录，不能用模拟事件代替。

不修改全局自然滚动、不使用 sudo、不安装登录启动项、不依赖 Homebrew 或第三方 Swift 包。许可证尚未选定，当前不声明开源授权。

## Phase 1 本机开发

```sh
make build
make test
./build/mousescrolltoggle --check-permission
./build/mousescrolltoggle
# 可选逐事件诊断（仅调试时开启）
./build/mousescrolltoggle --verbose
```

首次运行可能需要在系统设置 → 隐私与安全性 → 辅助功能中手动授权后重试。前台运行，Ctrl-C 停止；可使用 Phase 2 安装及控制接口，参见 [安装指南](docs/installation.md)。核心已有跨进程单实例锁。普通模式只输出启动/错误状态，不输出每次滚动；详细模式输出到 stderr，不自动保存日志。

退出码：0 正常结束；2 未授权；3 Event Tap/RunLoop 初始化失败；4 运行中恢复失败；64 参数错误。`--check-permission` 不弹授权请求。READY 仅表示初始化；control.sh 使用独立健康挑战。

## 日常使用

```sh
make install
./Scripts/control.sh start
./Scripts/control.sh status
./Scripts/control.sh toggle
./Scripts/control.sh stop
make uninstall
```

安装不启动；首次 toggle 只开启一次。退出码、回滚和配置冲突处理见安装指南。

## 快捷指令

主要快捷指令名为 **Mouse Scroll Toggle**。执行 `make shortcut` 生成 `Shortcuts/shortcut-payload.sh`，`make check-shortcut` 检查同步。按 [创建指南](Shortcuts/README.md) 将完整载荷粘贴到一个 Zsh Shell 动作，并添加显示结果。载荷不依赖仓库、网络下载或 Homebrew。安装和切换在同一串行流程中完成，更新失败不会继续切换。

## 诊断与验收

`make doctor` 输出当前系统、权限、服务、真实 Tap 健康和恢复信息，默认隐藏用户路径；`make diagnostic-test` 运行隔离诊断回归。无仓库时可对保存的完整载荷执行 `/bin/zsh shortcut-payload.sh --doctor`，不会安装或切换。实际硬件、系统和自动化证据逐项见 [Phase 4 证据表](docs/phase4-evidence.md)，性能与兼容记录单独保存；尚不发布 v1.0。
