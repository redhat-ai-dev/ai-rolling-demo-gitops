.PHONY: install install-no-rhoai tests ci-install ci-tests

install:
	bash setup.sh

install-no-rhoai:
	SKIP_RHOAI_SETUP=true bash setup.sh

tests:
	bash scripts/run-tests.sh

ci-install:
	bash scripts/ci-setup.sh

ci-tests:
	bash scripts/ci-run-tests.sh
