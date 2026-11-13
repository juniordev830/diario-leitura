# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../lib/reading_journal'

class ReadingJournalTest < Minitest::Test
  def setup
    @journal = ReadingJournal.new
    @journal.add_book(id: 'livro', title: 'Manual de exemplo', total_pages: 100, goal_pages: 40)
  end

  def test_two_sessions_update_progress_and_goal
    @journal.record(id: 'livro', date: '2026-11-09', pages: 15)
    progress = @journal.record(id: 'livro', date: '2026-11-10', pages: 25, note: 'Revisei capítulo')
    assert_equal 40, progress[:current_page]
    assert_equal 40.0, progress[:percent]
    assert progress[:goal_reached]
    assert_equal 2, progress[:sessions]
    assert_equal 1, progress[:notes].length
  end

  def test_cannot_read_beyond_end
    assert_raises(ArgumentError) do
      @journal.record(id: 'livro', date: '2026-11-10', pages: 101)
    end
    assert_equal 0, @journal.progress('livro')[:current_page]
  end

  def test_duplicate_id_bad_date_or_pages
    assert_raises(ArgumentError) do
      @journal.add_book(id: 'livro', title: 'Outro', total_pages: 5)
    end
    assert_raises(ArgumentError) do
      @journal.record(id: 'livro', date: '2026-02-30', pages: 1)
    end
    assert_raises(ArgumentError) do
      @journal.record(id: 'livro', date: '2026-11-01', pages: -1)
    end
  end

  def test_backup_roundtrip
    @journal.record(id: 'livro', date: '2026-11-01', pages: 20, note: 'Olá')
    restored = ReadingJournal.from_json(@journal.to_json)
    assert_equal @journal.progress('livro'), restored.progress('livro')
  end

  def test_tampered_backup_rejected
    assert_raises(ArgumentError) { ReadingJournal.from_json('{"version":2,"books":[]}') }
    assert_raises(ArgumentError) { ReadingJournal.from_json('invalid json') }
  end
end
