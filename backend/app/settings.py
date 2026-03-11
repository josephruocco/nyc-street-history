from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    card_cache_ttl_seconds: int = 10
    card_cache_precision: int = 7

    class Config:
        env_prefix = ""
        case_sensitive = False


settings = Settings()
