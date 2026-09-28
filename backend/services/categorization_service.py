def categorizar_transacao(descricao: str):
    descricao = descricao.lower()

    regras = {
        "alimentação": [
            "ifood",
            "restaurante",
            "lanchonete",
            "mercado",
            "supermercado",
            "padaria",
        ],
        "transporte": [
            "uber",
            "99",
            "posto",
            "combustivel",
            "gasolina",
            "estacionamento",
        ],
        "moradia": [
            "aluguel",
            "condominio",
            "energia",
            "água",
            "internet",
        ],
        "lazer": [
            "cinema",
            "netflix",
            "spotify",
            "steam",
            "jogo",
        ],
        "saúde": [
            "farmacia",
            "farmácia",
            "hospital",
            "consulta",
            "academia",
        ],
    }

    for categoria, palavras in regras.items():
        for palavra in palavras:
            if palavra in descricao:
                return categoria

    return None