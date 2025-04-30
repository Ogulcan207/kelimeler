from sqlalchemy.orm import Session
from backend import models, schemas
import hashlib, random,string
from .models import Game, GameMode
from datetime import datetime
from fastapi import HTTPException
from sqlalchemy import text

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

FIXED_BONUS_POSITIONS = {
    "k3": [
        (0,2) , (2,0), (12,0) , (0,12), (14,2) , (2,14), (14,12) , (12,14)
    ],
    "k2": [
        (3,3) ,(7,2) , (11,3), (2,7) , (3,11), (11,11) , (7,12), (12,7)
    ],
    "h3": [
        (1,1) , (4,4), (13,13) , (10,10), (13,1) , (1,13), (10,4) , (4,10), (7,7)
    ],
    "h2": [
        (5,0) , (9,0), (6,1) , (8,1), (0,5) , (1,6), (0,9) , (1,8), (5,5) , (6,6), (8,8) , (9,9), (14,5) , (13,6), (13,8) , (14,9), (5,14) , (6,13), (8,13) , (9,14), (8,6) , (9,5), (5,9) , (6,8)
    ]
}

SPECIAL_TYPES = (
    ['puan_bolunmesi'] * 5 +
    ['puan_transferi'] * 4 +
    ['harf_kaybi'] * 3 +
    ['ekstra_hamle_engeli'] * 2 +
    ['kelime_iptali'] * 2 +
    ['bolge_yasagi'] * 2 +
    ['harf_yasagi'] * 3 +
    ['ekstra_hamle_jokeri'] * 2
)

def create_game_grid(db: Session, game_id: int):
    existing = db.query(models.GameGrid).filter(models.GameGrid.game_id == game_id).first()
    if existing:
        return

    grid_data = []
    used_positions = set()

    # Sabit bonus kareleri ekle
    for bonus, positions in FIXED_BONUS_POSITIONS.items():
        for (r, c) in positions:
            grid_data.append(models.GameGrid(
                game_id=game_id, row=r, col=c, letter=None, special_type=bonus
            ))
            used_positions.add((r, c))

    # Mayınları bonus olmayan yerlere rastgele yerleştir
    for special in SPECIAL_TYPES:
        while True:
            r, c = random.randint(0, 14), random.randint(0, 14)
            if (r, c) not in used_positions:
                grid_data.append(models.GameGrid(
                    game_id=game_id, row=r, col=c, letter=None, special_type=special
                ))
                used_positions.add((r, c))
                break

    # Kalan hücreleri boş ekle
    for r in range(15):
        for c in range(15):
            if (r, c) not in used_positions:
                grid_data.append(models.GameGrid(
                    game_id=game_id, row=r, col=c, letter=None, special_type=None
                ))

    db.add_all(grid_data)
    db.commit()


def play_move_logic(db: Session, move: schemas.PlayMove):
    game = db.query(models.Game).filter(models.Game.id == move.game_id).first()
    if not game:
        raise HTTPException(status_code=404, detail="Oyun bulunamadı.")

    user = get_user_by_username(db, move.username)
    if not user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı.")

    # Oyuncunun sırası mı?
    if (game.current_turn == 1 and game.player1_id != user.id) or \
       (game.current_turn == 2 and game.player2_id != user.id):
        raise HTTPException(status_code=403, detail="Sıra sende değil.")

    # Basit puan: kelime uzunluğu * 10
    score = len(move.word) * 10
    if game.player1_id == user.id:
        game.player1_score += score
        game.current_turn = 2
    else:
        game.player2_score += score
        game.current_turn = 1

    # Grid’e harfleri yaz
    for pos, char in zip(move.positions, move.word):
        cell = db.query(models.GameGrid).filter_by(game_id=move.game_id, row=pos.row, col=pos.col).first()
        if cell:
            cell.letter = char
        else:
            new_cell = models.GameGrid(
                game_id=move.game_id,
                row=pos.row,
                col=pos.col,
                letter=char
            )
            db.add(new_cell)

    db.commit()
    return {
        "message": "Hamle başarılı",
        "updated_score": game.player1_score if game.player1_id == user.id else game.player2_score,
        "next_turn": game.player2.username if game.player1_id == user.id else game.player1.username
    }
