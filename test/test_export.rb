# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "csv"
require "json"
require_relative "../lib/reading_diary/export"

class ReadingDiaryExportTest < Minitest::Test
  def setup
    @state = ReadingDiary.empty
    ReadingDiary.add_book(@state, id: "book", title: "=SUM(A1:A9)", pages: 100)
    ReadingDiary.add_session(@state, id: "book", date: "2026-11-01", page: 20, note: "+CMD()")
    ReadingDiary.add_session(@state, id: "book", date: "2026-11-02", page: 50, note: "normal")
    @directory = Dir.mktmpdir("reading-export-")
  end

  def teardown
    FileUtils.remove_entry(@directory) if File.exist?(@directory)
  end

  def test_books_csv_has_expected_columns
    rows = CSV.parse(ReadingDiary::Export.books_csv(@state), headers: true)
    assert_equal 1, rows.length
    assert_equal "book", rows[0]["id"]
    assert_equal "50", rows[0]["current_page"]
    assert_equal "reading", rows[0]["status"]
  end

  def test_books_csv_neutralizes_formula_in_title
    rows = CSV.parse(ReadingDiary::Export.books_csv(@state), headers: true)
    assert_equal "'=SUM(A1:A9)", rows[0]["title"]
  end

  def test_sessions_csv_neutralizes_formula_in_note
    rows = CSV.parse(ReadingDiary::Export.sessions_csv(@state), headers: true)
    assert_equal "'+CMD()", rows[0]["note"]
    assert_equal "20", rows[0]["pages_read"]
    assert_equal "30", rows[1]["pages_read"]
  end

  def test_safe_cell_neutralizes_spreadsheet_prefixes
    ["=1+1", "+cmd", "-cmd", "@cmd", "  =A1"].each do |value|
      assert_equal "'#{value}", ReadingDiary::Export.safe_cell(value)
    end
  end

  def test_safe_cell_preserves_safe_text_and_numbers
    assert_equal "normal", ReadingDiary::Export.safe_cell("normal")
    assert_equal 15, ReadingDiary::Export.safe_cell(15)
    assert_equal "", ReadingDiary::Export.safe_cell(nil)
  end

  def test_csv_escapes_quotes_commas_and_newlines
    text = ReadingDiary::Export.csv([{ "text" => "um, \"dois\"\ntres" }], columns: ["text"])
    assert_equal "um, \"dois\"\ntres", CSV.parse(text, headers: true)[0]["text"]
  end

  def test_daily_csv_contains_aggregated_deltas
    rows = CSV.parse(ReadingDiary::Export.daily_csv(@state), headers: true)
    assert_equal %w[2026-11-01 2026-11-02], rows.map { |row| row["date"] }
    assert_equal %w[20 30], rows.map { |row| row["pages"] }
  end

  def test_daily_csv_filters_date_range
    rows = CSV.parse(ReadingDiary::Export.daily_csv(@state, from: "2026-11-02"), headers: true)
    assert_equal 1, rows.length
    assert_equal "30", rows[0]["pages"]
  end

  def test_json_books_export_contains_metrics
    json = ReadingDiary::Export.export(@state, format: "json", scope: "books")
    report = JSON.parse(json)
    assert_equal 50.0, report[0]["completion_percent"]
    assert_equal "book", report[0]["id"]
  end

  def test_json_sessions_export_filters_dates
    json = ReadingDiary::Export.export(@state, format: "json", scope: "sessions",
                                       from: "2026-11-02", to: "2026-11-02")
    report = JSON.parse(json)
    assert_equal 1, report.length
    assert_equal 30, report[0]["pages_read"]
  end

  def test_json_daily_export
    json = ReadingDiary::Export.export(@state, format: "json", scope: "daily")
    assert_equal({ "2026-11-01" => 20, "2026-11-02" => 30 }, JSON.parse(json))
  end

  def test_export_rejects_invalid_scope_and_format
    assert_raises(ReadingDiary::Error) { ReadingDiary::Export.export(@state, format: "xml", scope: "books") }
    assert_raises(ReadingDiary::Error) { ReadingDiary::Export.export(@state, format: "csv", scope: "unknown") }
  end

  def test_export_rejects_unsupported_filters
    assert_raises(ReadingDiary::Error) do
      ReadingDiary::Export.export(@state, format: "csv", scope: "sessions", from: "2026-11-01")
    end
    assert_raises(ReadingDiary::Error) do
      ReadingDiary::Export.export(@state, format: "csv", scope: "daily", id: "book")
    end
  end

  def test_write_new_file_creates_private_export
    path = File.join(@directory, "books.csv")
    assert_equal path, ReadingDiary::Export.write_new_file(path, ReadingDiary::Export.books_csv(@state))
    assert_equal 0o600, File.stat(path).mode & 0o777
    assert_match(/book/, File.read(path))
  end

  def test_write_new_file_refuses_overwrite
    path = File.join(@directory, "books.csv")
    File.write(path, "keep")
    assert_raises(ReadingDiary::Error) { ReadingDiary::Export.write_new_file(path, "new") }
    assert_equal "keep", File.read(path)
  end

  def test_write_new_file_refuses_missing_directory
    path = File.join(@directory, "missing", "books.csv")
    assert_raises(ReadingDiary::Error) { ReadingDiary::Export.write_new_file(path, "new") }
  end

  def test_write_new_file_refuses_symlink
    target = File.join(@directory, "target.csv")
    File.write(target, "keep")
    link = File.join(@directory, "link.csv")
    File.symlink(target, link)
    assert_raises(ReadingDiary::Error) { ReadingDiary::Export.write_new_file(link, "new") }
    assert_equal "keep", File.read(target)
  end
end
