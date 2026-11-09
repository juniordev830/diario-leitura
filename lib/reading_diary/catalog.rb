# frozen_string_literal: true

require "date"
require_relative "../reading_diary"

module ReadingDiary
  MAX_BOOKS = 10_000
  MAX_SESSIONS = 100_000

  def self.validate!(state)
    raise Error, "documento invalido" unless state.is_a?(Hash)
    entries = state["books"]
    raise Error, "lista de livros invalida" unless entries.is_a?(Array) && entries.length <= MAX_BOOKS
    seen = {}
    entries.each do |book|
      raise Error, "registro de livro invalido" unless book.is_a?(Hash)
      id = book["id"]
      title = book["title"]
      pages = book["pages"]
      current = book["current_page"]
      raise Error, "identificador invalido" unless id.is_a?(String) && id.match?(/\A[a-z0-9-]{1,50}\z/)
      raise Error, "livro duplicado" if seen[id]
      seen[id] = true
      raise Error, "titulo invalido" unless title.is_a?(String) && !title.strip.empty? && title.length <= 200
      raise Error, "paginas invalidas" unless pages.is_a?(Integer) && pages.between?(1, 100_000)
      raise Error, "pagina atual invalida" unless current.is_a?(Integer) && current.between?(0, pages)
      tags = book.fetch("tags", [])
      raise Error, "etiquetas invalidas" unless tags.is_a?(Array) && tags.length <= 20 &&
        tags.all? { |tag| tag.is_a?(String) && tag.match?(/\A[a-z0-9-]{1,30}\z/) } && tags.uniq == tags
      goal = book["goal"]
      raise Error, "meta invalida" unless goal.nil? || (goal.is_a?(Integer) && goal.between?(1, 1000))
      sessions = book["sessions"]
      raise Error, "historico invalido" unless sessions.is_a?(Array) && sessions.length <= MAX_SESSIONS
      previous_date = nil
      previous_page = 0
      sessions.each do |session|
        raise Error, "sessao invalida" unless session.is_a?(Hash)
        date = session["date"]
        page = session["page"]
        note = session["note"]
        raise Error, "data invalida" unless date.is_a?(String) && date.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        begin
          raise Error, "data invalida" unless Date.iso8601(date).iso8601 == date
        rescue Date::Error
          raise Error, "data invalida"
        end
        raise Error, "historico fora de ordem" if previous_date && date < previous_date
        raise Error, "progresso inconsistente" unless page.is_a?(Integer) && page.between?(previous_page, pages)
        raise Error, "nota invalida" unless note.is_a?(String) && note.length <= 2_000
        previous_date = date
        previous_page = page
      end
      raise Error, "pagina atual nao confere com historico" unless current == previous_page
    end
    state
  end

  def self.find_book(state, id)
    books(state).find { |book| book["id"] == id } ||
      (raise Error, "livro nao encontrado: #{id}")
  end

  def self.rename_book(state, id:, title:)
    raise Error, "titulo invalido" unless title.is_a?(String) && !title.strip.empty? && title.length <= 200
    book = find_book(state, id)
    book["title"] = title.strip
    book
  end

  def self.set_tags(state, id:, tags:)
    raise Error, "etiquetas invalidas" unless tags.is_a?(Array)
    normalized = tags.map do |tag|
      raise Error, "etiqueta invalida" unless tag.is_a?(String)
      tag.strip.downcase
    end
    raise Error, "etiquetas invalidas" unless normalized.length <= 20 &&
      normalized.all? { |tag| tag.match?(/\A[a-z0-9-]{1,30}\z/) }
    find_book(state, id)["tags"] = normalized.uniq
  end

  def self.set_goal(state, id:, pages_per_day:)
    raise Error, "meta invalida" unless pages_per_day.nil? ||
      (pages_per_day.is_a?(Integer) && pages_per_day.between?(1, 1000))
    book = find_book(state, id)
    if pages_per_day.nil?
      book.delete("goal")
    else
      book["goal"] = pages_per_day
    end
    book
  end

  def self.undo_last_session(state, id:)
    book = find_book(state, id)
    raise Error, "nenhuma sessao para desfazer" if book["sessions"].empty?
    removed = book["sessions"].pop
    book["current_page"] = book["sessions"].last&.fetch("page") || 0
    removed
  end

  def self.remove_book(state, id:)
    book = find_book(state, id)
    books(state).delete(book)
    book
  end

  def self.search_books(state, query: nil, tag: nil, status: nil)
    raise Error, "filtro invalido" unless [nil, "unread", "reading", "finished"].include?(status)
    raise Error, "busca invalida" unless query.nil? || (query.is_a?(String) && query.length <= 200)
    raise Error, "etiqueta invalida" unless tag.nil? || (tag.is_a?(String) && tag.match?(/\A[a-z0-9-]{1,30}\z/))
    books(state).select do |book|
      matches_text = query.nil? || book["title"].downcase.include?(query.downcase) || book["id"].include?(query.downcase)
      matches_tag = tag.nil? || book.fetch("tags", []).include?(tag)
      matches_status = case status
                       when "unread" then book["current_page"].zero?
                       when "reading" then book["current_page"].positive? && book["current_page"] < book["pages"]
                       when "finished" then book["current_page"] == book["pages"]
                       else true
                       end
      matches_text && matches_tag && matches_status
    end
  end

  def self.search_notes(state, query:, id: nil)
    raise Error, "busca invalida" unless query.is_a?(String) && !query.strip.empty? && query.length <= 200
    source = id ? [find_book(state, id)] : books(state)
    source.flat_map do |book|
      book["sessions"].each_with_index.filter_map do |session, index|
        next unless session["note"].downcase.include?(query.downcase)
        { "book_id" => book["id"], "session_index" => index, "date" => session["date"],
          "page" => session["page"], "note" => session["note"] }
      end
    end
  end
end
