#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "fileutils"
require_relative "../lib/reading_diary"

def load_state(path)
  return ReadingDiary.empty unless File.file?(path)
  state = JSON.parse(File.read(path))
  raise ReadingDiary::Error, "formato JSON invalido" unless state.is_a?(Hash)
  ReadingDiary.books(state)
  state
end

def save_state(path, state)
  parent = File.dirname(File.expand_path(path))
  raise ReadingDiary::Error, "diretorio de destino inexistente" unless Dir.exist?(parent)
  temp = "#{path}.tmp-#{Process.pid}"
  begin
    File.open(temp, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
      file.write(JSON.pretty_generate(state) + "\n")
      file.flush
      file.fsync
    end
    File.rename(temp, path)
  ensure
    File.delete(temp) if File.exist?(temp)
  end
end

begin
  command, path, *args = ARGV
  raise ReadingDiary::Error, "Uso: ruby bin/diario.rb add|read|summary dados.json ..." unless %w[add read summary].include?(command) && path
  state = load_state(path)
  case command
  when "add"
    raise ReadingDiary::Error, "Uso: add dados.json ID TITULO TOTAL_PAGINAS" unless args.length == 3
    ReadingDiary.add_book(state, id: args[0], title: args[1], pages: Integer(args[2], 10))
    save_state(path, state)
  when "read"
    raise ReadingDiary::Error, "Uso: read dados.json ID AAAA-MM-DD PAGINA_ATUAL NOTA" unless args.length == 4
    ReadingDiary.add_session(state, id: args[0], date: args[1], page: Integer(args[2], 10), note: args[3])
    save_state(path, state)
  when "summary"
    raise ReadingDiary::Error, "Uso: summary dados.json" unless args.empty?
    puts JSON.pretty_generate(ReadingDiary.summary(state))
  end
rescue ReadingDiary::Error, ArgumentError, JSON::ParserError, Errno::ENOENT, Errno::EACCES => error
  warn "Erro: #{error.message}"
  exit 2
end
