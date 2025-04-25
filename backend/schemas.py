from pydantic import BaseModel, EmailStr
from enum import Enum
from datetime import datetime

class UserCreate(BaseModel):
    username: str
    email: EmailStr
    password: str

class UserLogin(BaseModel):
    username: str
    password: str

class GameMode(str, Enum):
    fast_2_min = "2_min"
    fast_5_min = "5_min"
    extended_12_hour = "12_hour"
    extended_24_hour = "24_hour"

class GameCreate(BaseModel):
    player1_id: int
    player2_id: int
    mode: GameMode  # örnek: '2_min', '5_min', '12_hour', '24_hour'

class GameOut(BaseModel):
    id: int
    mode: GameMode
    start_time: datetime
    player1_score: int
    player2_score: int
    current_turn: int

    class Config:
        orm_mode = True