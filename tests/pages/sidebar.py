from playwright.sync_api import Page, Locator

from .base_page import BasePage


# MAIN_ITEMS: a list of expected main navigation items that should be present in
# the sidebar of RHDH.
MAIN_ITEMS = ["Home", "Catalog", "APIs", "Learning Paths", "Docs"]

# ADMIN_SUB_ITEMS: a list of expected sub-items that should be present under the
# "Administration" section of the sidebar when it is expanded.
ADMIN_SUB_ITEMS = ["Adoption Insights", "Extensions"]


class Sidebar(BasePage):
    """
    Sidebar is a page object that represents the sidebar navigation of RHDH. It provides
    methods for locating main navigation items and the "Administration" section, as well
    as, clicking on the "Administration" section to expand it and locating sub-items within
    the expanded "Administration" section.
    
    This allows for assertions to be made about the presence and functionality of the
    sidebar navigation, ensuring that users can easily access important sections of
    RHDH from the sidebar.
    """
    def __init__(self, page: "Page", base_url: "str") -> None:
        super().__init__(page, base_url)

    def nav_item(self, label: "str") -> "Locator":
        """
        locates a sidebar nav item by its visible label.
        """
        return self.page.locator(
            f"[data-testid='sidebar-root'] a[aria-label='{label}']"
        )

    @property
    def administration_item(self) -> "Locator":
        """
        locates the "Administration" section in the sidebar.
        """
        return self.page.locator(
            "[data-testid='sidebar-root'] button[aria-label='Administration']"
        )

    def click_administration(self) -> "None":
        """
        locates and clicks the "Administration" section in the
        sidebar to expand it, then waits.
        """
        self.administration_item.click()
        self.page.wait_for_load_state("domcontentloaded")

    def admin_sub_item(self, label: str):
        """
        locates an Administration sub-item after the section is
        expanded.
        """
        return self.page.locator(
            f"[data-testid='sidebar-root'] a[aria-label='{label}']"
        )
