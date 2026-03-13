import pytest

from playwright.sync_api import Page

from pages.nav_bar import NavBar, APP_LAUNCHER_ITEMS


@pytest.fixture(scope="module")
def navbar(authenticated_page: "Page", base_url: "str") -> "NavBar":
    nb = NavBar(authenticated_page, base_url)
    nb.navigate()
    nb.wait_for_load()
    return nb


@pytest.mark.auth_required
def test_rhdh_logo_visible(navbar: "NavBar") -> "None":
    assert navbar.rhdh_logo.is_visible(), "RHDH logo should be visible in the nav bar"


@pytest.mark.auth_required
def test_search_input_visible(navbar: "NavBar") -> "None":
    assert navbar.search_input.is_visible(), "Search input should be visible in the nav bar"


@pytest.mark.auth_required
def test_search_input_placeholder(navbar: "NavBar") -> "None":
    placeholder = navbar.search_input.get_attribute("placeholder")
    assert placeholder == "Search...", (
        f"Search input placeholder should be 'Search...', got '{placeholder}'"
    )


@pytest.mark.auth_required
def test_self_service_icon_visible(navbar: "NavBar") -> "None":
    assert navbar.self_service_icon.is_visible(), (
        "Self-service icon should be visible. Check aria-label or title='self-service'."
    )


@pytest.mark.auth_required
def test_app_launcher_button_visible(navbar: "NavBar") -> "None":
    assert navbar.app_launcher_button.is_visible(), "App launcher button should be visible"


@pytest.mark.auth_required
@pytest.mark.parametrize("item_label", APP_LAUNCHER_ITEMS)
def test_app_launcher_contains_item(
    navbar: "NavBar", item_label: "str"
) -> "None":
    navbar.open_app_launcher()
    item = navbar.app_launcher_item(item_label)
    assert item.is_visible(), f"App launcher should contain item '{item_label}'"


@pytest.mark.auth_required
def test_help_icon_visible(navbar: "NavBar") -> "None":
    assert navbar.help_icon.is_visible(), (
        "Help icon should be visible. Check aria-label or title='Help'."
    )
