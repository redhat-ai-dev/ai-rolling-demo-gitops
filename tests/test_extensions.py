import pytest

from playwright.sync_api import Page

from pages.extensions_page import (
    ExtensionsPage,
    CATALOG_PLUGIN_SAMPLE,
    INSTALLED_PACKAGE_SAMPLE,
)


@pytest.fixture(scope="module")
def extensions(authenticated_page: "Page", base_url: "str") -> "ExtensionsPage":
    """
    returns an instance of the ExtensionsPage page object, navigated to
    the extensions page and ready for testing.
    """
    ep = ExtensionsPage(authenticated_page, base_url)
    ep.navigate_to_extensions()
    ep.wait_for_load()
    return ep


@pytest.mark.auth_required
def test_extensions_catalog_tab_visible(extensions: "ExtensionsPage") -> "None":
    assert extensions.catalog_tab.is_visible(), (
        "Extensions 'catalog' tab should be visible"
    )

@pytest.mark.auth_required
def test_extensions_catalog_lists_plugins(extensions: "ExtensionsPage") -> "None":
    extensions.click_catalog_tab()
    plugin = extensions.catalog_plugin(CATALOG_PLUGIN_SAMPLE)
    assert plugin.is_visible(), (
        f"Catalog tab should list at least '{CATALOG_PLUGIN_SAMPLE}'"
    )


@pytest.mark.auth_required
def test_extensions_installed_packages_tab_visible(
    extensions: "ExtensionsPage"
) -> "None":
    assert extensions.installed_packages_tab.is_visible(), (
        "Extensions 'installed packages' tab should be visible"
    )


@pytest.mark.auth_required
def test_extensions_installed_packages_lists_packages(
    extensions: "ExtensionsPage"
) -> "None":
    extensions.click_installed_packages_tab()
    package = extensions.installed_package(INSTALLED_PACKAGE_SAMPLE)
    assert package.count() > 0, (
        f"Installed packages tab should list '{INSTALLED_PACKAGE_SAMPLE}'"
    )
