import os
import urllib.parse

import requests
import pytest
from playwright.sync_api import sync_playwright, Browser, BrowserContext, Page


# RHDH_BASE_URL: the base URL of the RHDH instance to test, e.g.
# "https://rhdh.example.com"
RHDH_BASE_URL = os.getenv("RHDH_BASE_URL")

# RHDH_ENVIRONMENT: the environment name to use when authenticating
RHDH_ENVIRONMENT = os.getenv("RHDH_ENVIRONMENT")

# PLAYWRIGHT_HEADLESS: controls whether the browser runs in headless mode.
# Set to "false" to run with a visible browser window. Defaults to True.
PLAYWRIGHT_HEADLESS = os.getenv("PLAYWRIGHT_HEADLESS", "true").lower() != "false"

# ROLLING_DEMO_TEST_USERNAME: the username of a test user with permissions
# to access the RHDH instance for testing purposes.
ROLLING_DEMO_TEST_USERNAME = os.getenv("ROLLING_DEMO_TEST_USERNAME")

# KEYCLOAK_CLIENT_ID: the client ID of the Keycloak client used for
# authentication in the tests.
KEYCLOAK_CLIENT_ID = os.getenv("KEYCLOAK_CLIENT_ID")

# KEYCLOAK_CLIENT_SECRET: the client secret of the Keycloak client used
# for authentication in the tests.
KEYCLOAK_CLIENT_SECRET = os.getenv("KEYCLOAK_CLIENT_SECRET")

class KeycloakRealm:
    """
    KeycloakRealm represents a Keycloak realm and provides methods to
    interact with it, such as authenticating a given test user through
    the auth flow.
    """
    def __init__(
        self,
        rhdh_base_url: "str" = RHDH_BASE_URL,
        rhdh_env: "str" = RHDH_ENVIRONMENT,
        username: "str" = ROLLING_DEMO_TEST_USERNAME,
        client_id: "str" = KEYCLOAK_CLIENT_ID,
        client_secret: "str" = KEYCLOAK_CLIENT_SECRET,
    ) -> None:
        # client creds
        self.client_id = client_id
        self.client_secret = client_secret
        self.username = username

        # base url of RHDH
        self.rhdh_base_url = rhdh_base_url

        # initialize the session which will authenticate in keycloak.
        self.session = requests.Session()
        self.session.verify = False

        # basic keycloak info
        self.auth_url = self._get_auth_url(rhdh_env)
        self._parsed_auth_url = urllib.parse.urlparse(self.auth_url)
        self.base_url = f"{self._parsed_auth_url.scheme}://{self._parsed_auth_url.netloc}"
        self.realm_path = self._parsed_auth_url.path.split("/protocol")[0]
        self.realm_name = self.realm_path.strip("/").split("/")[-1]
        self.hostname = self._parsed_auth_url.hostname

    def _get_auth_url(self, rhdh_env: "str") -> "str":
        """
        returns the authentication URL for the given RHDH environment
        """
        start_resp = self.session.get(
            f"{self.rhdh_base_url}/api/auth/oidc/start",
            params={"env": rhdh_env},
            allow_redirects=False,
        )
        return start_resp.headers["Location"] 

    def get_token(self) -> "str":
        """
        returns an access token for the client credentials provided to this realm instance
        """
        token_resp = requests.post(
            f"{self.base_url}{self.realm_path}/protocol/openid-connect/token",
            data={
                "grant_type": "client_credentials",
                "client_id": self.client_id,
                "client_secret": self.client_secret,
            },
            verify=False,
        )
        token_resp.raise_for_status()
        return token_resp.json()["access_token"]

    def get_user_id(self, token: "str") -> "str":
        """
        returns the user ID of the test user in the given realm
        """
        users_resp = requests.get(
            f"{self.base_url}/auth/admin/realms/{self.realm_name}/users",
            headers={"Authorization": f"Bearer {token}"},
            params={"username": self.username, "exact": "true"},
            verify=False,
        )
        users_resp.raise_for_status()
        return users_resp.json()[0]["id"]

    def get_authenticated_session(self, user_id: "str", token: "str") -> "list[dict[str, str | bool]]":
        impersonate_resp = requests.post(
            f"{self.base_url}/auth/admin/realms/{self.realm_name}/users/{user_id}/impersonation",
            headers={"Authorization": f"Bearer {token}"},
            verify=False,
            allow_redirects=False,
        )

        impersonate_resp.raise_for_status()

        return [
            {
                "name": c.name,
                "value": c.value,
                "domain": self.hostname,
                "path": c.path or "/",
                "secure": c.secure,
                "sameSite": "Lax",
            }
            for c in impersonate_resp.cookies
        ]

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
    return _require_env("RHDH_BASE_URL").rstrip("/")


@pytest.fixture(scope="session")
def authenticated_page(base_url: "str") -> "Page":
    """
    returns a session-scoped fixture that performs
    Red Hat SSO (Keycloak) login once and yields the
    authenticated Playwright Page for reuse across all tests.
    """
    keycloak_realm = KeycloakRealm()
    keycloak_token = keycloak_realm.get_token()
    keycloak_user_id = keycloak_realm.get_user_id(keycloak_token)
    keycloak_authenticated_session = keycloak_realm.get_authenticated_session(keycloak_user_id, keycloak_token)

    with sync_playwright() as playwright:
        # launch chromium browser for testing
        browser: Browser = playwright.chromium.launch(
            headless=PLAYWRIGHT_HEADLESS,
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
        # authenticate externally the browser session
        context.add_cookies(keycloak_authenticated_session)
        page: "Page" = context.new_page()

        # navigate to the RHDH login page
        page.goto(base_url, wait_until="networkidle")

        # trigger the popup. Keycloak will find the injected session cookies
        with context.expect_page() as page_info:
            page.click("button:has-text('Sign in')")

        popup = page_info.value
        popup.wait_for_load_state("domcontentloaded")

        try:
            popup.wait_for_event("close", timeout=15000)
        except Exception:
            pass

        page.wait_for_load_state("networkidle")

        yield page

        context.close()
        browser.close()
