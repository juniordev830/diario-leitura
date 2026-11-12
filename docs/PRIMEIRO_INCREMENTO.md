# Primeiro incremento verificável — Diário de Leitura

**Estado confirmado:** apenas documentação de concepção (`README.md`). Não existem Rails, SQLite, testes ou aplicação funcional neste repositório.

## Entidades propostas

- `Livro`: identificador, título, total de páginas e página atual.
- `Sessao`: livro, data, páginas avançadas e observação opcional.
- `Nota`: sessão associada, conteúdo com limite definido.

## Fluxo mínimo para implementar

1. Criar registro de livro com total de páginas maior que zero.
2. Registrar uma sessão com avanço positivo sem ultrapassar o total.
3. Calcular página atual e percentual de conclusão.
4. Consultar sessões em ordem cronológica.
5. Recusar sessão negativa, livro inexistente e avanço acima do limite.

## Critérios de aceitação

- Um livro de 100 páginas com sessões de 20 e 30 páginas mostra 50/100 e 50%.
- Uma tentativa posterior de registrar 60 páginas é rejeitada sem alterar o histórico.
- O cálculo usa dados de teste, sem criar registros de leitura reais.

## Implementação

Ruby/Rails/SQLite são **proposta**, não stack instalada. Primeiro desenvolver testes de domínio puros, depois escolher persistência. Não anunciar um app executável antes de existir um comando de teste funcionando.
