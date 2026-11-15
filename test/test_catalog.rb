# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/reading_diary/catalog"

class ReadingDiaryCatalogTest < Minitest::Test
  def setup
    @state = ReadingDiary.empty
    ReadingDiary.add_book(@state, id: "alpha", title: "  Ruby Profundo  ", pages: 200)
    ReadingDiary.add_book(@state, id: "beta", title: "Historia", pages: 80)
  end

  def read(id, date, page, note = "")
    ReadingDiary.add_session(@state, id: id, date: date, page: page, note: note)
  end

  def test_empty_state_is_valid
    assert_equal({ "books" => [] }, ReadingDiary.validate!(ReadingDiary.empty))
  end

  def test_add_book_normalizes_title
    assert_equal "Ruby Profundo", ReadingDiary.find_book(@state, "alpha")["title"]
    assert_equal 2, ReadingDiary.books(@state).length
  end

  def test_duplicate_id_rejected_without_mutation
    assert_raises(ReadingDiary::Error) do
      ReadingDiary.add_book(@state, id: "alpha", title: "Duplicado", pages: 3)
    end
    assert_equal 2, @state["books"].size
  end

  def test_invalid_ids_and_page_limits
    ["", "UPPER", "has space", "a" * 51].each do |id|
      assert_raises(ReadingDiary::Error) { ReadingDiary.add_book(@state, id: id, title: "X", pages: 1) }
    end
    [0, -1, 100_001, 1.5].each do |pages|
      assert_raises(ReadingDiary::Error) { ReadingDiary.add_book(@state, id: "new", title: "X", pages: pages) }
    end
  end

  def test_rename_book_changes_only_target
    ReadingDiary.rename_book(@state, id: "alpha", title: "  Novo titulo ")
    assert_equal "Novo titulo", ReadingDiary.find_book(@state, "alpha")["title"]
    assert_equal "Historia", ReadingDiary.find_book(@state, "beta")["title"]
  end

  def test_rename_rejects_blank_and_overlong_title
    ["  ", "x" * 201].each do |title|
      assert_raises(ReadingDiary::Error) { ReadingDiary.rename_book(@state, id: "alpha", title: title) }
    end
    assert_equal "Ruby Profundo", ReadingDiary.find_book(@state, "alpha")["title"]
  end

  def test_tags_normalized_and_deduplicated
    ReadingDiary.set_tags(@state, id: "alpha", tags: [" Tech ", "tech", "estudo"])
    assert_equal %w[tech estudo], ReadingDiary.find_book(@state, "alpha")["tags"]
    assert_equal @state, ReadingDiary.validate!(@state)
  end

  def test_tags_reject_invalid_values
    ["com espaco", "", "x" * 31, "@mal"].each do |tag|
      assert_raises(ReadingDiary::Error) { ReadingDiary.set_tags(@state, id: "alpha", tags: [tag]) }
    end
    assert_raises(ReadingDiary::Error) { ReadingDiary.set_tags(@state, id: "alpha", tags: ["a"] * 21) }
  end

  def test_tags_can_be_cleared
    ReadingDiary.set_tags(@state, id: "alpha", tags: ["tech"])
    ReadingDiary.set_tags(@state, id: "alpha", tags: [])
    assert_empty ReadingDiary.find_book(@state, "alpha")["tags"]
  end

  def test_goal_can_be_set_and_removed
    ReadingDiary.set_goal(@state, id: "alpha", pages_per_day: 25)
    assert_equal 25, ReadingDiary.find_book(@state, "alpha")["goal"]
    ReadingDiary.set_goal(@state, id: "alpha", pages_per_day: nil)
    refute ReadingDiary.find_book(@state, "alpha").key?("goal")
  end

  def test_invalid_goals_do_not_change_book
    [0, -3, 1001, 1.2, "20"].each do |goal|
      assert_raises(ReadingDiary::Error) { ReadingDiary.set_goal(@state, id: "alpha", pages_per_day: goal) }
    end
    refute ReadingDiary.find_book(@state, "alpha").key?("goal")
  end

  def test_undo_last_session_restores_previous_page
    read("alpha", "2026-11-01", 25)
    read("alpha", "2026-11-02", 70)
    removed = ReadingDiary.undo_last_session(@state, id: "alpha")
    assert_equal 70, removed["page"]
    assert_equal 25, ReadingDiary.find_book(@state, "alpha")["current_page"]
    assert_equal 1, ReadingDiary.find_book(@state, "alpha")["sessions"].size
    assert_equal @state, ReadingDiary.validate!(@state)
  end

  def test_undo_last_session_to_zero_and_no_sessions_error
    read("alpha", "2026-11-01", 10)
    ReadingDiary.undo_last_session(@state, id: "alpha")
    assert_equal 0, ReadingDiary.find_book(@state, "alpha")["current_page"]
    assert_raises(ReadingDiary::Error) { ReadingDiary.undo_last_session(@state, id: "alpha") }
  end

  def test_remove_book_preserves_other_books
    read("alpha", "2026-11-01", 10)
    removed = ReadingDiary.remove_book(@state, id: "alpha")
    assert_equal "alpha", removed["id"]
    assert_equal ["beta"], ReadingDiary.books(@state).map { |book| book["id"] }
    assert_raises(ReadingDiary::Error) { ReadingDiary.find_book(@state, "alpha") }
  end

  def test_search_books_by_title_id_and_tags
    ReadingDiary.set_tags(@state, id: "alpha", tags: ["tecnologia"])
    assert_equal ["alpha"], ReadingDiary.search_books(@state, query: "ruby").map { |b| b["id"] }
    assert_equal ["beta"], ReadingDiary.search_books(@state, query: "BET").map { |b| b["id"] }
    assert_equal ["alpha"], ReadingDiary.search_books(@state, tag: "tecnologia").map { |b| b["id"] }
  end

  def test_search_by_status
    read("alpha", "2026-11-01", 30)
    read("beta", "2026-11-01", 80)
    assert_equal ["alpha"], ReadingDiary.search_books(@state, status: "reading").map { |b| b["id"] }
    assert_equal ["beta"], ReadingDiary.search_books(@state, status: "finished").map { |b| b["id"] }
    assert_empty ReadingDiary.search_books(@state, status: "unread")
  end

  def test_search_invalid_filters
    assert_raises(ReadingDiary::Error) { ReadingDiary.search_books(@state, status: "unknown") }
    assert_raises(ReadingDiary::Error) { ReadingDiary.search_books(@state, tag: "a b") }
    assert_raises(ReadingDiary::Error) { ReadingDiary.search_books(@state, query: "x" * 201) }
  end

  def test_search_notes_returns_context_and_is_case_insensitive
    read("alpha", "2026-11-01", 10, "Aprendi sobre Classes")
    read("alpha", "2026-11-02", 20, "outro capitulo")
    read("beta", "2026-11-03", 5, "classes historicas")
    matches = ReadingDiary.search_notes(@state, query: "CLASSES")
    assert_equal 2, matches.length
    assert_equal %w[alpha beta], matches.map { |entry| entry["book_id"] }
    assert_equal [0, 0], matches.map { |entry| entry["session_index"] }
    assert_equal 1, ReadingDiary.search_notes(@state, query: "classes", id: "alpha").size
  end

  def test_search_notes_rejects_empty_query
    ["", " ", "a" * 201].each do |query|
      assert_raises(ReadingDiary::Error) { ReadingDiary.search_notes(@state, query: query) }
    end
  end

  def test_validation_detects_duplicate_and_inconsistent_progress
    @state["books"][1]["id"] = "alpha"
    assert_raises(ReadingDiary::Error) { ReadingDiary.validate!(@state) }
    @state["books"][1]["id"] = "beta"
    @state["books"][0]["current_page"] = 10
    assert_raises(ReadingDiary::Error) { ReadingDiary.validate!(@state) }
  end

  def test_validation_rejects_corrupted_sessions
    read("alpha", "2026-11-01", 10)
    session = ReadingDiary.find_book(@state, "alpha")["sessions"].first
    session["date"] = "2026-02-30"
    assert_raises(ReadingDiary::Error) { ReadingDiary.validate!(@state) }
    session["date"] = "2026-11-01"
    session["page"] = 500
    assert_raises(ReadingDiary::Error) { ReadingDiary.validate!(@state) }
  end

  def test_failed_read_does_not_append_session
    read("alpha", "2026-11-05", 40)
    assert_raises(ReadingDiary::Error) { read("alpha", "2026-11-04", 50) }
    assert_raises(ReadingDiary::Error) { read("alpha", "2026-11-06", 20) }
    assert_equal 1, ReadingDiary.find_book(@state, "alpha")["sessions"].length
  end
end
