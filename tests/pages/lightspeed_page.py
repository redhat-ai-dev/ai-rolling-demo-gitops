from playwright.sync_api import Page, Locator

from .base_page import BasePage

# MCP_PROMPT: should be a prompt that is expected to return a
# list of available MCP tools when sent to the Lightspeed chat.
MCP_PROMPT = "list all the mcp tools you have available"


# LLM_RESPONSE_TIMEOUT: the maximum time to wait for a response
# from the LLM before timing out.
LLM_RESPONSE_TIMEOUT = 120000

# DEFAULT_CHAT_ITEM_INDEX: the default index for selecting a
# chat history item.
DEFAULT_CHAT_ITEM_INDEX = 0

class LightspeedPage(BasePage):
    def __init__(self, page: "Page", base_url: "str") -> "None":
        super().__init__(page, base_url)

    def navigate_to_lightspeed(self) -> "None":
        self.navigate("/lightspeed")

    @property
    def homepage_icon(self) -> "Locator":
        """
        locates the Lightspeed floating action button visible on
        the home page.
        """
        return self.page.locator(
            "[data-testid='lightspeed-icon'], "
            "[aria-label*='Lightspeed'], "
            "[aria-label*='lightspeed'], "
            "button[class*='lightspeed'], "
            "button[class*='Lightspeed']"
        ).first

    @property
    def model_selector(self) -> "Locator":
        """
        locates the Model selector dropdown inside the
        Lightspeed chat panel.
        """
        return self.page.locator("button[aria-label='Chatbot selector']")

    @property
    def chat_input(self) -> "Locator":
        """
        locates the Text input / textarea for sending prompts.
        """
        return self.page.locator("textarea[aria-label='Enter a prompt for Lightspeed']")

    def send_message(self, text: "str") -> "None":
        """
        sends a message to the Lightspeed chat by filling the input
        and pressing Enter.
        """
        self.chat_input.fill(text)
        self.page.keyboard.press("Enter")

    @property
    def response_container(self) -> "Locator":
        """
        locates the most recent bot response. Bot messages are
        distinguished from user messages by having response action
        buttons (Good/Bad/Copy/Listen) inside them.
        """
        return self.page.locator(
            "div.pf-chatbot__message-and-actions:has(.pf-chatbot__response-actions)"
        ).last

    def wait_for_response(self, timeout: "int" = LLM_RESPONSE_TIMEOUT) -> "str":
        """
        waits until the bot response is fully streamed — indicated by
        the response action buttons (Good/Bad/Copy) becoming visible —
        then returns the response text.
        """
        self.page.locator(
            "div.pf-chatbot__message-and-actions:has(.pf-chatbot__response-actions)"
        ).last.locator(".pf-chatbot__response-actions").wait_for(
            state="visible", timeout=timeout
        )
        return self.response_container.inner_text()

    @property
    def history_panel(self) -> "Locator":
        """
        locates the chat history panel that displays previous conversations.
        """
        return self.page.locator(
            "[data-testid='chat-history'], "
            "[aria-label*='history'], "
            "[class*='chat-history']"
        ).first

    def history_item(self, index: "int" = DEFAULT_CHAT_ITEM_INDEX) -> "Locator":
        """
        returns a chat history entry by index (0-based), excluding
        disabled placeholder items like "No pinned chats".
        """
        return self.page.locator(
            "li.pf-chatbot__menu-item:not(.pf-m-disabled)"
        ).nth(index)
