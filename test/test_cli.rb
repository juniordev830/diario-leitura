# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "stringio"
require "json"
require_relative "../lib/reading_diary/cli"

class ReadingDiaryCLITest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir("reading-cli-")
    @path = File.join(@directory, "books.json")
  end

  def teardown
    FileUtils.remove_entry(@directory) if File.exist?(@directory)
  end

  def call(command, *args)
    out = StringIO.new
    err = StringIO.new
    code = ReadingDiary::CLI.run([command, @path, *args], out: out, err: err)
    [code, out.string.empty? ? nil : JSON.parse(out.string), err.string]
  end

  def seed
    code, book, = call("add", "book", "Livro", "100")
    assert_equal 0, code
    assert_equal "book", book["id"]
  end

  def test_help_displays_available_commands
    out = StringIO.new
    assert_equal 0, ReadingDiary::CLI.run(["help"], out: out)
    assert_includes out.string, "export"
    assert_includes out.string, "backup"
  end

  def test_add_creates_json_and_summary
    seed
    assert File.file?(@path)
    code, summary, = call("summary")
    assert_equal 0, code
    assert_equal 0, summary[0]["current_page"]
    assert_equal 100, summary[0]["pages"]
  end

  def test_read_updates_summary
    seed
    code, session, = call("read", "book", "2026-11-08", "25", "Capitulo 1")
    assert_equal 0, code
    assert_equal 25, session["page"]
    assert_equal 25.0, call("summary")[1][0]["percent"]
  end

  def test_list_and_search
    seed
    assert_equal "book", call("list")[1][0]["id"]
    assert_equal "book", call("search", "livro")[1][0]["id"]
    assert_empty call("search", "inexistente")[1]
  end

  def test_rename_changes_title
    seed
    code, book, = call("rename", "book", "Novo")
    assert_equal 0, code
    assert_equal "Novo", book["title"]
    assert_equal "Novo", call("summary")[1][0]["title"]
  end

  def test_tag_and_goal_are_persistent
    seed
    assert_equal %w[ruby leitura], call("tag", "book", "ruby,leitura")[1]
    assert_equal 12, call("goal", "book", "12")[1]["goal"]
    assert_equal %w[ruby leitura], call("book", "book")[1]["tags"]
    assert_equal 12, call("book", "book")[1]["goal_pages_per_day"]
  end

  def test_goal_off_removes_goal
    seed
    call("goal", "book", "12")
    code, book, = call("goal", "book", "off")
    assert_equal 0, code
    refute book.key?("goal")
  end

  def test_undo_restores_previous_page
    seed
    call("read", "book", "2026-11-01", "20", "A")
    call("read", "book", "2026-11-02", "45", "B")
    code, removed, = call("undo", "book")
    assert_equal 0, code
    assert_equal 45, removed["page"]
    assert_equal 20, call("summary")[1][0]["current_page"]
  end

  def test_remove_requires_confirmation
    seed
    code, _, error = call("remove", "book", "no")
    assert_equal 2, code
    assert_match(/CONFIRM/, error)
    assert_equal 1, call("list")[1].size
    assert_equal 0, call("remove", "book", "CONFIRM")[0]
    assert_empty call("list")[1]
  end

  def test_stats_aggregates_reading
    seed
    call("read", "book", "2026-11-08", "25", "A")
    code, report, = call("stats")
    assert_equal 0, code
    assert_equal 25, report["pages_read"]
    assert_equal 1, report["reading"]
    assert_equal 1, report["active_days"]
  end

  def test_book_report_includes_status_and_remaining
    seed
    call("read", "book", "2026-11-08", "100", "Fim")
    report = call("book", "book")[1]
    assert_equal "finished", report["status"]
    assert_equal 0, report["remaining_pages"]
  end

  def test_history_contains_deltas
    seed
    call("read", "book", "2026-11-07", "10", "A")
    call("read", "book", "2026-11-08", "35", "B")
    assert_equal [10, 25], call("history", "book")[1].map { |item| item["pages_read"] }
  end

  def test_period_and_streak
    seed
    call("read", "book", "2026-11-07", "10", "A")
    call("read", "book", "2026-11-08", "35", "B")
    assert_equal 35, call("period", "2026-11-07", "2026-11-08")[1]["pages"]
    assert_equal 2, call("streak")[1]["longest"]
  end

  def test_goal_report_and_estimate
    seed
    call("goal", "book", "10")
    call("read", "book", "2026-11-08", "20", "A")
    assert_equal 20, call("goal-report", "book", "2026-11-08")[1]["actual_pages"]
    assert_equal 8, call("estimate", "book", "2026-11-08")[1]["days"]
  end

  def test_notes_search
    seed
    call("read", "book", "2026-11-08", "20", "Conceitos de Ruby")
    assert_equal 1, call("notes", "ruby")[1].length
    assert_empty call("notes", "nao")[1]
  end

  def test_monthly_summary
    seed
    call("read", "book", "2026-11-08", "20", "A")
    assert_equal({ "2026-11" => 20 }, call("monthly")[1])
  end

  def test_export_writes_csv_without_overwriting_state
    seed
    destination = File.join(@directory, "report.csv")
    code, report, = call("export", "csv", "books", destination)
    assert_equal 0, code
    assert_equal destination, report["exported"]
    assert_match(/book/, File.read(destination))
    assert_equal 1, call("list")[1].length
  end

  def test_export_rejects_overwriting_existing_destination
    seed
    destination = File.join(@directory, "report.csv")
    File.write(destination, "original")
    code, _, error = call("export", "csv", "books", destination)
    assert_equal 2, code
    assert_match(/existe/, error)
    assert_equal "original", File.read(destination)
  end

  def test_export_refuses_same_path_as_database
    seed
    code, _, error = call("export", "json", "books", @path)
    assert_equal 2, code
    assert_match(/diferente/, error)
    assert_equal 1, call("list")[1].length
  end

  def test_backup_creates_valid_copy
    seed
    destination = File.join(@directory, "backup.json")
    code, report, = call("backup", destination)
    assert_equal 0, code
    assert_equal destination, report["backup"]
    assert_equal ReadingDiary::Storage.load(@path), ReadingDiary::Storage.load(destination)
  end

  def test_backup_refuses_overwrite
    seed
    destination = File.join(@directory, "backup.json")
    call("backup", destination)
    code, _, error = call("backup", destination)
    assert_equal 2, code
    assert_match(/existe/, error)
  end

  def test_invalid_command_returns_error_without_writing
    code, _, error = call("unknown")
    assert_equal 2, code
    assert_match(/desconhecido/, error)
    refute File.exist?(@path)
  end

  def test_invalid_integer_returns_error_without_mutation
    seed
    code, _, error = call("read", "book", "2026-11-08", "abc", "A")
    assert_equal 2, code
    assert_match(/inteiro/, error)
    assert_equal 0, call("summary")[1][0]["current_page"]
  end

  def test_invalid_date_returns_error_without_mutation
    seed
    code, _, error = call("read", "book", "2026-02-30", "10", "A")
    assert_equal 2, code
    assert_match(/data invalida/, error)
    assert_equal 0, call("summary")[1][0]["sessions"]
  end

  def test_invalid_arguments_return_usage
    seed
    code, _, error = call("add", "book")
    assert_equal 2, code
    assert_match(/Uso:/, error)
  end
end
