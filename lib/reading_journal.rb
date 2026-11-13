# frozen_string_literal: true

require 'date'
require 'json'

# Pure domain model; does not require Rails or a database for the first MVP.
class ReadingJournal
  Book = Struct.new(:id, :title, :total_pages, :goal_pages, :current_page,
                    :sessions, keyword_init: true)

  def initialize
    @books = {}
  end

  def add_book(id:, title:, total_pages:, goal_pages: nil)
    unless id.is_a?(String) && id.match?(/\A[a-zA-Z0-9_-]{1,60}\z/) &&
           title.is_a?(String) && !title.strip.empty? && title.length <= 150 &&
           total_pages.is_a?(Integer) && total_pages.positive?
      raise ArgumentError, 'Dados do livro inválidos'
    end

    goal_pages ||= total_pages
    unless goal_pages.is_a?(Integer) && goal_pages.between?(1, total_pages)
      raise ArgumentError, 'Meta fora do total de páginas'
    end

    raise ArgumentError, 'ID duplicado' if @books.key?(id)

    @books[id] = Book.new(id: id, title: title.strip, total_pages: total_pages,
                          goal_pages: goal_pages, current_page: 0, sessions: [])
    @books[id]
  end

  def record(id:, date:, pages:, note: '')
    book = @books.fetch(id) { raise ArgumentError, 'Livro inexistente' }
    unless date.is_a?(String) && date.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      raise ArgumentError, 'Formato de data inválido'
    end
    begin
      Date.iso8601(date)
    rescue Date::Error
      raise ArgumentError, 'Data inválida'
    end
    unless pages.is_a?(Integer) && pages.positive? &&
           book.current_page + pages <= book.total_pages
      raise ArgumentError, 'Páginas fora do limite do livro'
    end
    unless note.is_a?(String) && note.length <= 1000
      raise ArgumentError, 'Nota inválida'
    end

    book.current_page += pages
    book.sessions << { date: date, pages: pages, note: note }
    progress(id)
  end

  def progress(id)
    book = @books.fetch(id) { raise ArgumentError, 'Livro inexistente' }
    {
      id: book.id,
      title: book.title,
      current_page: book.current_page,
      total_pages: book.total_pages,
      goal_pages: book.goal_pages,
      percent: (book.current_page * 100.0 / book.total_pages).round(1),
      goal_reached: book.current_page >= book.goal_pages,
      sessions: book.sessions.length,
      notes: book.sessions.filter_map do |s|
        s[:note].empty? ? nil : { date: s[:date], note: s[:note] }
      end
    }
  end

  def ids
    @books.keys.sort
  end

  def to_json(*args)
    JSON.generate({ version: 1, books: ids.map do |id|
      b = @books.fetch(id)
      {
        id: b.id, title: b.title, total_pages: b.total_pages,
        goal_pages: b.goal_pages, sessions: b.sessions
      }
    end }, *args)
  end

  def self.from_json(json)
    data = JSON.parse(json)
    raise ArgumentError, 'Backup inválido' unless data.is_a?(Hash) &&
      data['version'] == 1 && data['books'].is_a?(Array)
    raise ArgumentError, 'Backup muito grande' if data['books'].length > 10_000
    journal = new
    data['books'].each do |b|
      unless b.is_a?(Hash) && b['sessions'].is_a?(Array) &&
             b['sessions'].length <= 100_000
        raise ArgumentError, 'Livro ou sessões inválidos'
      end
      journal.add_book(id: b.fetch('id'), title: b.fetch('title'),
                       total_pages: b.fetch('total_pages'),
                       goal_pages: b.fetch('goal_pages'))
      b['sessions'].each do |s|
        journal.record(id: b.fetch('id'), date: s.fetch('date'),
                       pages: s.fetch('pages'), note: s.fetch('note'))
      end
    end
    journal
  rescue KeyError, JSON::ParserError => e
    raise ArgumentError, "Backup inválido: #{e.message}"
  end
end
