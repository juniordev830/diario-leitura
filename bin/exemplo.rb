# frozen_string_literal: true

require_relative "../lib/diario_leitura"

livro = DiarioLeitura::Livro.new(titulo: "Livro de demonstração", total_paginas: 100)
livro.registrar_sessao(paginas: 20, data: "2026-11-01")
livro.registrar_sessao(paginas: 30, data: "2026-11-02")

puts "Título: #{livro.titulo}"
puts "Lidas: #{livro.paginas_lidas}/#{livro.total_paginas}"
puts "Progresso: #{livro.progresso_percentual}%"
puts "Restantes: #{livro.paginas_restantes}"
