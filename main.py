from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from core.routers import rest_llm
from core.dependencies import init_app
from core.services import llm_services, firestore_service
from fastapi.middleware.cors import CORSMiddleware
import os

app = FastAPI()

static_dir = "static"
if not os.path.exists(static_dir):
    os.makedirs(static_dir)

app.mount("/static", StaticFiles(directory=static_dir), name="static")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Change to specific domains if needed
    allow_credentials=True,
    allow_methods=["*"],  # Allows GET, POST, PUT, DELETE, etc.
    allow_headers=["*"],  # Allows all headers
)
app.include_router(rest_llm.router)

@app.on_event("startup")
async def startup_event():
    print("Starting up...")
    await init_app(app)
    llm_services.initialize_ai()
    firestore_service.initialize_firestore()

@app.on_event("shutdown")
async def shutdown_event():
    print("Shutting down...")

@app.get("/")
async def read_index():
    return FileResponse(os.path.join(static_dir, 'index.html'))
