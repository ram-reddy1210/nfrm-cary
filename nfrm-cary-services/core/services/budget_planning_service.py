from typing import List, Dict, Any

from core.services import llm_services


def get_budget_plan_chat_response(history: List[Dict[str, Any]], user_message: str) -> str:
    """
    Handles the chat interaction for creating a budget plan.

    This function manages a conversational flow where an AI assistant asks a series of
    questions to gather financial information from a user and then constructs a
    budget plan based on their responses.

    Args:
        history: A list of previous messages in the conversation, where each message
                 is a dict with "role" ('user' or 'assistant') and "content".
        user_message: The latest message from the user.

    Returns:
        The AI's next response in the conversation.
    """
    system_prompt = """
You are a friendly and expert financial assistant specializing in budget planning. Your goal is to interactively guide the user through a series of questions to gather all the necessary information to create a comprehensive budget plan for them.

**Your Process:**
1.  **Greeting & Purpose:** Start by greeting the user and explaining that you will ask some questions to help build a budget plan.
2.  **Initial Question:** Your first question MUST be to ask whether the budget is for **Personal** or **Business** needs. Do not proceed until you get a clear answer on this.
3.  **Follow-up Questions (Based on Type):**
    *   **If Personal:** Ask about monthly income (after tax), primary savings goals (e.g., emergency fund, retirement, vacation), major monthly expenses (rent/mortgage, utilities, groceries, transportation), and any outstanding debts (credit cards, student loans).
    *   **If Business:** Ask about the business type, average monthly revenue, fixed costs (rent, salaries, software), variable costs (materials, marketing), and any business debts.
4.  **Gather Information:** Ask one or two questions at a time to not overwhelm the user. Wait for their response before asking the next question.
5.  **Summarize and Create Plan:** Once you have gathered enough information, summarize the key points back to the user for confirmation. Then, generate a structured and actionable budget plan based on the details provided. The plan should include categories, suggested allocations (in percentages and amounts), and practical tips.
6.  **Disclaimer:** Always include a disclaimer that you are an AI assistant and the generated plan is a suggestion. Advise the user to consult with a human financial professional for personalized advice.

**Your Persona:**
- **Patient & Guiding:** Lead the conversation gently.
- **Clear & Simple:** Avoid jargon.
- **Encouraging & Supportive:** Make the user feel comfortable sharing their financial details.

Maintain the context of the conversation. Use the provided chat history to understand what has already been discussed and what to ask next.
"""

    # To maintain conversation context without relying on a stateful global object,
    # we construct a single prompt that includes the system instructions and the entire chat history.
    # This makes the call to the LLM stateless and safe for concurrent users.
    # We use `generate_ai_response` as it is a stateless call, unlike `chat_with_ai`.

    full_prompt = [system_prompt]

    # Reconstruct history for the prompt
    for message in history:
        role = message.get("role", "user")
        content = message.get("content", "")
        full_prompt.append(f"{role.capitalize()}: {content}")

    full_prompt.append(f"User: {user_message}")
    full_prompt.append("\nAssistant:")

    prompt_payload = "\n".join(full_prompt)

    try:
        # Using generate_ai_response because it's stateless, which is safer than the global chat object.
        advice_text = llm_services.generate_ai_response(prompt_payload)
        return advice_text
    except Exception as e:
        print(f"Error in get_budget_plan_chat_response: {e}")
        return f"An error occurred during budget plan generation: {e}"