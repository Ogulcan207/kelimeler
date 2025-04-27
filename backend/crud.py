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
        mode=game_data.mode.value,
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

    games = db.query(models.Game).filter(
        ((models.Game.player1_id == user.id) | (models.Game.player2_id == user.id)),
        models.Game.is_active == True
    ).all()

    result = []
    for game in games:
        opponent_id = game.player2_id if game.player1_id == user.id else game.player1_id
        opponent = db.query(models.User).filter(models.User.id == opponent_id).first()

        result.append({
            "id": game.id,
            "mode": game.mode,
            "player1_score": game.player1_score,
            "player2_score": game.player2_score,
            "current_turn": game.current_turn,
            "opponent": opponent.username if opponent else "Bilinmiyor"
        })

    return result

def get_completed_games_by_user(db: Session, username: str):
    user = get_user_by_username(db, username)
    if not user:
        return []
    return db.query(models.Game).filter(
        ((models.Game.player1_id == user.id) | (models.Game.player2_id == user.id)),
        models.Game.is_completed == True
    ).all()

def match_or_create_game(db: Session, username: str, mode: str):
    pending_match = db.query(models.PendingMatch).filter(models.PendingMatch.mode == mode).first()

    if pending_match and pending_match.username != username:
        # Eşleştir ve yeni oyun oluştur
        player1 = get_user_by_username(db, pending_match.username)
        player2 = get_user_by_username(db, username)

        if not player1 or not player2:
            raise HTTPException(status_code=404, detail="Oyuncu bulunamadı")

        # Pending eşleşmeyi sil
        db.delete(pending_match)
        db.commit()

        new_game = Game(
            player1_id=player1.id,
            player2_id=player2.id,
            mode=mode,
            start_time=datetime.utcnow(),
            current_turn=1
        )
        db.add(new_game)
        db.commit()
        db.refresh(new_game)
        return new_game

    else:
        # Bekleyen yoksa yeni pending match oluştur
        pending = models.PendingMatch(username=username, mode=mode)
        db.add(pending)
        db.commit()
        return None

def get_active_games_by_user(db: Session, username: str):
    user = get_user_by_username(db, username)
    if not user:
        return []

    games = db.query(models.Game).filter(
        ((models.Game.player1_id == user.id) | (models.Game.player2_id == user.id)),
        models.Game.is_active == True
    ).all()

    result = []
    for game in games:
        opponent_id = game.player2_id if game.player1_id == user.id else game.player1_id
        opponent = db.query(models.User).filter(models.User.id == opponent_id).first()

        result.append({
            "id": game.id,
            "mode": game.mode,
            "player1_score": game.player1_score,
            "player2_score": game.player2_score,
            "current_turn": game.current_turn,
            "opponent": opponent.username if opponent else "Bilinmiyor"
        })

    return result
