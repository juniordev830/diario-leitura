# frozen_string_literal: true

require "date"

module DiarioLeitura
  Sessao = Struct.new(:data, :paginas, :nota, keyword_init: true)

  # Núcleo independente de interface e banco: cada sessão incrementa o progresso.
  class Livro
    attr_reader :titulo, :total_paginas

    def initialize(titulo:, total_paginas:)
      unless titulo.is_a?(String) && !titulo.strip.empty? && titulo.strip.length <= 200
        raise ArgumentError, "Título deve ter entre 1 e 200 caracteres."
      end
      unless total_paginas.is_a?(Integer) && total_paginas.between?(1, 100_000)
        raise ArgumentError, "Total de páginas deve estar entre 1 e 100000."
      end

      @titulo = titulo.strip.freeze
      @total_paginas = total_paginas
      @sessoes = []
    end

    def registrar_sessao(paginas:, data:, nota: nil)
      unless paginas.is_a?(Integer) && paginas.positive?
        raise ArgumentError, "Páginas da sessão devem ser um inteiro positivo."
      end
      if paginas > paginas_restantes
        raise ArgumentError, "A sessão ultrapassa o total de páginas do livro."
      end
      unless nota.nil? || (nota.is_a?(String) && nota.length <= 500)
        raise ArgumentError, "Nota deve ter no máximo 500 caracteres."
      end

      data_valida = normalizar_data(data)
      sessao = Sessao.new(data: data_valida, paginas: paginas, nota: nota&.dup&.freeze).freeze
      @sessoes << sessao
      sessao
    end

    def paginas_lidas
      @sessoes.sum(&:paginas)
    end

    def paginas_restantes
      total_paginas - paginas_lidas
    end

    def progresso_percentual
      (100.0 * paginas_lidas / total_paginas).round(2)
    end

    def concluido?
      paginas_restantes.zero?
    end

    def sessoes
      @sessoes.dup.freeze
    end

    private

    def normalizar_data(value)
      case value
      when Date
        value
      when String
        # ISO8601 estrito: não aceitar datas parcialmente interpretadas.
        unless value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
          raise ArgumentError, "Data deve estar em AAAA-MM-DD."
        end
        Date.iso8601(value)
      else
        raise ArgumentError, "Data deve ser Date ou texto AAAA-MM-DD."
      end
    rescue Date::Error
      raise ArgumentError, "Data de sessão inválida."
    end
  end
end
