# Diário de Leitura

## Aplicação Ruby no terminal

Aplicação de terminal em **Ruby**, sem dependências externas de produção, para acompanhar livros, sessões, metas, anotações e estatísticas. Os dados ficam em um arquivo JSON local.

### Requisitos

- Ruby 3.2 ou superior (CI: 3.2, 3.3 e 3.4).
- Permissão de leitura/escrita no diretório escolhido.
- Nenhuma conta, API, banco de dados ou serviço em nuvem.

### Primeiro uso

```bash
ruby bin/diario.rb add leitura.json livro-1 "Livro demonstrativo" 120
ruby bin/diario.rb read leitura.json livro-1 2026-11-08 30 "Primeiro capitulo"
ruby bin/diario.rb read leitura.json livro-1 2026-11-09 50 "Segundo capitulo"
ruby bin/diario.rb summary leitura.json
ruby bin/diario.rb stats leitura.json
ruby bin/diario.rb book leitura.json livro-1
```

Cada sessão registra a **página acumulada** alcançada, não a quantidade de páginas da sessão. O relatório calcula a diferença em relação à sessão anterior, evitando contar páginas duas vezes.

### Catálogo, metas e histórico

```bash
ruby bin/diario.rb list leitura.json
ruby bin/diario.rb search leitura.json "livro"
ruby bin/diario.rb rename leitura.json livro-1 "Novo título"
ruby bin/diario.rb tag leitura.json livro-1 "estudo,tecnologia"
ruby bin/diario.rb goal leitura.json livro-1 15
ruby bin/diario.rb goal-report leitura.json livro-1 2026-11-09
ruby bin/diario.rb estimate leitura.json livro-1 2026-11-09
ruby bin/diario.rb history leitura.json livro-1
ruby bin/diario.rb notes leitura.json "capitulo"
ruby bin/diario.rb undo leitura.json livro-1
```

- Identificadores: 1 a 50 caracteres minúsculos, números e hífens.
- Títulos: 1 a 200 caracteres; livros: 1 a 100.000 páginas.
- Datas: ISO 8601 estrito (`AAAA-MM-DD`); sessões não podem retroceder na data ou página.
- Notas: até 2.000 caracteres; até 20 etiquetas por livro.
- Metas: 1 a 1.000 páginas/dia; `goal ... off` remove a meta.
- `undo` remove **somente a última sessão** e restaura o progresso anterior.
- Remoção permanente exige `ruby bin/diario.rb remove leitura.json livro-1 CONFIRM`. Faça backup antes.

### Análises

```bash
ruby bin/diario.rb stats leitura.json
ruby bin/diario.rb period leitura.json 2026-11-01 2026-11-30
ruby bin/diario.rb streak leitura.json
ruby bin/diario.rb monthly leitura.json
```

O sistema oferece totais de páginas, livros iniciados/concluídos, dias ativos, sequência de dias com leitura, histórico por livro, progresso percentual e média de páginas por dia ativo. A estimativa de conclusão usa a meta diária configurada ou a média dos últimos 30 dias; sem atividade recente, retorna uma previsão indisponível em vez de inventar uma data.

### Exportação e backup

```bash
ruby bin/diario.rb export leitura.json csv books relatorio-livros.csv
ruby bin/diario.rb export leitura.json csv sessions sessoes.csv livro-1
ruby bin/diario.rb export leitura.json json daily dias.json
ruby bin/diario.rb backup leitura.json leitura-backup.json
```

A exportação CSV inclui cabeçalhos e escapa texto que poderia ser interpretado como fórmula por planilhas. Arquivos de exportação e backup **nunca sobrescrevem** destinos existentes. Não utilize o mesmo caminho para origem e destino.

### Persistência e segurança

- JSON validado ao carregar e antes de salvar; erros não alteram o arquivo original.
- Gravação em arquivo temporário no mesmo diretório, com `fsync` e renomeação atômica.
- Operações de escrita usam uma trava de arquivo (`.lock`) para reduzir perda de dados em processos simultâneos que usam este aplicativo.
- Arquivos novos são privados (`0600` em sistemas POSIX); links simbólicos nos caminhos de arquivo são rejeitados.
- Tamanho máximo de 10 MiB por arquivo JSON; a aplicação não realiza sincronização remota.

**Limites:** não é um serviço web, não implementa autenticação, criptografia, edição de sessões antigas ou sincronização entre máquinas. O arquivo de trava pode permanecer após o encerramento; isso é esperado. Não edite o JSON manualmente enquanto a aplicação estiver em uso.

### Testes

```bash
ruby -Itest -e 'Dir["test/test_*.rb"].sort.each { |file| require File.expand_path(file) }'
```

A suíte Minitest cobre validação, histórico, metas, relatórios, persistência, backups, concorrência, CSV e comandos de terminal. O GitHub Actions executa os testes em Ruby 3.2, 3.3 e 3.4.

### Critérios de aceitação

1. Registrar duas sessões deve atualizar a página acumulada sem ultrapassar o total.
2. Falhas de validação não podem sobrescrever os dados anteriores.
3. Operações concorrentes realizadas pelo aplicativo não devem perder alterações.
4. Relatórios devem usar diferenças reais entre sessões, não somar páginas acumuladas.
5. Exportações e backups não podem sobrescrever arquivos existentes.

## Biblioteca Ruby e exemplos

Biblioteca local em Ruby para registrar livros, metas, sessões de leitura e notas. O núcleo e a demonstração estão implementados; Rails, interface web e SQLite continuam planejados.

### Recursos implementados

- Cadastro de livros com identificador único, total de páginas e meta.
- Registro de sessões com data, páginas lidas e nota opcional.
- Consulta de progresso, percentual, meta atingida e notas.
- Exportação e restauração de backup JSON versionado.
- Validação de datas, páginas, identificadores e estrutura do backup.

### Executar e testar

Requer Ruby; o GitHub Actions valida o projeto com Ruby 3.3.

```bash
ruby bin/demo.rb
ruby -Itest test/reading_journal_test.rb
```

A demonstração usa um livro fictício de 120 páginas e registra sessões de 20 e 40 páginas. O resultado mostra 60 páginas lidas, 50% de progresso e a meta de 60 páginas atingida.

### Usar a biblioteca

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

### Limites

Os dados ficam em memória; a exportação retorna uma string JSON e não grava um arquivo automaticamente. Não há autenticação, sincronização, banco de dados ou interface web. Use dados fictícios nos exemplos e mantenha backups pessoais fora do repositório.

O roteiro histórico está em [docs/PRIMEIRO_INCREMENTO.md](docs/PRIMEIRO_INCREMENTO.md). Recursos futuros ali descritos não representam funcionalidades já entregues.
