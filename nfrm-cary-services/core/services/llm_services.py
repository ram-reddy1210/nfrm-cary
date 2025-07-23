import os
import vertexai
# google.generativeai is not used in this file.
from vertexai.generative_models import GenerativeModel, ChatSession # Part is not used.

model: GenerativeModel = None # Added type hint for clarity
chat: ChatSession = None # Global chat session variable

def initialize_ai():
    global model, chat # Ensure assignment to global variables
    # --- CONFIGURATION ---
    # Project ID and location can be fetched from environment variables
    # for better flexibility in different environments.
    # Ensure these environment variables (GCP_PROJECT_ID, GCP_LOCATION) are set in your Cloud Run service.
    # The defaults 'ai-agent-repo' and 'us-east1' are used if the environment variables are not set.
    project_id = os.getenv('GCP_PROJECT_ID', 'ai-agent-repo')
    location = os.getenv('GCP_LOCATION', 'us-east1')

    # DO NOT set os.environ['GOOGLE_APPLICATION_CREDENTIALS'] here for Cloud Run.
    # vertexai.init() will use Application Default Credentials (ADC).
    # On Cloud Run, ADC uses the service's runtime service account.
    # For local development, run 'gcloud auth application-default login'.
    print(f"Initializing Vertex AI with Project ID: {project_id}, Location: {location}")
    vertexai.init(project=project_id, location=location)
    model_name = os.getenv('VERTEX_MODEL_NAME', "gemini-2.0-flash-001")
    # Consider making the model name configurable as well, e.g., via an environment variable.
    model = GenerativeModel(model_name)
    chat = model.start_chat()
    print(f"Vertex AI Model '{model_name}' initialized and chat session started.")

def generate_ai_response(prompt: str) -> str:
    """
    Generates an AI response to a given prompt using a transformer model.

    Args:
        prompt: The input prompt string.

    Returns:
        The generated AI response string.
    """
    try:
        print(f"Generating AI response for prompt: {prompt}")
        if model is None:
            # This should ideally not be reached if initialize_ai() is called at startup,
            # but it's a good safeguard.
            raise RuntimeError("AI model has not been initialized. Call initialize_ai() first.")
        response = model.generate_content(prompt)
        # For Vertex AI GenerativeModel, the text response is typically accessed via response.text
        print(f"Raw AI response: {response}")
        return response.text
    except Exception as e:
        print(f"Error generating AI response: {e}")
        return f"Error generating AI response: {e}"

def chat_with_ai(prompt: str) -> str:
    """
    Sends a message to the AI in an ongoing chat session and gets a response.

    Args:
        prompt: The user's message to the AI.

    Returns:
        The AI's response string.
    """
    try:
        print(f"Sending message to AI chat: {prompt}")
        if chat is None:
            # This safeguard ensures initialize_ai() has been successfully called
            # and the chat session was started.
            raise RuntimeError("AI chat session has not been initialized. Call initialize_ai() first.")
        
        response = chat.send_message(prompt)
        # For ChatSession, the text response is typically accessed via response.text
        print(f"Raw AI chat response: {response}")
        return response.text
    except Exception as e:
        print(f"Error in AI chat: {e}")
        return f"Error in AI chat: {e}"
