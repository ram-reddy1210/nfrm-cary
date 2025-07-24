from typing import List, Literal

# Import the llm_services module to interact with the AI model
from core.services import llm_services

# Using Literal for type hinting the allowed question types
QuestionType = Literal["Personal", "Business"]

# Predefined lists of popular financial questions
POPULAR_PERSONAL_FINANCE_QUESTIONS = [
    "How can I create a budget and stick to it?",
    "What's the best way to start saving for retirement?",
    "How do I build an emergency fund and how much should I save?",
    "What are the differences between a 401(k) and an IRA?",
    "How can I improve my credit score?",
    "What strategies can I use to pay off credit card debt?",
    "Should I rent or buy a home?",
    "What is a mutual fund and how does it work?",
    "How much life insurance do I need?",
    "What are the basics of investing in the stock market for a beginner?",
]

POPULAR_BUSINESS_FINANCE_QUESTIONS = [
    "What are the first steps to creating a business plan?",
    "How do I manage my business's cash flow effectively?",
    "What are the different funding options for a new startup?",
    "How can I find angel investors or venture capital for my business?",
    "What are the key financial metrics I should be tracking for my small business?",
    "What's the difference between a sole proprietorship, LLC, and corporation?",
    "How do I prepare a pitch deck for investors?",
    "What are the basics of business accounting?",
    "How can I secure a small business loan?",
    "What are the tax implications of different business structures?",
]

def get_popular_questions(question_type: QuestionType, count: int) -> List[str]:
    """
    Retrieves a specified number of popular financial questions based on the type.

    Args:
        question_type: The type of questions to retrieve ("Personal" or "Business").
        count: The number of questions to return.

    Returns:
        A list of popular questions.
    """
    if question_type == "Personal":
        return POPULAR_PERSONAL_FINANCE_QUESTIONS[:count]
    elif question_type == "Business":
        return POPULAR_BUSINESS_FINANCE_QUESTIONS[:count]
    return []


def get_financial_advice_chat(user_question: str) -> str:
    """
    Gets financial advice from the AI in a chat session.
    This function is moved from the router to the service layer for better code organization.

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


def get_document_review_chat(document_content: str, user_question: str) -> str:
    """
    Analyzes financial document content and answers user questions about it.

    Args:
        document_content: The text content of the financial document.
        user_question: The user's specific question or request about the document.

    Returns:
        The AI's analysis and response.
    """
    system_prompt = f"""You are an expert financial document analyst AI. Your primary function is to review the content of financial documents provided by the user, offer insightful suggestions, and answer specific questions.

**Your Task:**
1.  **Analyze the Document:** Carefully read and understand the provided financial document content.
2.  **Provide Suggestions:** Based on the user's request, offer suggestions to improve clarity, identify potential risks, highlight key figures or clauses, or point out missing information.
3.  **Answer Questions:** Address the user's follow-up questions about the document accurately. Use the document content as the primary source of truth for your answers.
4.  **Maintain Context:** Remember the document content and previous questions to provide coherent, conversational follow-up responses.

**Your Persona:**
- **Analytical & Meticulous:** Pay close attention to detail.
- **Helpful & Clear:** Explain your findings and suggestions in an easy-to-understand manner.
- **Objective & Neutral:** Do not offer personal opinions or advice beyond the scope of analyzing the document.
- **Prudent & Responsible:** Always include a disclaimer that you are an AI assistant and that users should consult with qualified human professionals (like lawyers or financial advisors) for legally binding or personalized advice.

**User's Document:**
---
{document_content}
---
"""
    
    # Combine the system prompt, document, and user question into a single payload for the chat.
    # The chat model will use the system prompt and document as context for the user's question.
    prompt_payload = f"{system_prompt}\n\nUser's question about the document: \"{user_question}\"\n\nYour analysis and response:"
    
    try:
        # Use the chat_with_ai function to maintain conversation context for follow-up questions.
        analysis_text = llm_services.chat_with_ai(prompt_payload)
        return analysis_text
    except Exception as e:
        print(f"Error in get_document_review_chat: {e}")
        return f"An error occurred during document review: {e}"