from playwright.sync_api import Page, Locator

from .base_page import BasePage


# APP_LAUNCHER_ITEMS: a list of expected application launcher items
# that should be present in the dropdown menu when the application
# launcher button is clicked.
APP_LAUNCHER_ITEMS = [
    "Developer Hub",
    "Openshift AI Docs",
    "RHDH Local",
    "RHDH Dynamic Plugin Factory",
    "RHDH CLI",
    "MCP Tools Guide",
    "Openshift AI",
]

class NavBar(BasePage):
    """
    NavBar is a page object that represents the navigation bar of RHDH.
    It provides properties for accessing common elements in the nav bar
    such as the logo, search input, self-service icon, application
    launcher, and help icon.
    
    It also provides a method for opening the application launcher
    dropdown and retrieving items from it. This allows for assertions
    to be made about the presence and functionality of these common
    nav bar elements, ensuring that users can easily navigate and
    access important features of RHDH from the nav bar.
    """
    def __init__(self, page: "Page", base_url: "str") -> "None":
        super().__init__(page, base_url)

    @property
    def rhdh_logo(self) -> "Locator":
        """
        retrieves the Red Hat Developer Hub logo in the top-left
        of the nav bar.
        """
        return self.page.locator("[data-testid='global-header-company-logo'] a[aria-label='Home']")

    @property
    def search_input(self) -> "Locator":
        """
        locates the Global search field.
        """
        return self.page.locator("input[placeholder='Search...']")

    @property
    def self_service_icon(self) -> "Locator":
        """
        locates the Self-service icon button (tooltip: 'self-service').
        """
        return self.page.locator("a[aria-label='Self-service']")

    @property
    def app_launcher_button(self) -> "Locator":
        """
        locates the Application launcher (grid/waffle) icon that opens
        the dropdown.
        """
        return self.page.locator("button[aria-label='Application launcher']")

    def open_app_launcher(self) -> "None":
        """
        opens the application launcher dropdown menu by clicking
        the app launcher button and waiting for the dropdown menu
        to be visible.
        """
        # close any leftover open menu before clicking
        self.page.keyboard.press("Escape")

        btn = self.app_launcher_button
        btn.wait_for(state="visible")
        btn.click()

        # MUI sets aria-labelledby=<button id> on the menu — use that to
        # pick the correct ul[role='menu'] out of potentially many in the DOM
        btn_id = btn.get_attribute("id")
        if btn_id:
            menu = self.page.locator(f"ul[role='menu'][aria-labelledby='{btn_id}']")
        else:
            menu = self.page.locator("ul[role='menu']").filter(
                has=self.page.locator(":visible")
            ).first

        menu.wait_for(state="visible", timeout=10000)

    def app_launcher_item(self, label: "str") -> "Locator":
        """
        locates an item in the application launcher dropdown
        menu by its label.
        """
        btn_id = self.app_launcher_button.get_attribute("id")
        if btn_id:
            menu = self.page.locator(f"ul[role='menu'][aria-labelledby='{btn_id}']")
        else:
            menu = self.page.locator("ul[role='menu']").filter(
                has=self.page.locator(":visible")
            ).first
        return menu.locator(f"a[role='menuitem']:has(p:text-is('{label}'))")

    @property
    def help_icon(self) -> "Locator":
        """
        locates Help icon button (tooltip: 'Help').
        """
        return self.page.locator(
            "[aria-label='Help'], [title='Help']"
        ).first
