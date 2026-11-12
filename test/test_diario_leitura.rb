# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/diario_leitura"

class DiarioLeituraTest < Minitest::Test
  def novo_livro
    DiarioLeitura::Livro.new(titulo: "  Livro fictício  ", total_paginas: 100)
  end

  def test_duas_sessoes_calculam_progresso_sem_ultrapassar_total
    livro = novo_livro
    livro.registrar_sessao(paginas: 20, data: "2026-11-01")
    livro.registrar_sessao(paginas: 30, data: "2026-11-02", nota: "Anotações")
    assert_equal "Livro fictício", livro.titulo
    assert_equal 50, livro.paginas_lidas
    assert_equal 50, livro.paginas_restantes
    assert_equal 50.0, livro.progresso_percentual
    refute livro.concluido?
    assert_equal 2, livro.sessoes.size
  end

  def test_sessao_que_ultrapassa_paginas_nao_modifica_estado
    livro = novo_livro
    livro.registrar_sessao(paginas: 50, data: "2026-11-01")
    assert_raises(ArgumentError) { livro.registrar_sessao(paginas: 60, data: "2026-11-02") }
    assert_equal 50, livro.paginas_lidas
    assert_equal 1, livro.sessoes.length
  end

  def test_conclusao_e_progresso_exato
    livro = novo_livro
    livro.registrar_sessao(paginas: 100, data: "2026-11-01")
    assert livro.concluido?
    assert_equal 100.0, livro.progresso_percentual
    assert_raises(ArgumentError) { livro.registrar_sessao(paginas: 1, data: "2026-11-02") }
  end

  def test_entradas_invalidas_e_data_inexistente
    assert_raises(ArgumentError) { DiarioLeitura::Livro.new(titulo: "", total_paginas: 10) }
    assert_raises(ArgumentError) { DiarioLeitura::Livro.new(titulo: "Teste", total_paginas: 0) }
    livro = novo_livro
    [0, -1, 1.5].each do |paginas|
      assert_raises(ArgumentError) { livro.registrar_sessao(paginas: paginas, data: "2026-11-01") }
    end
    assert_raises(ArgumentError) { livro.registrar_sessao(paginas: 5, data: "2026-02-30") }
    assert_raises(ArgumentError) { livro.registrar_sessao(paginas: 5, data: "01/11/2026") }
    assert_equal 0, livro.paginas_lidas
  end

  def test_sessoes_sao_inalteraveis_por_quem_consulta
    livro = novo_livro
    sessao = livro.registrar_sessao(paginas: 7, data: Date.new(2026, 11, 3), nota: "ok")
    assert_raises(FrozenError) { sessao.paginas = 90 }
    assert_raises(FrozenError) { livro.sessoes << sessao }
    assert_equal 7, livro.paginas_lidas
  end

  def test_sessoes_exibidas_em_ordem_cronologica_com_empate_estavel
    livro = novo_livro
    livro.registrar_sessao(paginas: 10, data: "2026-11-10", nota: "Terceira")
    livro.registrar_sessao(paginas: 5, data: "2026-11-08", nota: "Primeira")
    livro.registrar_sessao(paginas: 7, data: "2026-11-10", nota: "Quarta")
    livro.registrar_sessao(paginas: 3, data: "2026-11-09", nota: "Segunda")
    assert_equal ["Primeira", "Segunda", "Terceira", "Quarta"], livro.sessoes.map(&:nota)
    assert_equal 25, livro.paginas_lidas
    assert_equal 75, livro.paginas_restantes
    assert_raises(FrozenError) { livro.sessoes.clear }
  end

end
