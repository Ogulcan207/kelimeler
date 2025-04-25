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