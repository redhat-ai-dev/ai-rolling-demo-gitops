import pytest

from playwright.sync_api import Page

from pages.sidebar import Sidebar, MAIN_ITEMS, ADMIN_SUB_ITEMS


@pytest.fixture(scope="module")
def sidebar(authenticated_page: "Page", base_url: "str") -> "Sidebar":
    sb = Sidebar(authenticated_page, base_url)
    sb.navigate()
    sb.wait_for_load()
    return sb


@pytest.mark.auth_required
@pytest.mark.parametrize("item_label", MAIN_ITEMS)
def test_sidebar_main_item_visible(sidebar: "Sidebar", item_label: "str") -> "None":
    item = sidebar.nav_item(item_label)
    assert item.is_visible(), f"Sidebar should contain main nav item '{item_label}'"


@pytest.mark.auth_required
def test_sidebar_administration_item_visible(sidebar: "Sidebar") -> "None":
    assert sidebar.administration_item.is_visible(), (
        "Sidebar should contain an 'Administration' item"
    )


@pytest.mark.auth_required
@pytest.mark.parametrize("sub_label", ADMIN_SUB_ITEMS)
def test_sidebar_administration_sub_items(sidebar: "Sidebar", sub_label: "str") -> "None":
    sidebar.click_administration()
    sub_item = sidebar.admin_sub_item(sub_label)
    assert sub_item.is_visible(), (
        f"After clicking Administration, sub-item '{sub_label}' should be visible"
    )
