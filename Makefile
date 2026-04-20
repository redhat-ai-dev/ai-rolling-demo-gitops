.PHONY: install install-no-rhoai tests

install:
	bash setup.sh

install-no-rhoai:
	SKIP_RHOAI_SETUP=true bash setup.sh

tests:
	bash scripts/run-tests.sh
