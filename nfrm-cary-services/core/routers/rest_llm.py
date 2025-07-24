from fastapi import APIRouter, Request, Query
from pydantic import BaseModel
from typing import Optional, List, Dict, Any

# typing.Annotated was imported but not used.
# Import the llm_services module to avoid naming conflicts and allow proper calling.
from core.services import llm_services, firestore_service, admin_chat_agent_service, financial_advice_service, budget_planning_service
from core.services.financial_advice_service import QuestionType

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

class AdviseChatRequest(BaseModel):
    prompt: str
    user_name: str
    user_email: str
    language: Optional[str] = "English"

@router.post('/v1/ai-agents/advise_chat', tags=["Financial Advice"])
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

    # The business logic is now in the service layer.
    ai_response_content = financial_advice_service.get_financial_advice_chat(
        user_question=details.prompt,
        language=details.language
    )
    return {"response": ai_response_content}


class ReviewDocumentRequest(BaseModel):
    document_content: str
    prompt: str
    user_name: str
    user_email: str

@router.post('/v1/ai-agents/review_document_chat', tags=["Financial Advice"])
async def document_reviewer_chat(details: ReviewDocumentRequest, request: Request):
    """
    Endpoint for chat-based financial document review.
    User provides document content and a prompt for analysis.
    """
    user_details = {
        "client_host": request.client.host if request.client else "unknown",
        "user_name": details.user_name,
        "user_email": details.user_email
    }
    await firestore_service.log_api_call(
        api_name="document_reviewer_chat",
        prompt=details.prompt,
        user_details=user_details,
        request_data=details.model_dump()
    )

    ai_response_content = financial_advice_service.get_document_review_chat(document_content=details.document_content, user_question=details.prompt)
    return {"response": ai_response_content}


class BudgetChatRequest(BaseModel):
    history: List[Dict[str, Any]] # e.g. [{"role": "user", "content": "Hi"}, {"role": "assistant", "content": "Hello!"}]
    prompt: str
    user_name: str
    user_email: str

@router.post('/v1/ai-agents/budget_planner_chat', tags=["Financial Advice"])
async def budget_planner_chat(details: BudgetChatRequest, request: Request):
    """
    Endpoint for an interactive chat to create a budget plan.
    Manages a conversation where the AI asks questions to gather financial details
    and then generates a budget plan.
    """
    user_details = {
        "client_host": request.client.host if request.client else "unknown",
        "user_name": details.user_name,
        "user_email": details.user_email
    }
    # The prompt for logging will be just the user's latest message.
    await firestore_service.log_api_call(
        api_name="budget_planner_chat",
        prompt=details.prompt,
        user_details=user_details,
        request_data=details.model_dump()
    )

    ai_response_content = budget_planning_service.get_budget_plan_chat_response(
        history=details.history, user_message=details.prompt
    )
    return {"response": ai_response_content}


@router.get("/v1/ai-agents/popular-financial-questions", response_model=List[str], tags=["Financial Advice"])
async def get_popular_financial_questions(
    type: QuestionType = Query(..., description="The type of financial questions to retrieve. Either 'Personal' or 'Business'."),
    count: int = Query(5, description="The number of questions to return.", ge=1, le=20)
):
    """
    Retrieves a list of popular financial questions.

    This endpoint provides a list of common questions that users can ask the financial advisor agent.
    This helps guide users on the capabilities of the service.
    """
    questions = financial_advice_service.get_popular_questions(question_type=type, count=count)
    return questions


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
