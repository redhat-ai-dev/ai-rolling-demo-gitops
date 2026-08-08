.PHONY: install install-no-rhoai install-kserve-catalog-bridge-rhoai-handled-separately tests ci-install ci-tests

install:
	bash setup.sh

install-no-rhoai:
	SKIP_RHOAI_SETUP=true bash setup.sh

install-kserve-catalog-bridge-rhoai-handled-separately:
	SKIP_RHOAI_SETUP=true RHOAI_PREINSTALLED=true bash setup.sh

tests:
	bash scripts/run-tests.sh

ci-install:
	bash scripts/ci-setup.sh

ci-tests:
	bash scripts/ci-run-tests.sh
