.PHONY: install tests

install:
	bash setup.sh

tests:
	bash scripts/run-tests.sh
