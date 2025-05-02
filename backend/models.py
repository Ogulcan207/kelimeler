from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Enum, Boolean
from sqlalchemy.orm import relationship
from backend.database import Base
import enum
from datetime import datetime

class GameMode(enum.Enum):
    fast_2_min = "2_min"
    fast_5_min = "5_min"
    extended_12_hour = "12_hour"
    extended_24_hour = "24_hour"

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False)
    email = Column(String(100), unique=True, nullable=False)
    password = Column(String(100), nullable=False)

    games_as_player1 = relationship("Game", back_populates="player1", foreign_keys='Game.player1_id')
    games_as_player2 = relationship("Game", back_populates="player2", foreign_keys='Game.player2_id')

class Game(Base):
    __tablename__ = "games"

    id = Column(Integer, primary_key=True, index=True)
    player1_id = Column(Integer, ForeignKey("users.id"))
    player2_id = Column(Integer, ForeignKey("users.id"))
    mode = Column(Enum(GameMode), nullable=False)
    start_time = Column(DateTime, default=datetime.utcnow)
    player1_score = Column(Integer, default=0)
    player2_score = Column(Integer, default=0)
    current_turn = Column(Integer)  # 1 or 2
    is_active = Column(Boolean, default=True)  # ✅ aktif mi?
    is_completed = Column(Boolean, default=False)  # ✅ bitmiş mi?

    player1 = relationship("User", foreign_keys=[player1_id], back_populates="games_as_player1")
    player2 = relationship("User", foreign_keys=[player2_id], back_populates="games_as_player2")
    end_time = Column(DateTime, nullable=True)  # 🎯 Burası yeni eklenen alan

class PendingMatch(Base):
    __tablename__ = "pending_matches"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), nullable=False)
    mode = Column(Enum(GameMode), nullable=False)

class GameGrid(Base):
    __tablename__ = "game_grid"

    id = Column(Integer, primary_key=True, index=True)
    game_id = Column(Integer, ForeignKey("games.id"), nullable=False)
    row = Column(Integer, nullable=False)
    col = Column(Integer, nullable=False)
    letter = Column(String(1), nullable=True)  # Hamle yapılmadıysa boş olabilir
    special_type = Column(String(50), nullable=True)  # bonus veya mayın tipi (örn: 'puan_bolme')

# models.py
class LetterPool(Base):
    __tablename__ = 'letter_pool'
    id = Column(Integer, primary_key=True)
    game_id = Column(Integer, ForeignKey("games.id"))
    letter = Column(String(2), nullable=False)
    remaining_count = Column(Integer, nullable=False)

class PlayerLetters(Base):
    __tablename__ = "player_letters"
    id = Column(Integer, primary_key=True)
    game_id = Column(Integer)
    username = Column(String)  # ✅ bu olmalı
    letter = Column(String)
    point = Column(Integer)
    used = Column(Boolean, default=False)