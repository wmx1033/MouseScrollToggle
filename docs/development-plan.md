# 开发计划与交付清单

目标版本 v1.0.0；当前已交付 Phase 1 代码与最小测试，硬件验收待完成。详细需求见 requirements.md，验收步骤见 acceptance-tests.md。

- [x] 初始化 Git 与目录。
- [x] 保存原始需求全文、架构、验收规范和测试报告模板。
- [ ] Phase 1：MouseScrollToggle.swift、build.sh；分类、三类增量、权限、Event Tap、信号退出与 Debug；最小测试。通过 T01–T06、T17–T20 的相关验证。
- [ ] Phase 2：install.sh、control.sh、uninstall.sh；launchctl、健康确认、并发保护、回滚。验证 T07–T13、T15/T16、T20/T21、T25/T29/T30。
- [ ] Phase 3：自包含 shortcut-payload.sh；首次安装、版本与源码哈希、跨架构编译、iCloud 与人工导入说明。验证 T10/T11/T14/T26/T31。
- [ ] Phase 4：event-tests.swift、integration-tests.sh、doctor.sh；执行全部适用测试、兼容矩阵、性能测量及异常恢复，修复缺陷。
- [ ] Phase 5：补全实测安装使用和卸载指南，选择许可证，核对原始 DoD，发布 v1.0.0。

每阶段提交实际实现与证据；未完成项不能用占位脚本成功退出代替。实现完成后必须尝试编译与自动化测试，记录失败原因；硬件缺失记未验证。不得在初始化阶段预先勾选产品验收项。

Phase 1 进展：核心、编译脚本和 35 项检查已完成；未授权环境验证了启动失败提示。阶段勾选保留未完成，等待真实鼠标和触摸板验收。

Phase 2 代码与隔离测试完成；真实 launchctl 权限失败、停止及清理已验证。阶段验收仍待授权后的 Tap、退出登录及硬件测试；不勾选整体验收完成。Phase 3 本轮未实施。
