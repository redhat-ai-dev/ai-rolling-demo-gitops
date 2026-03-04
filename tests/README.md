# AI Rolling Demo Testing Suite

Testing Suite for E2E tests on UI of AI Rolling Demo. The current directory
is used by our nightly tests to verify that specific parts of our RHDH
instance (deployed by our gitops environment) works and behaves as expected.

## Prerequisites

- [uv](https://docs.astral.sh/uv/) installed (`pip install uv` or via the official installer)

## Setup

```bash
cd tests
uv sync
uv run playwright install chromium
```

## Required Environment Variables

| Variable      | Description                                     | Example                              |
| ------------- | ----------------------------------------------- | ------------------------------------ |
| `BASE_URL`    | Root URL of the RHDH instance (no trailing `/`) | `https://rolling-demo-backstage-...` |
| `RH_USERNAME` | Red Hat SSO username                            | `demo-user`                          |
| `RH_PASSWORD` | Red Hat SSO password                            | `s3cr3t`                             |
| `OTP_SECRET`  | OTP Secret in Base32                            | `s3cr3t`                             |

Export them before running tests:

```bash
export BASE_URL=https://rolling-demo-backstage-rolling-demo-ns.apps.example.com
export RH_USERNAME=demo-user
export RH_PASSWORD=s3cr3t
export OTP_SECRET=s3cr3t
```

## Running Tests

```bash
# All tests
uv run pytest -v

# Smoke tests only (no authentication required)
uv run pytest -m smoke -v

# Login page tests only
uv run pytest test_login.py -v
```
