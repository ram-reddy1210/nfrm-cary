import os
import json
from typing import TypedDict, Annotated, List, Dict, Any

from langchain_core.messages import HumanMessage, BaseMessage
from langchain_core.tools import tool
from langchain_google_vertexai import ChatVertexAI
from langgraph.graph import StateGraph, END
from langgraph.graph.message import add_messages
from langgraph.prebuilt import ToolNode

from core.services import firestore_service

# --- 1. Define Tools ---

@tool
async def query_firestore_api_logs(filters: List[Dict[str, Any]], limit: int = 10) -> str:
    """
    Queries and retrieves full documents from the 'api_logs' collection in Firestore.
    Use this to answer questions that require seeing the content of logs, such as "Show me the latest 5 logs for user X".
    Do NOT use this for counting. Use the `count_api_logs` tool instead.
    The filters argument should be a list of dictionaries, where each dictionary
    represents a filter condition with 'field', 'op', and 'value'.
    'field' is the document field to filter on (e.g., 'api_name', 'user_details.user_email', 'timestamp').
    'op' is the comparison operator (e.g., '==', '!=', '<', '<=', '>', '>=').
    'value' is the value to compare against. For timestamps, use ISO 8601 format strings.
    'limit' is the maximum number of documents to return.
    """
    print(f"Executing Firestore query with filters: {filters} and limit: {limit}")
    try:
        results = await firestore_service.query_collection_with_filters(
            collection_name='api_logs',
            filters=filters,
            limit=limit
        )
        if not results:
            return "No documents found matching the criteria."
        return json.dumps(results, indent=2)
    except Exception as e:
        print(f"Error during Firestore query tool execution: {e}")
        return f"An error occurred while querying Firestore: {str(e)}"

@tool
async def count_api_logs(filters: List[Dict[str, Any]]) -> str:
    """
    Counts documents in the 'api_logs' collection based on filters.
    Use this to answer questions like "How many total API calls were made?" or "Count the number of calls to 'generate_ai_response'".
    This tool is much more efficient for counting than retrieving full documents.
    The filters argument is a list of dictionaries, each with 'field', 'op', and 'value'.
    For time-based questions like "in the last 10 days", you must calculate the date and create a filter like:
    {'field': 'timestamp', 'op': '>=', 'value': 'YYYY-MM-DDTHH:MM:SSZ'}.
    """
    print(f"Executing Firestore count with filters: {filters}")
    try:
        count = await firestore_service.count_collection_with_filters(
            collection_name='api_logs',
            filters=filters
        )
        return f"Found {count} matching documents."
    except Exception as e:
        print(f"Error during Firestore count tool execution: {e}")
        return f"An error occurred while counting documents in Firestore: {str(e)}"

@tool
async def get_distinct_api_log_values(field_name: str, filters: List[Dict[str, Any]], limit: int = 100) -> str:
    """
    Gets distinct (unique) values for a specific field from the 'api_logs' collection.
    Use this to answer questions like "Show me all distinct prompts" or "List all unique user emails".
    'field_name' is the field you want to find unique values for (e.g., 'prompt', 'api_name', 'user_details.user_email').
    'filters' can be used to narrow down the search (e.g., within a specific time range).
    'limit' is the maximum number of logs to scan to find the distinct values.
    """
    print(f"Executing Firestore distinct value query for field '{field_name}' with filters: {filters}")
    try:
        distinct_values = await firestore_service.get_distinct_values(
            collection_name='api_logs',
            field_name=field_name,
            filters=filters,
            limit=limit
        )
        if not distinct_values:
            return "No distinct values found for the given criteria."
        return json.dumps(distinct_values, indent=2)
    except Exception as e:
        print(f"Error during Firestore distinct value tool execution: {e}")
        return f"An error occurred while getting distinct values from Firestore: {str(e)}"

@tool
async def get_api_call_count_by_group(group_by_field: str, filters: List[Dict[str, Any]], limit: int = 1000) -> str:
    """
    Groups API logs by a specific field and returns the count for each group.
    Use this to answer questions like "Show me total API calls per user" or "What is the breakdown of API calls by api_name?".
    'group_by_field' is the field to group by (e.g., 'user_details.user_email', 'api_name').
    'filters' can be used to narrow down the search (e.g., within a specific time range).
    'limit' is the maximum number of logs to scan for this aggregation.
    """
    print(f"Executing Firestore group and count for field '{group_by_field}' with filters: {filters}")
    try:
        grouped_counts = await firestore_service.group_and_count_by_field(
            collection_name='api_logs',
            group_by_field=group_by_field,
            filters=filters,
            limit=limit
        )
        if not grouped_counts:
            return "No data found to group and count for the given criteria."
        return json.dumps(grouped_counts, indent=2)
    except Exception as e:
        print(f"Error during Firestore group and count tool execution: {e}")
        return f"An error occurred while grouping and counting data from Firestore: {str(e)}"

# --- 2. Define Agent State and Graph ---

class AgentState(TypedDict):
    messages: Annotated[list, add_messages]

# --- 3. Define Agent Logic ---

# This node decides whether to call a tool or to generate a final response.
def should_continue(state: AgentState) -> str:
    last_message = state['messages'][-1]
    # If the LLM returned a tool call, then we call the tool node.
    if last_message.tool_calls:
        return "call_tool"
    # Otherwise, we are done.
    return END

# This is the agent node. It calls the model to decide what to do next.
async def call_model(state: AgentState):
    response = await llm_with_tools.ainvoke(state['messages'])
    return {"messages": [response]}

# --- 4. Initialize and Compile the Agent ---

# The schema of the api_logs collection is crucial for the LLM to construct correct queries.
# This should be updated if your schema changes.
FIRESTORE_SCHEMA_PROMPT = """
You are a powerful and helpful assistant that answers questions about API logs stored in a Firestore collection named 'api_logs'.
You have access to a set of tools to query this collection. You must choose the best tool for the user's question.

**Tool Descriptions:**

1.  `query_firestore_api_logs(filters: List[Dict], limit: int)`:
    - **Use Case:** When you need to retrieve and view the full content of log documents.
    - **Example Questions:** "Show me the last 5 logs for 'test@example.com'", "What was the request data for the latest 'astrology_chat' call?"
    - **Do NOT use this for counting.**

2.  `count_api_logs(filters: List[Dict])`:
    - **Use Case:** When you need to count the number of documents that match certain criteria. This is very efficient.
    - **Example Questions:** "How many total API calls were made in the last 10 days?", "Count the number of calls to the 'generate_ai_response' API yesterday."

3.  `get_distinct_api_log_values(field_name: str, filters: List[Dict], limit: int)`:
    - **Use Case:** When you need to find all the unique values for a specific field.
    - **Example Questions:** "Show me all distinct prompts used last month.", "List all the unique user emails that called an API this week."

4.  `get_api_call_count_by_group(group_by_field: str, filters: List[Dict], limit: int)`:
    - **Use Case:** When you need to count documents and group them by a specific field.
    - **Example Questions:** "Show me the total API calls per user", "What is the breakdown of API calls by api_name in the last week?", "Count calls for each user email".
    - **Fields to group by:** `api_name`, `user_details.user_email`.

**Log Schema:**
The schema for the documents in the 'api_logs' collection is as follows:
- `api_name` (string): The name of the API endpoint.
- `prompt` (string): The user's query to the API.
- `user_details` (map):
  - `user_email` (string): User's email.
  - `user_name` (string): User's name.
- `request_data` (map): The full JSON request body.
- `timestamp` (timestamp): The time the log was created.

**Important Instructions:**
- **Date and Time:** For any questions involving dates (e.g., "today", "last 10 days", "last month"), you MUST calculate the appropriate start and end dates and format them as ISO 8601 strings (e.g., "2024-05-21T00:00:00Z") to use in the `value` field of a timestamp filter.
- **Tool Selection:** Carefully analyze the user's question to select the most appropriate tool. If the user asks "how many", use `count_api_logs`. If they ask for "distinct" or "unique" values, use `get_distinct_api_log_values`. If they want to see the actual logs, use `query_firestore_api_logs`.
- **Clarification:** If a question is ambiguous, ask for clarification. Do not guess filters.
- **Conversation:** If the user asks a general question like "What's up?", do not call any tools and just have a friendly conversation.
"""

# Initialize the model and tools
tools = [query_firestore_api_logs, count_api_logs, get_distinct_api_log_values, get_api_call_count_by_group]
model_name = os.getenv('VERTEX_MODEL_NAME', "gemini-2.0-flash-001")
llm = ChatVertexAI(model_name=model_name, system_instruction=FIRESTORE_SCHEMA_PROMPT)
llm_with_tools = llm.bind_tools(tools)

# The tool node that executes the function calls
tool_node = ToolNode(tools)

# Define the graph
workflow = StateGraph(AgentState)
workflow.add_node("agent", call_model)
workflow.add_node("call_tool", tool_node)

# Define the edges
workflow.set_entry_point("agent")
workflow.add_conditional_edges(
    "agent",
    should_continue,
)
workflow.add_edge("call_tool", "agent")

# Compile the graph into a runnable
agent_graph = workflow.compile()

async def run_agent_chat(question: str) -> str:
    """
    Runs the agent graph to get an answer for the user's question.
    """
    try:
        final_state = await agent_graph.ainvoke({
            "messages": [HumanMessage(content=question)]
        })
        # The final response is the last message from the agent
        response_message = final_state['messages'][-1]
        return response_message.content
    except Exception as e:
        print(f"Error running agent chat: {e}")
        return "I'm sorry, but I encountered an error while processing your request."