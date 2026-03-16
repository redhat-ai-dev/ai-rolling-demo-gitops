import pytest

from playwright.sync_api import Page

from pages.lightspeed_page import LightspeedPage, MCP_PROMPT


@pytest.fixture(scope="module")
def lightspeed_home(authenticated_page: "Page", base_url: "str") -> "LightspeedPage":
    """
    returns a LightspeedPage navigated to the home page.
    """
    lp = LightspeedPage(authenticated_page, base_url)
    lp.navigate()
    lp.wait_for_load()
    return lp


@pytest.fixture(scope="module")
def lightspeed_chat(authenticated_page: "Page", base_url: "str") -> "LightspeedPage":
    """
    returns a LightspeedPage navigated to /lightspeed for chat interaction tests.
    """
    lp = LightspeedPage(authenticated_page, base_url)
    lp.navigate_to_lightspeed()
    lp.wait_for_load()
    return lp


@pytest.mark.auth_required
def test_lightspeed_icon_on_homepage(lightspeed_home: "LightspeedPage") -> "None":
    assert lightspeed_home.homepage_icon.is_visible(), (
        "Lightspeed icon should be visible in the bottom-right of the home page"
    )


@pytest.mark.auth_required
def test_lightspeed_model_selector_has_option(
    lightspeed_chat: "LightspeedPage"
) -> "None":
    selector = lightspeed_chat.model_selector
    assert selector.is_visible(), "Model selector should be visible on the Lightspeed page"
    model_name = selector.locator(".pf-v6-c-menu-toggle__text").inner_text().strip()
    assert model_name, "Model selector should show at least one model"


@pytest.mark.auth_required
def test_lightspeed_chat_input_visible(lightspeed_chat: "LightspeedPage") -> "None":
    assert lightspeed_chat.chat_input.is_visible(), (
        "Chat input should be visible on the Lightspeed page"
    )

# TODO: Find a proper way to test the MCP tools response
# @pytest.mark.auth_required
# def test_lightspeed_mcp_tools_response(lightspeed_chat: "LightspeedPage") -> "None":
#     lightspeed_chat.send_message(MCP_PROMPT)
#     response_text = lightspeed_chat.wait_for_response()
#     assert "register-catalog-entities" in response_text, (
#         "Lightspeed MCP response should contain 'register-catalog-entities'"
#     )

# TODO: See if this overlaps with Lightspeed Plugin E2E
# @pytest.mark.auth_required
# def test_lightspeed_chat_history_retrievable(
#     lightspeed_chat: "LightspeedPage"
# ) -> "None":
#     history_item = lightspeed_chat.history_item(0)
#     assert history_item.is_visible(), (
#         "At least one chat history item should be visible after sending messages"
#     )
