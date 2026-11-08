# Diario de Leitura

Primeiro MVP executavel em **Ruby 3.3**, para cadastrar livros, registrar sessoes de leitura e acompanhar progresso em arquivo JSON local.

## Funcionalidades

- Cadastra ID unico, titulo e numero total de paginas.
- Registra leitura por data, pagina atual e nota de ate 2.000 caracteres.
- Impede avancar alem do livro, voltar paginas ou registrar sessao com data anterior a ultima.
- Gera resumo de paginas lidas, percentual do livro e numero de sessoes.
- Salva localmente em JSON com arquivo temporario e renomeacao; nenhum dado e enviado para servidores.

## Como executar

```bash
ruby bin/diario.rb add leitura.json livro-1 "Livro demonstrativo" 120
ruby bin/diario.rb read leitura.json livro-1 2026-11-08 30 "Primeiro capitulo"
ruby bin/diario.rb read leitura.json livro-1 2026-11-09 50 "Segundo capitulo"
ruby bin/diario.rb summary leitura.json
ruby -Itest test/test_diary.rb
```

## Estado e limites

Somente terminal e arquivo local nesta primeira entrega. Sem banco SQLite, interface Rails ou sincronizacao. O aplicativo nao oferece travas de arquivo para escritas concorrentes por varios processos; use uma instancia por vez e mantenha backups dos seus registros.

## Critério de aceite

Duas sessoes validas somam progresso ate a ultima pagina registrada e nao ultrapassam a quantidade total. Testes validam ainda data invalida, duplicidade, retrocesso de paginas e falha sem alteracao do registro.
