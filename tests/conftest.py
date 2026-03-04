import os
import pyotp
import pytest
from playwright.sync_api import sync_playwright, Browser, BrowserContext, Page


def _require_env(name: "str") -> "str":
    """
    requires an environment variable to be set and returns
    its value. If the variable is not set, it raises an
    EnvironmentError with a message indicating which variable
    is missing and how to set it.
    """
    value = os.environ.get(name)
    if not value:
        raise EnvironmentError(
            f"Required environment variable '{name}' is not set. "
            "Set it before running the tests:\n"
            f"  export {name}=<value>"
        )
    return value


@pytest.fixture(scope="session")
def base_url() -> "str":
    """
    returns the base url of RHDH isntance we are testing
    """
    return _require_env("BASE_URL").rstrip("/")


@pytest.fixture(scope="session")
def authenticated_page(base_url: "str") -> "Page":
    """
    returns a session-scoped fixture that performs
    Red Hat SSO (Keycloak) login once and yields the
    authenticated Playwright Page for reuse across all tests.
    """
    username = _require_env("RH_USERNAME")
    password = _require_env("RH_PASSWORD")
    otp_secret = _require_env("OTP_SECRET")
    totp = pyotp.TOTP(otp_secret)
    full_password = password + totp.now()

    with sync_playwright() as playwright:
        browser: Browser = playwright.chromium.launch(
            headless=True,
            args=["--disable-blink-features=AutomationControlled"],
        )
        context: BrowserContext = browser.new_context(
            ignore_https_errors=True,
            locale="en-US",
            timezone_id="UTC",
            user_agent=(
                "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
            ),
        )
        context.add_init_script(
            "Object.defineProperty(navigator, 'webdriver', {get: () => undefined})"
        )
        page: Page = context.new_page()

        # navigate to the RHDH login page
        page.goto(base_url, wait_until="networkidle")

        # capture the SSO window as a new page in the context
        with context.expect_page() as page_info:
            page.click("button:has-text('Sign in')")

        popup = page_info.value

        # wait for the login form to appear in the SSO window
        popup.wait_for_load_state("domcontentloaded")
        popup.locator("#username").wait_for(state="visible", timeout=60000)

        # fill in credentials on the SSO form
        popup.locator("#username").fill(username)
        popup.locator("#password").fill(full_password)

        # submit and wait for the navigation that follows
        with popup.expect_navigation(wait_until="domcontentloaded"):
            popup.locator("input#submit").click()

        # some flows close the popup, others keep it open and redirect
        try:
            popup.wait_for_event("close", timeout=30000)
        except Exception:
            pass

        # wait for the main page to finish loading after authentication
        page.wait_for_load_state("networkidle")

        # close the quickstart guide if it is present
        try:
            hide_btn = page.locator("button:text-is('Hide')")
            hide_btn.wait_for(state="visible", timeout=5000)
            hide_btn.click()
        except Exception:
            pass

        yield page

        context.close()
        browser.close()
