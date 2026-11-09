# frozen_string_literal: true

require "json"
require_relative "../lib/reading_diary/export"

module ReadingDiary
  module CLI
    module_function

    HELP = <<~TEXT
      Uso: ruby bin/diario.rb COMANDO arquivo.json [argumentos]
        add arquivo ID TITULO TOTAL_PAGINAS
        read arquivo ID AAAA-MM-DD PAGINA_ATUAL NOTA
        summary arquivo
        list arquivo
        search arquivo TEXTO
        rename arquivo ID NOVO_TITULO
        tag arquivo ID etiqueta1,etiqueta2
        goal arquivo ID PAGINAS_POR_DIA|off
        undo arquivo ID
        remove arquivo ID CONFIRM
        stats arquivo
        book arquivo ID
        history arquivo [ID]
        period arquivo DATA_INICIAL DATA_FINAL
        streak arquivo
        goal-report arquivo ID DATA
        estimate arquivo ID DATA
        notes arquivo TEXTO [ID]
        monthly arquivo
        export arquivo csv|json books|sessions|daily destino [ID]
        backup arquivo destino.json
    TEXT

    def run(argv, out: $stdout, err: $stderr)
      command, path, *args = argv
      if %w[help --help -h].include?(command)
        out.puts HELP
        return 0
      end
      raise ReadingDiary::Error, HELP unless command && path
      result = dispatch(command, path, args)
      out.puts JSON.pretty_generate(result) unless result == :silent
      0
    rescue ReadingDiary::Error, ArgumentError, JSON::ParserError, SystemCallError => error
      err.puts "Erro: #{error.message}"
      2
    end

    def dispatch(command, path, args)
      case command
      when "add"
        expect!(args, 3, "add ID TITULO TOTAL_PAGINAS")
        mutate(path) { |state| ReadingDiary.add_book(state, id: args[0], title: args[1], pages: number!(args[2])) }
      when "read"
        expect!(args, 4, "read ID DATA PAGINA NOTA")
        mutate(path) do |state|
          ReadingDiary.add_session(state, id: args[0], date: args[1], page: number!(args[2]), note: args[3])
        end
      when "rename"
        expect!(args, 2, "rename ID NOVO_TITULO")
        mutate(path) { |state| ReadingDiary.rename_book(state, id: args[0], title: args[1]) }
      when "tag"
        expect!(args, 2, "tag ID etiqueta1,etiqueta2")
        mutate(path) { |state| ReadingDiary.set_tags(state, id: args[0], tags: args[1].empty? ? [] : args[1].split(",")) }
      when "goal"
        expect!(args, 2, "goal ID PAGINAS|off")
        target = args[1] == "off" ? nil : number!(args[1])
        mutate(path) { |state| ReadingDiary.set_goal(state, id: args[0], pages_per_day: target) }
      when "undo"
        expect!(args, 1, "undo ID")
        mutate(path) { |state| ReadingDiary.undo_last_session(state, id: args[0]) }
      when "remove"
        expect!(args, 2, "remove ID CONFIRM")
        raise ReadingDiary::Error, "remocao exige CONFIRM" unless args[1] == "CONFIRM"
        mutate(path) { |state| ReadingDiary.remove_book(state, id: args[0]) }
      when "summary"
        expect!(args, 0, "summary")
        ReadingDiary.summary(ReadingDiary::Storage.load(path))
      when "list"
        expect!(args, 0, "list")
        ReadingDiary.search_books(ReadingDiary::Storage.load(path)).map { |book| { "id" => book["id"], "title" => book["title"] } }
      when "search"
        expect!(args, 1, "search TEXTO")
        ReadingDiary.search_books(ReadingDiary::Storage.load(path), query: args[0]).map do |book|
          { "id" => book["id"], "title" => book["title"], "tags" => book.fetch("tags", []) }
        end
      when "stats"
        expect!(args, 0, "stats")
        ReadingDiary.overview(ReadingDiary::Storage.load(path))
      when "book"
        expect!(args, 1, "book ID")
        ReadingDiary.book_report(ReadingDiary::Storage.load(path), id: args[0])
      when "history"
        expect_between!(args, 0, 1, "history [ID]")
        ReadingDiary.history(ReadingDiary::Storage.load(path), id: args[0])
      when "period"
        expect!(args, 2, "period DATA_INICIAL DATA_FINAL")
        ReadingDiary.period_report(ReadingDiary::Storage.load(path), from: args[0], to: args[1])
      when "streak"
        expect!(args, 0, "streak")
        ReadingDiary.reading_streak(ReadingDiary.daily_pages(ReadingDiary::Storage.load(path)))
      when "goal-report"
        expect!(args, 2, "goal-report ID DATA")
        ReadingDiary.goal_report(ReadingDiary::Storage.load(path), id: args[0], on: args[1])
      when "estimate"
        expect!(args, 2, "estimate ID DATA")
        ReadingDiary.estimate_finish(ReadingDiary::Storage.load(path), id: args[0], on: args[1])
      when "notes"
        expect_between!(args, 1, 2, "notes TEXTO [ID]")
        ReadingDiary.search_notes(ReadingDiary::Storage.load(path), query: args[0], id: args[1])
      when "monthly"
        expect!(args, 0, "monthly")
        ReadingDiary.monthly_pages(ReadingDiary::Storage.load(path))
      when "export"
        expect_between!(args, 3, 4, "export FORMATO ESCOPO DESTINO [ID]")
        state = ReadingDiary::Storage.load(path)
        raise ReadingDiary::Error, "destino deve ser diferente da origem" if File.expand_path(path) == File.expand_path(args[2])
        payload = ReadingDiary::Export.export(state, format: args[0], scope: args[1], id: args[3])
        ReadingDiary::Export.write_new_file(args[2], payload)
        { "exported" => args[2], "bytes" => payload.bytesize }
      when "backup"
        expect!(args, 1, "backup DESTINO")
        raise ReadingDiary::Error, "destino deve ser diferente da origem" if File.expand_path(path) == File.expand_path(args[0])
        { "backup" => ReadingDiary::Storage.backup(path, args[0]) }
      else
        raise ReadingDiary::Error, "comando desconhecido: #{command}\n#{HELP}"
      end
    end

    def mutate(path)
      ReadingDiary::Storage.transaction(path) { |state| yield(state) }
    end

    def number!(value)
      Integer(value, 10)
    rescue ArgumentError, TypeError
      raise ReadingDiary::Error, "numero inteiro invalido"
    end

    def expect!(args, count, usage)
      raise ReadingDiary::Error, "Uso: #{usage}" unless args.length == count
    end

    def expect_between!(args, min, max, usage)
      raise ReadingDiary::Error, "Uso: #{usage}" unless args.length.between?(min, max)
    end
  end
end
