# Diário de Leitura

> Estado atualizado nesta branch: núcleo de domínio Ruby executável, com testes automatizados. A aplicação Rails, interface e persistência SQLite continuam planejadas.

## Ideia

Registrar leituras e notas para acompanhar aprendizado ao longo do tempo.

## Primeira versão planejada

- [ ] Cadastrar um livro e meta de leitura.
- [ ] Registrar sessões e páginas lidas.
- [ ] Consultar progresso e notas.

## Modelo inicial

Livro, sessão de leitura e anotação.

## Regras e limites

Página atual deve ficar entre zero e o total do livro.

Escopo mantido pequeno: sem pagamentos, integrações externas, infraestrutura de produção ou uso de dados pessoais reais nesta etapa.

## Tecnologia proposta

Ruby + Rails + SQLite.

A escolha é uma proposta para a futura implementação; nenhuma dependência foi instalada e a tecnologia ainda não foi implementada.

## Critério de conclusão do primeiro incremento

Duas sessões válidas devem atualizar o progresso sem ultrapassar o total de páginas.

## Próximos passos

1. Revisar este escopo antes de começar a implementação.
2. Preparar o ambiente mínimo da tecnologia escolhida.
3. Implementar um fluxo completo e validar o critério acima.
4. Documentar a execução e acrescentar exemplos demonstrativos.

## Possíveis evoluções

Depois de validar o fluxo principal, avaliar persistência, acessibilidade e uma interface mais completa conforme a plataforma. Evoluções não fazem parte da entrega atual.

## Como executar

Ainda não há comandos de execução. Eles serão adicionados quando existir uma primeira versão funcional.

## Documentação de desenvolvimento

O [guia de validação e evolução](docs/PRIMEIRO_INCREMENTO.md) registra o estado atual, os testes e os próximos incrementos deste projeto.

## Núcleo Ruby implementado nesta branch

O arquivo `lib/diario_leitura.rb` modela livros, sessões de leitura, páginas restantes e progresso percentual. Impede que o avanço ultrapasse o total de páginas e valida datas ISO. O exemplo usa somente dados fictícios.

Requer Ruby 3.3 (bibliotecas padrão):

```bash
ruby bin/exemplo.rb
ruby -Ilib test/test_diario_leitura.rb
```

Os testes cobrem conclusão de livro, duas sessões, limite de páginas, data inválida e integridade da lista de sessões. A CI da branch está em `.github/workflows/ruby-test.yml`.

**Limitações:** os registros só vivem em memória durante o processo. Ainda não há Rails, SQLite, interface, cadastro de usuários ou recuperação de dados. A arquitetura prevista no planejamento permanece como próximo passo.
