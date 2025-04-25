from fastapi import FastAPI, Depends, HTTPException, Form, Body
from sqlalchemy.orm import Session
from backend import models, schemas, crud
from backend.database import engine, SessionLocal
from typing import List

models.Base.metadata.create_all(bind=engine)
print("💡 FastAPI başlatılıyor...")

app = FastAPI()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.post("/login")
def login(
    username: str = Form(...),
    password: str = Form(...),
    db: Session = Depends(get_db)
):
    user = crud.authenticate_user(db, username, password)
    if not user:
        raise HTTPException(status_code=401, detail="Kullanıcı adı veya şifre hatalı")
    return {
            "message": "Giriş başarılı",
            "username": user.username,
            "email": user.email  # ✅ Email'i de dönüyoruz
        }

@app.post("/register")
def register(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_username(db, user.username)
    if db_user:
        raise HTTPException(status_code=400, detail="Username already registered")
    return crud.create_user(db, user)

@app.post("/start-game")
def start_game(game: schemas.GameCreate, db: Session = Depends(get_db)):
    return crud.create_game(db, game)

@app.get("/active-games/{username}", response_model=List[schemas.GameOut])
def active_games(username: str, db: Session = Depends(get_db)):
    return crud.get_active_games_by_user(db, username)

@app.get("/completed-games/{username}")
def completed_games(username: str, db: Session = Depends(get_db)):
    games = crud.get_completed_games_by_user(db, username)
    return games
