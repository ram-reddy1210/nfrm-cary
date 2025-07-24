from typing import List, Literal

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