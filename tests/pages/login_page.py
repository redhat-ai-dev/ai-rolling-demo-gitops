from playwright.sync_api import Page, Locator

from .base_page import BasePage

# EXPECTED_INFO_BANNER: the expected text content of the info banner
# shown on the login page before authentication.
EXPECTED_INFO_BANNER = (
    "If this is your first time logging in, you may see the error"
    ' "Failed to sign-in, unable to resolve user identity".'
    " Please wait a few minutes and try again since it will take"
    " some time for the registration to complete."
)

# EXPECTED_TITLE: the expected title of the login page.
EXPECTED_TITLE = "AI Rolling Demo Developer Hub"

# EXPECTED_SSO_HEADING: the expected text content of the heading in the
# sign-in panel.
EXPECTED_SSO_HEADING = "Red Hat SSO"

# EXPECTED_SSO_SIGN_IN_TEXT: the expected text content of the label
# for signing in using Red Hat SSO.
EXPECTED_SSO_SIGN_IN_TEXT = "Sign in using Red Hat SSO"


class LoginPage(BasePage):
    """
    LoginPage is a page object that represents the login page of RHDH. It provides
    methods for navigating to the login page and retrieving information about the
    info banner, page title, and sign-in panel. This allows for assertions to be
    made about the content and structure of the login page, ensuring that it meets
    the expected design and provides the necessary information for users to log in
    successfully.
    """
    def __init__(self, page: "Page", base_url: "str") -> "None":
        super().__init__(page, base_url)

    @property
    def info_banner(self) -> "Locator":
        """
        retrieves a top-level info/warning banner shown before authentication.
        """
        return self.page.locator(".MuiAlert-message")

    @property
    def page_title(self) -> "str":
        """
        retrieves the title of the login page.
        """
        return self.page.locator("h1.MuiTypography-h1-30").inner_text()

    @property
    def sso_panel_heading(self) -> "Locator":
        """
        retrieves the 'Red Hat SSO' heading inside the sign-in panel.
        """
        return self.page.locator("span.MuiCardHeader-title-203")

    @property
    def sso_sign_in_text(self) -> "Locator":
        """
        retrieves the 'Sign in using Red Hat SSO' label.
        """
        return self.page.locator("p.MuiTypography-body1-27")
