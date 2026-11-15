# frozen_string_literal: true

require "date"

module ReadingDiary
  class Error < StandardError; end

  def self.empty
    { "books" => [] }
  end

  def self.books(state)
    items = state.fetch("books")
    raise Error, "lista de livros invalida" unless items.is_a?(Array)
    items
  end

  def self.add_book(state, id:, title:, pages:)
    raise Error, "identificador invalido" unless id.is_a?(String) && id.match?(/\A[a-z0-9-]{1,50}\z/)
    raise Error, "titulo invalido" unless title.is_a?(String) && !title.strip.empty? && title.size <= 200
    raise Error, "paginas invalidas" unless pages.is_a?(Integer) && pages.positive? && pages <= 100_000
    raise Error, "livro duplicado" if books(state).any? { |book| book["id"] == id }
    book = { "id" => id, "title" => title.strip, "pages" => pages, "current_page" => 0, "sessions" => [] }
    books(state) << book
    book
  end

  def self.add_session(state, id:, date:, page:, note:)
    book = books(state).find { |entry| entry["id"] == id }
    raise Error, "livro nao encontrado" unless book
    raise Error, "pagina invalida" unless page.is_a?(Integer) && page.between?(book["current_page"], book["pages"])
    raise Error, "nota invalida" unless note.is_a?(String) && note.length <= 2_000
    begin
      valid_date = Date.iso8601(date)
    rescue Date::Error, TypeError
      raise Error, "data invalida (AAAA-MM-DD)"
    end
    raise Error, "data invalida (AAAA-MM-DD)" unless valid_date.iso8601 == date
    sessions = book.fetch("sessions")
    raise Error, "historico invalido" unless sessions.is_a?(Array)
    if sessions.any? && date < sessions.last.fetch("date")
      raise Error, "sessao anterior ao ultimo registro"
    end
    session = { "date" => date, "page" => page, "note" => note }
    sessions << session
    book["current_page"] = page
    session
  end

  def self.summary(state)
    books(state).map do |book|
      {
        "id" => book.fetch("id"),
        "title" => book.fetch("title"),
        "current_page" => book.fetch("current_page"),
        "pages" => book.fetch("pages"),
        "percent" => (100.0 * book.fetch("current_page") / book.fetch("pages")).round(1),
        "sessions" => book.fetch("sessions").length
      }
    end
  end
end
