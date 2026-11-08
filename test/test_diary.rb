# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/reading_diary"

class ReadingDiaryTest < Minitest::Test
  def setup
    @data = ReadingDiary.empty
    ReadingDiary.add_book(@data, id: "book-1", title: "Exemplo", pages: 120)
  end

  def test_two_sessions_update_progress_and_history
    ReadingDiary.add_session(@data, id: "book-1", date: "2026-11-07", page: 20, note: "Primeiro dia")
    ReadingDiary.add_session(@data, id: "book-1", date: "2026-11-08", page: 60, note: "Segundo dia")
    report = ReadingDiary.summary(@data).first
    assert_equal 60, report["current_page"]
    assert_equal 50.0, report["percent"]
    assert_equal 2, report["sessions"]
  end

  def test_cannot_read_beyond_book_or_go_backwards
    assert_raises(ReadingDiary::Error) do
      ReadingDiary.add_session(@data, id: "book-1", date: "2026-11-08", page: 121, note: "")
    end
    ReadingDiary.add_session(@data, id: "book-1", date: "2026-11-08", page: 40, note: "")
    assert_raises(ReadingDiary::Error) do
      ReadingDiary.add_session(@data, id: "book-1", date: "2026-11-08", page: 39, note: "")
    end
  end

  def test_invalid_date_and_duplicate_id
    assert_raises(ReadingDiary::Error) do
      ReadingDiary.add_session(@data, id: "book-1", date: "2026-02-30", page: 1, note: "")
    end
    assert_raises(ReadingDiary::Error) do
      ReadingDiary.add_book(@data, id: "book-1", title: "Outro", pages: 20)
    end
  end

  def test_invalid_attempt_does_not_modify_current_page
    assert_raises(ReadingDiary::Error) do
      ReadingDiary.add_session(@data, id: "book-1", date: "2026-11-08", page: -1, note: "")
    end
    assert_equal 0, ReadingDiary.summary(@data).first["current_page"]
  end
end
