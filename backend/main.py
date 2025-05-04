from fastapi import FastAPI, Depends, HTTPException, Form, Body
from sqlalchemy.orm import Session
from backend import models, schemas, crud
from backend.database import engine, SessionLocal
from typing import List
from datetime import datetime, timedelta
from backend.crud import initialize_letter_pool, deal_letters_to_players
import random
from pytz import timezone
from fastapi.responses import JSONResponse
TR_TIMEZONE = timezone('Europe/Istanbul')

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
        return {"message": "Oyun başlatıldı", "game_id": result.id}
    else:
        return {"message": "Bekleniyor", "waiting": True}

@app.get("/active-games/{username}", response_model=List[schemas.GameOut])
def active_games(username: str, db: Session = Depends(get_db)):
    return crud.get_active_games_by_user(db, username)

@app.get("/completed-games/{username}")
def completed_games(username: str, db: Session = Depends(get_db)):
    return crud.get_completed_games_by_user(db, username)

@app.get("/check-match")
def check_match(username: str, mode: str, db: Session = Depends(get_db)):
    user = crud.get_user_by_username(db, username)
    if not user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")

    active_game = db.query(models.Game).filter(
        ((models.Game.player1_id == user.id) | (models.Game.player2_id == user.id)) &
        (models.Game.mode == mode) &
        (models.Game.is_active == True)
    ).order_by(models.Game.start_time.desc()).first()  # En güncel oyunu getir

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

    starting_turn = random.choice([1, 2])

    mode_value = pending.mode.value
    if mode_value == "2_min":
        duration = timedelta(minutes=2)
    elif mode_value == "5_min":
        duration = timedelta(minutes=5)
    elif mode_value == "12_hour":
        duration = timedelta(hours=12)
    elif mode_value == "24_hour":
        duration = timedelta(hours=24)
    else:
        raise HTTPException(status_code=400, detail="Geçersiz oyun modu")

    # 🧩 Yeni oyun
    new_game = models.Game(
        player1_id=player1.id,
        player2_id=player2.id,
        mode=pending.mode,
        start_time=datetime.now(TR_TIMEZONE),
        end_time=datetime.now(TR_TIMEZONE) + duration,
        current_turn=starting_turn,
        is_active=True,
        is_completed=False,
        player1_score=0,
        player2_score=0
    )

    db.add(new_game)
    db.delete(pending)
    db.commit()
    db.refresh(new_game)

    crud.create_game_grid(db, new_game.id)
    initialize_letter_pool(db, new_game.id)
    deal_letters_to_players(db, new_game.id, [player1.id, player2.id])

    return {
        "message": "Oyun başarıyla oluşturuldu",
        "game_id": new_game.id,
        "starting_turn": starting_turn,
        "player1": player1.username,
        "player2": player2.username,
        "mode": new_game.mode
    }

@app.get("/grid/{game_id}")
def get_game_grid(game_id: int, db: Session = Depends(get_db)):
    grid = db.execute(
        """SELECT `row`, `col`, letter, special_type FROM game_grid
           WHERE game_id = :game_id""",
        {"game_id": game_id}
    ).fetchall()

    return [
        {
            "row": cell[0],
            "col": cell[1],
            "letter": cell[2],
            "special_type": cell[3]
        } for cell in grid
    ]

@app.get("/start-board/{game_id}")
def start_board(game_id: int, db: Session = Depends(get_db)):
    grid = db.query(models.GameGrid).filter(models.GameGrid.game_id == game_id).all()

    board = [
        {
            "row": cell.row,
            "col": cell.col,
            "letter": cell.letter,
            "special_type": cell.special_type,
        }
        for cell in grid
    ]

    return {"board": board}  # ✅ BU formatı döndür

@app.get("/win-stats/{username}")
def get_win_stats(username: str, db: Session = Depends(get_db)):
    user = crud.get_user_by_username(db, username)
    if not user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")

    games = db.query(models.Game).filter(
        ((models.Game.player1_id == user.id) | (models.Game.player2_id == user.id)),
        models.Game.is_completed == True
    ).all()

    total = len(games)
    wins = 0

    for game in games:
        you_are_p1 = game.player1_id == user.id
        your_score = game.player1_score if you_are_p1 else game.player2_score
        opp_score = game.player2_score if you_are_p1 else game.player1_score
        if your_score > opp_score:
            wins += 1

    percentage = int((wins / total) * 100) if total > 0 else 0
    return {"win_rate": percentage, "played": total, "wins": wins}

@app.get("/get-letters/{game_id}/{username}")
def get_player_letters(game_id: int, username: str, db: Session = Depends(get_db)):
    letters = db.query(models.PlayerLetters).filter_by(
        game_id=game_id,
        username=username,
        used=False  # 🔥 Sadece eldeki harfler
    ).all()
    return JSONResponse(
        content={"letters": [{"letter": l.letter, "point": l.point} for l in letters]},
        media_type="application/json; charset=utf-8"
    )

@app.post("/play-move")
def play_move(move: schemas.PlayMove, db: Session = Depends(get_db)):
    return crud.play_move_logic(db, move)

@app.post("/pass-turn")
def pass_turn(game_id: int = Body(...), username: str = Body(...), db: Session = Depends(get_db)):
    game = db.query(models.Game).filter(models.Game.id == game_id).first()
    user = crud.get_user_by_username(db, username)

    if not game or not user:
        raise HTTPException(status_code=404, detail="Oyun veya kullanıcı bulunamadı")

    if (game.current_turn == 1 and game.player1_id != user.id) or \
       (game.current_turn == 2 and game.player2_id != user.id):
        raise HTTPException(status_code=403, detail="Sıra sende değil")

    game.current_turn = 2 if game.current_turn == 1 else 1
    db.commit()
    return {"message": "Pas geçildi", "next_turn": game.current_turn}

@app.post("/surrender")
def surrender(game_id: int = Body(...), username: str = Body(...), db: Session = Depends(get_db)):
    game = db.query(models.Game).filter(models.Game.id == game_id).first()
    user = crud.get_user_by_username(db, username)

    if not game or not user:
        raise HTTPException(status_code=404, detail="Oyun veya kullanıcı bulunamadı")

    game.is_active = False
    game.is_completed = True

    if game.player1_id == user.id:
        game.player2_score += 500  # Teslim olan kaybeder
    else:
        game.player1_score += 500

    db.commit()
    return {"message": "Teslim olundu", "winner": game.player2_id if game.player1_id == user.id else game.player1_id}
