.PHONY: doctor diagnostic-test cleanup-test help build test integration-test install uninstall shortcut check-shortcut shortcut-test
help:
	@printf '%s\n' 'make build / test / integration-test / shortcut-test / shortcut / check-shortcut / doctor / diagnostic-test / cleanup-test / install / uninstall'
build:
	@./Scripts/build.sh
test:
	@./Tests/run-tests.sh
integration-test:
	@./Tests/integration-tests.sh
install:
	@./Scripts/install.sh
uninstall:
	@./Scripts/uninstall.sh

shortcut:
	@./Scripts/generate-shortcut.sh
check-shortcut:
	@./Scripts/generate-shortcut.sh --check
shortcut-test:
	@./Tests/shortcut-tests.sh

doctor:
	@./Scripts/doctor.sh
diagnostic-test:
	@./Tests/doctor-tests.sh

cleanup-test:
	@./Tests/cleanup-tests.sh
