.PHONY: install install-no-rhoai install-kserve-catalog-bridge-rhoai-handled-separately install-kserve-kind tests ci-install ci-tests

install:
	bash setup.sh

install-no-rhoai:
	SKIP_RHOAI_SETUP=true bash setup.sh

install-kserve-catalog-bridge-rhoai-handled-separately:
	SKIP_RHOAI_SETUP=true RHOAI_PREINSTALLED=true bash setup.sh

# Upstream KServe (RawDeployment) on an existing Kind cluster — RHIDP-17561.
install-kserve-kind:
	bash scripts/install-kserve-kind.sh

tests:
	bash scripts/run-tests.sh

ci-install:
	bash scripts/ci-setup.sh

ci-tests:
	bash scripts/ci-run-tests.sh
