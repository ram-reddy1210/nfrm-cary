from fastapi import APIRouter, Request, Query
from pydantic import BaseModel
from typing import Optional, List, Dict, Any

# typing.Annotated was imported but not used.
# Import the llm_services module to avoid naming conflicts and allow proper calling.
from core.services import llm_services, firestore_service, admin_chat_agent_service

router = APIRouter(prefix="/api")

class GenerateAIResponseRequest(BaseModel):
    prompt: str
    user_name: str
    user_email: str

@router.post("/v1/ai-agents/generate_ai_response")
async def generate_ai_response(details: GenerateAIResponseRequest, request: Request):
    """
    Generates an AI response based on the provided prompt.

    Args:
        details: An object containing the prompt, user_name, and user_email.
        request: The incoming FastAPI request object for logging.

    Returns:
        A dictionary containing the generated AI response.
    """
    # Log the API call to Firestore
    user_details = {
        "client_host": request.client.host if request.client else "unknown",
        "user_name": details.user_name,
        "user_email": details.user_email
    }
    await firestore_service.log_api_call(
        api_name="generate_ai_response",
        prompt=details.prompt,
        user_details=user_details,
        request_data=details.model_dump()
    )

    # Call the service function correctly. The previous call was recursive.
    ai_response_content = llm_services.generate_ai_response(details.prompt)
    return {"response": ai_response_content}

def get_financial_advice_chat(user_question: str) -> str:
    """
    Gets financial advice from the AI in a chat session.
    Uses the persistent chat session from llm_services.

    Args:
        user_question: The financial question from the user.

    Returns:
        The AI's financial advice, or an error message.
    """
    system_prompt = """You are a comprehensive and expert financial advisor AI. Your goal is to provide clear, practical, and responsible financial guidance. You are equipped to handle a wide range of financial topics.

You must be able to answer questions related to:
- **Personal Finance:** Budgeting, saving, debt management (credit cards, loans), retirement planning (401k, IRA), and building an emergency fund.
- **Investing:** Stock market basics, mutual funds, ETFs, bonds, real estate, and risk tolerance assessment. Explain concepts clearly and provide general information, but do NOT give personalized investment advice to buy or sell specific securities.
- **Small Business:** Guidance on starting a business, creating a business plan, managing cash flow, understanding funding options, and basic accounting principles.
- **Finding Investors:** Strategies for seeking seed funding, venture capital, angel investors, and preparing a pitch deck.

**Your Persona:**
- **Knowledgeable & Clear:** Break down complex topics into easy-to-understand language.
- **Prudent & Responsible:** Always include a disclaimer that you are an AI assistant and that users should consult with a qualified human financial professional for personalized advice before making any financial decisions.
- **Supportive & Unbiased:** Provide balanced information about different financial strategies and products.
- **Conversational:** Engage with the user in a helpful and approachable manner. Do not refer to yourself as a language model. Act as a human advisor.

Remember to maintain the context of the conversation if it's an ongoing chat.
"""
    
    prompt_payload = f"{system_prompt}\n\nUser's question: \"{user_question}\"\n\nYour financial advice:"
    
    try:
        advice_text = llm_services.chat_with_ai(prompt_payload)
        return advice_text
    except Exception as e:
        print(f"Error in get_financial_advice_chat: {e}")
        return f"An error occurred during financial advice generation: {e}"

class AdviseChatRequest(BaseModel):
    prompt: str
    user_name: str
    user_email: str

@router.post('/v1/ai-agents/advise_chat')
async def financial_advisor_chat(details: AdviseChatRequest, request: Request):
    """Endpoint for chat-based financial advice."""
    # Log the API call to Firestore
    user_details = {
        "client_host": request.client.host if request.client else "unknown",
        "user_name": details.user_name,
        "user_email": details.user_email
    }
    await firestore_service.log_api_call(
        api_name="financial_advisor_chat",
        prompt=details.prompt,
        user_details=user_details,
        request_data=details.model_dump()
    )

    ai_response_content = get_financial_advice_chat(details.prompt)
    return {"response": ai_response_content}


@router.get("/v1/admin/api-logs", response_model=List[Dict[str, Any]], tags=["Admin"])
async def get_api_logs(
    api_name: Optional[str] = Query(None, description="Filter logs by API name. e.g., 'generate_ai_response'"),
    limit: int = Query(20, description="Maximum number of logs to return", ge=1, le=100)
):
    """
    Retrieves API call logs from Firestore.

    This endpoint allows querying the `api_logs` collection.
    You can filter by `api_name` and limit the number of results returned.
    The logs are returned in reverse chronological order (newest first).
    """
    logs = await firestore_service.query_api_logs(api_name=api_name, limit=limit)
    return logs


class AdminChatRequest(BaseModel):
    question: str
    user_name: str # To know which admin is asking
    user_email: str

@router.post("/v1/admin/chat", tags=["Admin"])
async def admin_chat(details: AdminChatRequest, request: Request):
    """
    Provides a chat interface for admins to ask natural language questions about API logs.
    The agent will understand the question, query Firestore's 'api_logs' collection,
    and return a summarized, human-readable answer.

    Example questions:
    - "How many calls were made to the astrology_chat API today?"
    - "Show me the latest 5 logs for the user 'test@example.com'."
    """
    answer = await admin_chat_agent_service.run_agent_chat(details.question)
    return {"response": answer}
