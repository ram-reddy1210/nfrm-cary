from fastapi import FastAPI

my_app = None

async def init_app(app: FastAPI):
    global my_app
    my_app = app

def get_app() -> FastAPI:
    global my_app   
    return my_app