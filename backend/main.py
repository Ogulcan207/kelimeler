from fastapi import FastAPI, Depends, HTTPException, Form, Body
from sqlalchemy.orm import Session
from backend import models, schemas, crud
from backend.database import engine, SessionLocal
from typing import List
from datetime import datetime

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
def start_game(
    username: str = Body(...),
    mode: str = Body(...),
    db: Session = Depends(get_db)
):
    result = crud.match_or_create_game(db, username, mode)
    if result:
        # Eşleşme sağlandı ve yeni oyun oluşturuldu
        return {"message": "Oyun başlatıldı", "game_id": result.id}
    else:
        # Beklemeye alındı, eşleşme yok
        return {"message": "Bekleniyor", "waiting": True}

@app.get("/active-games/{username}", response_model=List[schemas.GameOut])
def active_games(username: str, db: Session = Depends(get_db)):
    return crud.get_active_games_by_user(db, username)

@app.get("/completed-games/{username}", response_model=List[schemas.GameOut])
def completed_games(username: str, db: Session = Depends(get_db)):
    return crud.get_completed_games_by_user(db, username)

@app.get("/check-match")
def check_match(username: str, mode: str, db: Session = Depends(get_db)):
    user = crud.get_user_by_username(db, username)
    if not user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")

    # Kullanıcının aktif oyunu var mı kontrol et
    active_game = db.query(models.Game).filter(
        ((models.Game.player1_id == user.id) | (models.Game.player2_id == user.id)) &
        (models.Game.mode == mode) &
        (models.Game.player1_score == 0)  # Başlamış ama henüz skor alınmamış gibi kontrol
    ).first()

    if active_game:
        return {"game_id": active_game.id}

    return {"game_id": None}

@app.get("/all-pending-games")
def all_pending_games(db: Session = Depends(get_db)):
    pending = db.query(models.PendingMatch).all()
    return [{"id": p.id, "username": p.username, "mode": p.mode} for p in pending]

@app.get("/my-pending-game/{username}")
def my_pending_game(username: str, db: Session = Depends(get_db)):
    pending = db.query(models.PendingMatch).filter(models.PendingMatch.username == username).first()
    if pending:
        return {"waiting": True, "mode": pending.mode}
    return {"waiting": False}

@app.delete("/cancel-pending")
def cancel_pending(username: str, db: Session = Depends(get_db)):
    pending = db.query(models.PendingMatch).filter(models.PendingMatch.username == username).first()

    if pending:
        db.delete(pending)
        db.commit()
        return {"message": "Bekleyen oyun iptal edildi."}
    else:
        raise HTTPException(status_code=404, detail="Bekleyen oyun bulunamadı.")

@app.get("/get_active_games_by_user/{username}")
def get_active_games_by_user_endpoint(username: str, db: Session = Depends(get_db)):
    return crud.get_active_games_by_user(db, username)

@app.post("/join-pending-game")
def join_pending_game(
    pending_id: int = Body(...),
    username: str = Body(...),
    db: Session = Depends(get_db)
):
    pending = db.query(models.PendingMatch).filter(models.PendingMatch.id == pending_id).first()

    if not pending:
        raise HTTPException(status_code=404, detail="Pending match bulunamadı.")

    player1 = crud.get_user_by_username(db, pending.username)
    player2 = crud.get_user_by_username(db, username)

    if not player1 or not player2:
        raise HTTPException(status_code=404, detail="Oyuncu bulunamadı.")

    # Yeni game oluştur
    new_game = models.Game(
        player1_id=player1.id,
        player2_id=player2.id,
        mode=pending.mode,
        start_time=datetime.utcnow(),
        current_turn=1,
        is_active=True,
        is_completed=False,
        player1_score=0,
        player2_score=0
    )

    db.add(new_game)
    db.delete(pending)  # Pending'i siliyoruz
    db.commit()
    db.refresh(new_game)

    return {"message": "Oyun başarıyla oluşturuldu", "game_id": new_game.id}
