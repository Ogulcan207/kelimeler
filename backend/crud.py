from sqlalchemy.orm import Session
from backend import models, schemas
import hashlib
from .models import Game, GameMode
from datetime import datetime
from fastapi import HTTPException

def get_user_by_username(db: Session, username: str):
    return db.query(models.User).filter(models.User.username == username).first()

def create_user(db: Session, user: schemas.UserCreate):
    # Kullanıcı adı kontrolü
    existing_user = db.query(models.User).filter(models.User.username == user.username).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Bu kullanıcı adı zaten alınmış.")

    existing_email = db.query(models.User).filter(models.User.email == user.email).first()
    if existing_email:
        raise HTTPException(status_code=400, detail="Bu e-posta adresi zaten kayıtlı.")

    hashed_pw = hashlib.sha256(user.password.encode()).hexdigest()
    db_user = models.User(username=user.username, email=user.email, password=hashed_pw)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def authenticate_user(db: Session, username: str, password: str):
    user = get_user_by_username(db, username)
    if not user:
        return None
    hashed_pw = hashlib.sha256(password.encode()).hexdigest()
    if user.password != hashed_pw:
        return None
    return user

def create_game(db: Session, game_data: schemas.GameCreate):
    new_game = Game(
        player1_id=game_data.player1_id,
        player2_id=game_data.player2_id,
        mode=GameMode(game_data.mode),
        start_time=datetime.utcnow(),
        current_turn=1
    )
    db.add(new_game)
    db.commit()
    db.refresh(new_game)
    return new_game

def get_active_games_by_user(db: Session, username: str):
    user = get_user_by_username(db, username)
    if not user:
        return []
    return db.query(models.Game).filter(
        ((models.Game.player1_id == user.id) | (models.Game.player2_id == user.id)),
        models.Game.is_active == True
    ).all()

def get_completed_games_by_user(db: Session, username: str):
    user = get_user_by_username(db, username)
    if not user:
        return []
    return db.query(models.Game).filter(
        ((models.Game.player1_id == user.id) | (models.Game.player2_id == user.id)),
        models.Game.is_completed == True
    ).all()

def match_or_create_game(db: Session, username: str, mode: str):
    existing_match = db.query(models.PendingMatch).filter(models.PendingMatch.mode == mode).first()
    if existing_match and existing_match.username != username:
        # Eşleştir ve oyun oluştur
        db.delete(existing_match)
        db.commit()
        return create_game(db, player1_username=existing_match.username, player2_username=username, mode=mode)
    else:
        # Kuyruğa ekle
        pending = models.PendingMatch(username=username, mode=mode)
        db.add(pending)
        db.commit()
        return None  # Beklemeye alındı
