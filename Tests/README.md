# 测试

`make test` 保留 35 项 Swift 合成事件/恢复预算检查。`make integration-test` 执行 87 项扩展隔离检查：临时 HOME（包含空格与 &）、仓库副本、mock launchctl/core，不修改真实安装。覆盖安装幂等、版本变化、配置冲突、编译失败、回滚及旧服务恢复失败报告、启停幂等、首次 toggle、并发 start、暂停核心及陈旧响应、运行中卸载、重复卸载、未知文件保护与无 LaunchAgents。

模拟通过不证明真实 launchctl 或 Tap 行为。真实测试与人工步骤见 docs/test-report.md。

Review 回归新增完整恢复失败矩阵及恢复脚本实执行、前台锁占用阻止操作、陈旧 PID 不发信号与真实核心返回 5。真实核心锁检查与模拟 launchctl 测试分开解释，详见测试报告。
