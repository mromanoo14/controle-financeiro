# Controle Financeiro v2

App para organizar o salário: separa os gastos por **departamento** (categoria), **prevê** quanto vai gastar e quanto vai sobrar, aceita **lançamentos manuais** e importa transações dos bancos via **Open Finance**. Foi pensado para ser vendido por **assinatura mensal**.

```
v2/
├── backend/   API em Python (FastAPI + PostgreSQL)
└── app/       App em Flutter (Android, iOS, Windows, macOS, Linux e Web)
```

## O que já funciona

| Recurso | Grátis | Premium (e teste de 14 dias) |
|---|:-:|:-:|
| Cadastro, login e token salvo com segurança no aparelho | ✔ | ✔ |
| Contas, cartões e carteira, com saldo | ✔ | ✔ |
| Lançamento manual de gastos e receitas | ✔ | ✔ |
| Categorização automática por departamento | ✔ | ✔ |
| O app aprende quando você corrige uma categoria | ✔ | ✔ |
| Contas fixas, salário e compras parceladas | ✔ | ✔ |
| Orçamento mensal por departamento | ✔ | ✔ |
| Previsão do mês atual (fixos + média dos gastos variáveis) | ✔ | ✔ |
| Previsão dos próximos meses | | ✔ |
| Conexão com bancos (Open Finance) | | ✔ |
| Exclusão da conta e de todos os dados (LGPD) | ✔ | ✔ |

### Como a previsão funciona

```
previsto no mês = já gasto
                + contas fixas que ainda vão vencer
                + estimativa de gastos variáveis
```

A estimativa variável usa a média de cada departamento nos últimos 3 meses, proporcional aos dias que faltam no mês. Lançamentos que correspondem a uma conta fixa (como o aluguel) não entram nessa média, para não serem contados duas vezes. Quando um lançamento parecido com uma conta fixa aparece (descrição semelhante e valor até 15% diferente), ele é marcado automaticamente como pago.

## Rodando no seu computador

### 1. Backend

Pré-requisito: Python 3.12 ou mais novo (no Windows, marque "Add python.exe to PATH" ao instalar).

```bash
cd v2/backend
cp .env.example .env           # no Windows: copy .env.example .env
python -m venv .venv
source .venv/bin/activate      # no Windows: .venv\Scripts\activate
pip install -r requirements-dev.txt
alembic upgrade head
uvicorn app.main:app --reload
```

O `.env` de exemplo usa SQLite (um arquivo `dev.db` local), então não precisa instalar banco de dados para testar. Para usar PostgreSQL, rode `docker compose up -d db` e troque o `DATABASE_URL` conforme o comentário no `.env`.

A documentação interativa da API fica em http://localhost:8000/docs.

Para rodar os testes:

```bash
pytest
```

Para subir tudo com Docker (API + banco): `docker compose up --build`.

### 2. App

Pré-requisitos: [Flutter](https://docs.flutter.dev/get-started/install) 3.47 ou mais recente.

```bash
cd v2/app
flutter pub get
flutter run -d chrome --web-port 8080
```

Use a porta 8080 no Chrome: é a que o backend libera por padrão (`CORS_ORIGINS`).

Por padrão, o app procura a API em `http://10.0.2.2:8000` no emulador Android e em `http://localhost:8000` nas outras plataformas. Num celular de verdade, use o IP do seu computador na rede:

```bash
flutter run --dart-define=API_URL=http://192.168.0.10:8000
```

## Gerando os executáveis

Em produção, troque a URL pela da sua API publicada (sempre com HTTPS).

| Plataforma | Comando | Onde fica o arquivo |
|---|---|---|
| Android (APK para instalar direto) | `flutter build apk --release --dart-define=API_URL=https://api.seudominio.com.br` | `build/app/outputs/flutter-apk/app-release.apk` |
| Android (Play Store) | `flutter build appbundle --release --dart-define=API_URL=...` | `build/app/outputs/bundle/release/app-release.aab` |
| Windows | `flutter build windows --release --dart-define=API_URL=...` | `build/windows/x64/runner/Release/` |
| iOS (requer Mac + Xcode) | `flutter build ipa --release --dart-define=API_URL=...` | `build/ios/ipa/` |
| Web | `flutter build web --release --dart-define=API_URL=...` | `build/web/` |

**Sem instalar nada:** o workflow `.github/workflows/v2.yml` roda os testes e gera o APK e o executável do Windows a cada push. Baixe os arquivos em *GitHub → Actions → execução → Artifacts*. Para definir a URL da API, crie a variável `API_URL` em *Settings → Secrets and variables → Actions → Variables*.

### Assinatura do Android (obrigatória para a Play Store)

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Crie `v2/app/android/key.properties` (já está no `.gitignore`):

```
storePassword=SUA_SENHA
keyPassword=SUA_SENHA
keyAlias=upload
storeFile=/home/voce/upload-keystore.jks
```

Sem esse arquivo, o build de release é assinado com a chave de debug, que serve só para testes.

## Publicando na internet

**Backend no Render:** o arquivo `render.yaml` na raiz do repositório descreve a API e o banco.
1. Crie uma conta em https://render.com e conecte o GitHub.
2. Clique em **New → Blueprint**, escolha este repositório e confirme. O Render cria o banco, gera a `SECRET_KEY` e publica a API.
3. Copie o endereço da API (ex.: `https://controle-financeiro-api.onrender.com`) e teste `/health` nele.

O plano gratuito serve para testar: a API "dorme" depois de 15 minutos sem uso, e o banco gratuito expira em 30 dias. Para uso real, troque no `render.yaml` para `starter` (API) e `basic-256mb` (banco), por cerca de US$ 13 por mês.

**App web no GitHub Pages** (abre no Safari do iPhone e no Chrome):
1. Em *Settings → Pages*, escolha **Source: GitHub Actions**.
2. Em *Settings → Secrets and variables → Actions → Variables*, crie `API_URL` com o endereço da API do Render.
3. A cada atualização da `main`, o workflow publica o app em `https://<usuario>.github.io/<repositorio>/`.

No iPhone, abra o endereço no Safari, toque em **Compartilhar → Adicionar à Tela de Início**, e ele passa a abrir como um app.

## Antes de vender: o que ainda falta

1. **Publicar o backend** com HTTPS: Railway, Render, Fly.io ou uma VPS, com PostgreSQL gerenciado. O `Dockerfile` já aplica as migrações ao subir. Em produção, defina `ENVIRONMENT=production`, gere uma `SECRET_KEY` forte e restrinja `CORS_ORIGINS`.
2. **Open Finance de verdade:** crie uma conta num agregador (a integração com a [Pluggy](https://pluggy.ai) já está pronta). Depois:
   - preencha `OPEN_FINANCE_PROVIDER=pluggy`, `PLUGGY_CLIENT_ID` e `PLUGGY_CLIENT_SECRET`;
   - configure o webhook para `https://sua-api/open-finance/webhook`, com o cabeçalho `X-Webhook-Secret` igual a `OPEN_FINANCE_WEBHOOK_SECRET`.

   Até lá, o modo `mock` simula um banco com dados de exemplo. Valide o fluxo do widget (`app/lib/screens/open_finance/pluggy_connect_screen.dart`) com uma chave de sandbox, porque o formato exato dos eventos do Pluggy Connect precisa ser conferido na documentação deles.
3. **Pagamento da assinatura:** nas lojas, assinaturas dentro do app precisam usar o Google Play Billing e o Apple In-App Purchase. Sugestão: [RevenueCat](https://www.revenuecat.com) ou o pacote `in_app_purchase`. O backend já tem a interface (`app/services/billing`) e a rota `POST /subscription/purchase`. Falta:
   - implementar a validação do comprovante com a loja;
   - trocar a compra simulada em `app/lib/screens/subscription/subscription_screen.dart` pela compra real.

   O provedor simulado se recusa a funcionar em produção.
4. **Documentos legais:** Termos de Uso e Política de Privacidade (obrigatórios nas lojas e pela LGPD). A tela de cadastro já pede o aceite, mas ainda não tem link para os textos.
5. **Identidade do app:** ícone, nome definitivo e o `applicationId` / Bundle ID com o domínio da sua empresa.
6. **Recuperação de senha por e-mail:** precisa de um serviço de envio de e-mail (ex.: Resend, SES).

## Estrutura do backend

```
app/
├── main.py               # cria a API e registra as rotas
├── core/config.py        # configurações (.env)
├── core/security.py      # senha (Argon2) e JWT
├── models/               # tabelas (SQLAlchemy)
├── schemas/              # formatos de entrada/saída (Pydantic)
├── routers/              # rotas HTTP
└── services/
    ├── categorization.py # departamentos e regras aprendidas
    ├── recurrence.py     # contas fixas e parcelas
    ├── forecast.py       # previsão
    ├── finance.py        # saldos, resumos, criação de transações
    ├── subscription.py   # plano, teste grátis, Premium
    ├── billing/          # validação de compras (simulada)
    └── open_finance/     # provedores (mock, Pluggy) e sincronização
```

Para criar uma migração depois de mudar os modelos:

```bash
alembic revision --autogenerate -m "descricao"
```

```bash
alembic upgrade head
```
