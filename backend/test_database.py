from sqlalchemy import text

from database import engine


try:
    with engine.connect() as connection:
        result = connection.execute(
            text("SELECT version();")
        )

        print("Conexão com PostgreSQL realizada!")
        print(result.fetchone())

except Exception as erro:
    print("Erro ao conectar com PostgreSQL:")
    print(erro)