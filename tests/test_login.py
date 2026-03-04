from typing import Any
import pytest
from playwright.sync_api import sync_playwright

from pages.login_page import (
    LoginPage,
    EXPECTED_TITLE,
    EXPECTED_SSO_HEADING,
    EXPECTED_SSO_SIGN_IN_TEXT,
)


@pytest.fixture(scope="module")
def login_page(base_url: "str") -> "Any":
    """
    opens the app root without authenticating so the login page is shown.
    """
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        context = browser.new_context(ignore_https_errors=True)
        page = context.new_page()
        page.goto(base_url, wait_until="networkidle")
        lp = LoginPage(page, base_url)
        yield lp
        context.close()
        browser.close()


@pytest.mark.smoke
def test_login_page_title(login_page: "LoginPage") -> "None":
    assert EXPECTED_TITLE in login_page.page_title, (
        f"Expected title to contain '{EXPECTED_TITLE}', got '{login_page.page_title}'"
    )


@pytest.mark.smoke
def test_login_info_banner_visible(login_page: "LoginPage") -> "None":
    banner = login_page.info_banner
    assert banner.is_visible(), "Info/warning banner should be visible on the login page"


@pytest.mark.smoke
def test_login_info_banner_text(login_page: "LoginPage") -> "None":
    banner = login_page.info_banner
    assert banner.is_visible(), "Info/warning banner should be visible"
    actual_text = banner.inner_text()

    # allow partial match to be resilient to minor whitespace differences
    assert "Failed to sign-in, unable to resolve user identity" in actual_text, (
        f"Banner text did not contain expected message. Got:\n{actual_text}"
    )


@pytest.mark.smoke
def test_sso_panel_heading(login_page: "LoginPage") -> "None":
    heading = login_page.sso_panel_heading
    assert heading.is_visible(), f"Expected SSO panel heading '{EXPECTED_SSO_HEADING}' to be visible"


@pytest.mark.smoke
def test_sso_sign_in_text(login_page: "LoginPage") -> "None":
    sign_in = login_page.sso_sign_in_text
    assert sign_in.is_visible(), (
        f"Expected sign-in text '{EXPECTED_SSO_SIGN_IN_TEXT}' to be visible"
    )