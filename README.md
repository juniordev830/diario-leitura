# Diário de Leitura

Aplicação de terminal em **Ruby**, sem dependências externas de produção, para acompanhar livros, sessões, metas, anotações e estatísticas. Os dados ficam em um arquivo JSON local.

## Requisitos

- Ruby 3.2 ou superior (CI: 3.2, 3.3 e 3.4).
- Permissão de leitura/escrita no diretório escolhido.
- Nenhuma conta, API, banco de dados ou serviço em nuvem.

## Primeiro uso

```bash
ruby bin/diario.rb add leitura.json livro-1 "Livro demonstrativo" 120
ruby bin/diario.rb read leitura.json livro-1 2026-11-08 30 "Primeiro capitulo"
ruby bin/diario.rb read leitura.json livro-1 2026-11-09 50 "Segundo capitulo"
ruby bin/diario.rb summary leitura.json
ruby bin/diario.rb stats leitura.json
ruby bin/diario.rb book leitura.json livro-1
```

Cada sessão registra a **página acumulada** alcançada, não a quantidade de páginas da sessão. O relatório calcula a diferença em relação à sessão anterior, evitando contar páginas duas vezes.

## Catálogo, metas e histórico

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

## Análises

```bash
ruby bin/diario.rb stats leitura.json
ruby bin/diario.rb period leitura.json 2026-11-01 2026-11-30
ruby bin/diario.rb streak leitura.json
ruby bin/diario.rb monthly leitura.json
```

O sistema oferece totais de páginas, livros iniciados/concluídos, dias ativos, sequência de dias com leitura, histórico por livro, progresso percentual e média de páginas por dia ativo. A estimativa de conclusão usa a meta diária configurada ou a média dos últimos 30 dias; sem atividade recente, retorna uma previsão indisponível em vez de inventar uma data.

## Exportação e backup

```bash
ruby bin/diario.rb export leitura.json csv books relatorio-livros.csv
ruby bin/diario.rb export leitura.json csv sessions sessoes.csv livro-1
ruby bin/diario.rb export leitura.json json daily dias.json
ruby bin/diario.rb backup leitura.json leitura-backup.json
```

A exportação CSV inclui cabeçalhos e escapa texto que poderia ser interpretado como fórmula por planilhas. Arquivos de exportação e backup **nunca sobrescrevem** destinos existentes. Não utilize o mesmo caminho para origem e destino.

## Persistência e segurança

- JSON validado ao carregar e antes de salvar; erros não alteram o arquivo original.
- Gravação em arquivo temporário no mesmo diretório, com `fsync` e renomeação atômica.
- Operações de escrita usam uma trava de arquivo (`.lock`) para reduzir perda de dados em processos simultâneos que usam este aplicativo.
- Arquivos novos são privados (`0600` em sistemas POSIX); links simbólicos nos caminhos de arquivo são rejeitados.
- Tamanho máximo de 10 MiB por arquivo JSON; a aplicação não realiza sincronização remota.

**Limites:** não é um serviço web, não implementa autenticação, criptografia, edição de sessões antigas ou sincronização entre máquinas. O arquivo de trava pode permanecer após o encerramento; isso é esperado. Não edite o JSON manualmente enquanto a aplicação estiver em uso.

## Testes

```bash
ruby -Itest -e 'Dir["test/test_*.rb"].sort.each { |file| require File.expand_path(file) }'
```

A suíte Minitest cobre validação, histórico, metas, relatórios, persistência, backups, concorrência, CSV e comandos de terminal. O GitHub Actions executa os testes em Ruby 3.2, 3.3 e 3.4.

## Critérios de aceitação

1. Registrar duas sessões deve atualizar a página acumulada sem ultrapassar o total.
2. Falhas de validação não podem sobrescrever os dados anteriores.
3. Operações concorrentes realizadas pelo aplicativo não devem perder alterações.
4. Relatórios devem usar diferenças reais entre sessões, não somar páginas acumuladas.
5. Exportações e backups não podem sobrescrever arquivos existentes.
