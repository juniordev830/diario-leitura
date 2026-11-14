# Diário de Leitura

Biblioteca local em Ruby para registrar livros, metas, sessões de leitura e notas. O núcleo e a demonstração estão implementados; Rails, interface web e SQLite continuam planejados.

## Recursos implementados

- Cadastro de livros com identificador único, total de páginas e meta.
- Registro de sessões com data, páginas lidas e nota opcional.
- Consulta de progresso, percentual, meta atingida e notas.
- Exportação e restauração de backup JSON versionado.
- Validação de datas, páginas, identificadores e estrutura do backup.

## Executar e testar

Requer Ruby; o GitHub Actions valida o projeto com Ruby 3.3.

```bash
ruby bin/demo.rb
ruby -Itest test/reading_journal_test.rb
```

A demonstração usa um livro fictício de 120 páginas e registra sessões de 20 e 40 páginas. O resultado mostra 60 páginas lidas, 50% de progresso e a meta de 60 páginas atingida.

## Usar a biblioteca

```ruby
require_relative 'lib/reading_journal'

journal = ReadingJournal.new
journal.add_book(id: 'livro', title: 'Livro fictício', total_pages: 120, goal_pages: 60)
journal.record(id: 'livro', date: '2026-11-10', pages: 20, note: 'Introdução')
puts journal.progress('livro')
backup = journal.to_json
restored = ReadingJournal.from_json(backup)
```

Cada sessão acrescenta páginas ao progresso. O total acumulado não pode exceder o tamanho do livro. A meta omitida usa o total de páginas.

O retorno de `add_book` é uma cópia congelada: alterações devem passar pelos métodos da biblioteca. Textos armazenados não compartilham referências mutáveis com entradas ou resultados de consultas. Backups com sessões que não sejam objetos são rejeitados com `ArgumentError`.

## Limites

Os dados ficam em memória; a exportação retorna uma string JSON e não grava um arquivo automaticamente. Não há autenticação, sincronização, banco de dados ou interface web. Use dados fictícios nos exemplos e mantenha backups pessoais fora do repositório.

O roteiro histórico está em [docs/PRIMEIRO_INCREMENTO.md](docs/PRIMEIRO_INCREMENTO.md). Recursos futuros ali descritos não representam funcionalidades já entregues.
