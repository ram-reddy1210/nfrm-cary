# environment setup local
pyenv virtualenv 3.11.9 cary-nfrm-services
pyenv activate cary-nfrm-services
pip install -r requirements.txt

# Local execution: Note that you must have a main.py and app inside it.
    export GOOGLE_APPLICATION_CREDENTIALS=/Users/vinaykumar/.config/gcloud/ai-agent-repo-1456349a5589.json
    uvicorn main:app --reload

# Deployment to Cloud Run
    # Set your variables
    export PROJECT_ID="ai-agent-repo"
    export REGION="us-east1"
    export SERVICE_NAME="nfrm-cary-services-app"
    export IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"
    export RUNTIME_SERVICE_ACCOUNT="ai-agent-runner@${PROJECT_ID}.iam.gserviceaccount.com" 
    export VERTEX_AI_PROJECT_ID="ai-agent-repo" 
    export VERTEX_AI_LOCATION="us-east1"
    export VERTEX_MODEL_NAME="gemini-2.0-flash-001"

    # 0. Grant Firestore permissions to the Cloud Run service account (only needs to be done once)
    gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${RUNTIME_SERVICE_ACCOUNT}" \
    --role="roles/datastore.user"


    # 1. Build the container image
    gcloud builds submit --tag "${IMAGE_NAME}"

    # Run below command to allow kumar.vinay0210 to actAs service account
    gcloud iam service-accounts add-iam-policy-binding \
    ai-agent-runner@ai-agent-repo.iam.gserviceaccount.com \
    --member="user:kumar.vinay0210@gmail.com" \
    --role="roles/iam.serviceAccountUser" \
    --project="ai-agent-repo"


    # 2. Deploy to Cloud Run
    gcloud run deploy "${SERVICE_NAME}" \
    --image "${IMAGE_NAME}" \
    --platform managed \
    --region "${REGION}" \
    --service-account "${RUNTIME_SERVICE_ACCOUNT}" \
    --set-env-vars GCP_PROJECT_ID="${VERTEX_AI_PROJECT_ID}",GCP_LOCATION="${VERTEX_AI_LOCATION}",VERTEX_MODEL_NAME="${VERTEX_MODEL_NAME}" \
    --allow-unauthenticated
