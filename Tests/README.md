# 测试

`make test` 保留 35 项 Swift 合成事件/恢复预算检查。`make integration-test` 执行 87 项扩展隔离检查：临时 HOME（包含空格与 &）、仓库副本、mock launchctl/core，不修改真实安装。覆盖安装幂等、版本变化、配置冲突、编译失败、回滚及旧服务恢复失败报告、启停幂等、首次 toggle、并发 start、暂停核心及陈旧响应、运行中卸载、重复卸载、未知文件保护与无 LaunchAgents。

模拟通过不证明真实 launchctl 或 Tap 行为。真实测试与人工步骤见 docs/test-report.md。

Review 回归新增完整恢复失败矩阵及恢复脚本实执行、前台锁占用阻止操作、陈旧 PID 不发信号与真实核心返回 5。真实核心锁检查与模拟 launchctl 测试分开解释，详见测试报告。

`make shortcut-test` 的 64 项检查使用共享 mock-runtime.sh 适配器覆盖确定性生成、一致性、Shell 语法、离仓库执行、特殊字符路径、首次点击、连续点击、版本/核心/脚本更新、编译/启动失败、跨临时目录恢复、未完成事务、旧版本拒绝及整次点击并发。明确使用临时 HOME、独立服务名；不证明 UI/iCloud 或硬件验收。`make check-shortcut` 逐字节检查生成产物是否过期。
