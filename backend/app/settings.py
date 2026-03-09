from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    card_cache_ttl_seconds: int = 45
    card_cache_precision: int = 6

    class Config:
        env_prefix = ""
        case_sensitive = False


settings = Settings()
