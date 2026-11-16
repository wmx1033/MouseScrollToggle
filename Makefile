.PHONY: help build test install uninstall
help:
	@printf '%s\n' 'make build：编译 Swift 核心' 'make test：运行最小自动化测试' 'install/uninstall：Phase 2 尚未实现'
build:
	@./Scripts/build.sh
test:
	@./Tests/run-tests.sh
install uninstall:
	@printf '%s\n' '尚未实现：请参阅 docs/development-plan.md。' >&2
	@exit 2
