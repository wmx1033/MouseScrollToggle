.PHONY: help build test integration-test install uninstall
help:
	@printf '%s\n' 'make build / test / integration-test / install / uninstall'
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
