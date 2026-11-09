# frozen_string_literal: true

require "csv"
require "json"
require_relative "analytics"
require_relative "storage"

module ReadingDiary
  module Export
    module_function

    def safe_cell(value)
      return value if value.is_a?(Numeric)
      text = value.nil? ? "" : value.to_s
      text = text.gsub("\0", "")
      text.match?(/\A[\s]*[=+@\-]/) ? "'#{text}" : text
    end

    def csv(rows, columns:)
      CSV.generate(row_sep: "\n", force_quotes: true) do |out|
        out << columns
        rows.each do |row|
          out << columns.map { |column| safe_cell(row[column]) }
        end
      end
    end

    def books_csv(state)
      rows = ReadingDiary.books(state).map do |book|
        report = ReadingDiary.book_report(state, id: book["id"])
        {
          "id" => report["id"], "title" => report["title"], "status" => report["status"],
          "pages" => report["total_pages"], "current_page" => report["read_pages"],
          "percent" => report["completion_percent"], "sessions" => report["sessions"],
          "goal" => report["goal_pages_per_day"], "tags" => report["tags"].join("|")
        }
      end
      csv(rows, columns: %w[id title status pages current_page percent sessions goal tags])
    end

    def sessions_csv(state, id: nil)
      csv(ReadingDiary.history(state, id: id),
          columns: %w[book_id date page pages_read note])
    end

    def daily_csv(state, from: nil, to: nil)
      rows = ReadingDiary.daily_pages(state, from: from, to: to).map do |date, pages|
        { "date" => date, "pages" => pages }
      end
      csv(rows, columns: %w[date pages])
    end

    def export(state, format:, scope:, id: nil, from: nil, to: nil)
      ReadingDiary.validate!(state)
      raise ReadingDiary::Error, "formato invalido" unless %w[csv json].include?(format)
      raise ReadingDiary::Error, "escopo invalido" unless %w[books sessions daily].include?(scope)
      data = case scope
             when "books"
               raise ReadingDiary::Error, "filtros nao suportados para livros" if id || from || to
               format == "csv" ? books_csv(state) : ReadingDiary.books(state).map { |book| ReadingDiary.book_report(state, id: book["id"]) }
             when "sessions"
               raise ReadingDiary::Error, "filtro de datas nao suportado para sessoes CSV" if format == "csv" && (from || to)
               format == "csv" ? sessions_csv(state, id: id) : ReadingDiary.history(state, id: id, from: from, to: to)
             when "daily"
               raise ReadingDiary::Error, "filtro de livro nao suportado para dias" if id
               format == "csv" ? daily_csv(state, from: from, to: to) : ReadingDiary.daily_pages(state, from: from, to: to)
             end
      format == "json" ? JSON.pretty_generate(data) + "\n" : data
    end

    def write_new_file(path, payload)
      ReadingDiary::Storage.check_path!(path)
      raise ReadingDiary::Error, "destino ja existe" if File.exist?(path)
      parent = File.dirname(File.expand_path(path))
      raise ReadingDiary::Error, "diretorio de destino inexistente" unless File.directory?(parent)
      raise ReadingDiary::Error, "exportacao muito grande" if payload.bytesize > ReadingDiary::Storage::MAX_BYTES
      created = false
      begin
        File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
          created = true
          file.write(payload)
          file.flush
          file.fsync
        end
      rescue StandardError
        File.delete(path) if created && File.file?(path)
        raise
      end
      path
    rescue Errno::EEXIST
      raise ReadingDiary::Error, "destino ja existe"
    rescue Errno::EACCES, Errno::ENOSPC, Errno::EROFS => error
      raise ReadingDiary::Error, "falha ao exportar: #{error.class}"
    end
  end
end
