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



def get_coaching_advice_chat(user_problem: str, scriptures_context: str) -> str:
    """
    Gets career coaching advice from the AI in a chat session, based on Hindu scriptures.
    Uses the persistent chat session from llm_services.

    Args:
        user_problem: The problem or question from the user for the current turn.
        scriptures_context: A string containing the list/summary of Hindu scriptures.

    Returns:
        The AI's coaching advice for the current turn, or an error message.
    """
    system_prompt = f"""You are a highly knowledgeable master of all Hindu scriptures and an experienced career coach, engaging in an ongoing chat conversation.
                    Your primary knowledge base for Hindu scriptures is as follows:
                    --- SCRIPTURES START ---
                    {scriptures_context}
                    --- SCRIPTURES END ---
                    You are to provide guidance and advice to students (at any level), corporate leaders, and stakeholders. 
                    Address their real-time problems with brief and insightful answers, drawing wisdom from these scriptures and remembering previous parts of this conversation.
                    Limit your response for this turn to a maximum of 300 words. 
                    Be empathetic, wise, and practical in your advice. Do not refer to yourself as an AI or language model. Act as a human coach.
                    """
    
    prompt_payload = f"{system_prompt}\n\nUser's current problem or question: \"{user_problem}\"\n\nYour coaching advice for this turn:"
    
    try:
        advice_text = llm_services.chat_with_ai(prompt_payload)
        return advice_text
    except Exception as e:
        print(f"Error in get_coaching_advice_chat: {e}")
        return f"An error occurred during chat-based advice generation: {e}"

class AdviseChatRequest(BaseModel):
    prompt: str
    user_name: str
    user_email: str

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
