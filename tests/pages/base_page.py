from playwright.sync_api import Page


class BasePage:
    """
    BasePage is a base class for all page objects. It provides common
    methods for navigating to a page and waiting for the page to load.
    """
    def __init__(self, page: "Page", base_url: "str") -> "None":
        self.page = page
        self.base_url = base_url.rstrip("/")

    def navigate(self, path: str = "") -> None:
        """
        navigates to the specified path relative to the base URL.
        If no path is provided, it navigates to the base URL.
        """
        url = f"{self.base_url}/{path.lstrip('/')}" if path else self.base_url
        self.page.goto(url, wait_until="networkidle")

    def wait_for_load(self) -> "None":
        """
        waits for the page to load by waiting for the network to be idle. This
        is useful for pages that load content dynamically after the initial page load.
        """
        self.page.wait_for_load_state("networkidle")
