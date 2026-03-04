from playwright.sync_api import Page, Locator

from .base_page import BasePage

# CATALOG_PLUGIN_SAMPLE: should be a plugin that is expected to be
# present in the catalog list.
CATALOG_PLUGIN_SAMPLE = "Adoption Insights for Red Hat Developer Hub"

# INSTALLED_PACKAGE_SAMPLE: should be a package that is expected to be
# present in the installed packages list.
INSTALLED_PACKAGE_SAMPLE = "@backstage/plugin-mcp-actions-backend"


class ExtensionsPage(BasePage):
    """
    ExtensionsPage is a page object that represents the extensions page of
    RHDH. Provides methods for navigating to the extensions page, interacting
    with the catalog and installed packages tabs, as well as, retrieving
    information about the available catalog plugins and installed packages.
    """
    def __init__(self, page: "Page", base_url: "str") -> "None":
        super().__init__(page, base_url)

    def navigate_to_extensions(self) -> "None":
        self.navigate("/extensions")

    @property
    def catalog_tab(self) -> "Locator":
        """
        the locator for the "catalog" tab.
        """
        return self.page.locator("a[role='tab'][data-testid='header-tab-0']")

    def click_catalog_tab(self) -> "None":
        """
        performs a click action on the "catalog" tab and waits for
        the page to load. This is necessary because clicking the tab
        may trigger a page update or navigation, and we want to ensure
        that the page is fully loaded before proceeding with any
        further actions or assertions.
        """
        self.catalog_tab.click()
        self.page.wait_for_load_state("domcontentloaded")

    @property
    def plugin_list(self) -> "Locator":
        """
        lists available catalog plugins.
        """
        return self.page.locator(
            "[data-testid='plugin-list'], ul[class*='plugin'], div[class*='catalog']"
        ).first

    def catalog_plugin(self, name: "str") -> "Locator":
        """
        retrieves a specific plugin from the catalog list by its name. It
        looks for an element that contains the text matching the provided
        name.
        """
        return self.page.locator(f"h6.v5-MuiTypography-subtitle1:text-is('{name}')")

    @property
    def installed_packages_tab(self) -> "Locator":
        """
        retrieves the locator for the "installed packages" tab.
        """
        return self.page.locator("a[role='tab'][data-testid='header-tab-1']")

    def click_installed_packages_tab(self) -> "None":
        """
        navigates directly to the installed packages URL and waits
        for the table body to be attached to the DOM.
        """
        self.navigate("/extensions/installed-packages")
        self.page.locator("tbody tr td[value]").first.wait_for(
            state="attached", timeout=15000
        )

    @property
    def installed_packages_list(self) -> "Locator":
        """
        retrieves the locator for the list of installed packages. It
        looks for an element that has a data-testid of "installed-list",
        or a ul or div element with a class that contains "installed".
        """
        return self.page.locator(
            "[data-testid='installed-list'], ul[class*='installed'], div[class*='installed']"
        ).first

    def installed_package(self, name: "str") -> "Locator":
        """
        retrieves a specific package from the installed packages list
        by its name. Matches the first table cell whose text content
        equals the package name.
        """
        return self.page.locator(f"tbody tr:has-text('{name}')")
