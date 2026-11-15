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

  def test_returned_book_cannot_change_internal_progress
    book = @journal.add_book(id: 'novo', title: 'Novo livro', total_pages: 50)
    assert_raises(FrozenError) { book.current_page = 200 }
    assert_raises(FrozenError) { book.sessions << { pages: 200 } }
    assert_equal 0, @journal.progress('novo')[:current_page]
  end

  def test_input_strings_do_not_alias_saved_sessions
    id = String.new('novo')
    date = String.new('2026-11-10')
    note = String.new('Original')
    @journal.add_book(id: id, title: 'Novo livro', total_pages: 50)
    @journal.record(id: id, date: date, pages: 10, note: note)
    id.replace('alterado')
    date.replace('inválida')
    note.replace('Modificada')
    result = @journal.progress('novo')
    assert_equal 'novo', result[:id]
    assert_equal '2026-11-10', result[:notes][0][:date]
    assert_equal 'Original', result[:notes][0][:note]
  end

  def test_progress_notes_cannot_mutate_stored_text
    @journal.record(id: 'livro', date: '2026-11-10', pages: 5, note: 'Original')
    result = @journal.progress('livro')
    assert_raises(FrozenError) { result[:notes][0][:note].replace('Outra') }
    result[:notes].clear
    assert_equal 'Original', @journal.progress('livro')[:notes][0][:note]
  end

  def test_false_goal_is_not_treated_as_default
    assert_raises(ArgumentError) do
      @journal.add_book(id: 'novo', title: 'Livro', total_pages: 50, goal_pages: false)
    end
    refute_includes @journal.ids, 'novo'
  end

  def test_non_object_backup_sessions_rejected_consistently
    [nil, 1, 'texto', []].each do |bad|
      data = JSON.parse(@journal.to_json)
      data['books'][0]['sessions'] = [bad]
      assert_raises(ArgumentError) { ReadingJournal.from_json(JSON.generate(data)) }
    end
  end

end

