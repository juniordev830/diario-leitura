# Diário de Leitura — Rails API MVP

API em **Ruby on Rails 7.2 e SQLite** para acompanhar livros, metas e sessões de leitura.

## Funcionalidades
- Criar livro com título, total de páginas e meta opcional.
- Listar livros e consultar percentual de progresso.
- Registrar sessões com última página lida e anotação.
- Impedir regressão de página e leitura acima do total.
- Persistência SQLite e teste de integração cobrindo duas sessões.

## Executar
Requer Ruby 3.3 e Bundler:
```bash
bundle install
bundle exec rails db:prepare
bundle exec rails server
```
API local padrão: http://localhost:3000

## Endpoints
- `GET /health`
- `GET /books`
- `POST /books` — `{"title":"Livro exemplo","total_pages":120,"goal_pages":100}`
- `GET /books/:id`
- `POST /books/:book_id/sessions` — `{"ending_page":20,"note":"Primeira leitura"}`

## Testes
```bash
RAILS_ENV=test bundle exec rails db:prepare
RAILS_ENV=test bundle exec rails test
```

## Limitações
API educacional local sem contas de usuário, frontend, autenticação ou hospedagem. Não publique na internet antes de acrescentar autenticação, autorização e segurança de produção. Em produção, configure `SECRET_KEY_BASE` forte e proteção dos dados.
