# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "json"
require_relative "../lib/reading_diary/storage"

class ReadingDiaryStorageTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir("reading-diary-test-")
    @path = File.join(@directory, "books.json")
    @state = ReadingDiary.empty
    ReadingDiary.add_book(@state, id: "book", title: "Exemplo", pages: 120)
  end

  def teardown
    FileUtils.remove_entry(@directory) if File.exist?(@directory)
  end

  def test_load_missing_file_returns_empty
    assert_equal ReadingDiary.empty, ReadingDiary::Storage.load(@path)
    refute File.exist?(@path)
  end

  def test_save_and_load_round_trip
    assert ReadingDiary::Storage.save(@path, @state)
    assert_equal @state, ReadingDiary::Storage.load(@path)
  end

  def test_save_pretty_prints_with_trailing_newline
    ReadingDiary::Storage.save(@path, @state)
    payload = File.read(@path)
    assert payload.start_with?("{\n")
    assert payload.end_with?("\n")
    assert_equal @state, JSON.parse(payload)
  end

  def test_save_uses_private_file_permissions
    ReadingDiary::Storage.save(@path, @state)
    assert_equal 0o600, File.stat(@path).mode & 0o777
  end

  def test_save_replaces_existing_content_atomically
    ReadingDiary::Storage.save(@path, @state)
    ReadingDiary.add_book(@state, id: "other", title: "Outro", pages: 20)
    ReadingDiary::Storage.save(@path, @state)
    assert_equal 2, ReadingDiary::Storage.load(@path)["books"].size
    assert_empty Dir.glob(File.join(@directory, ".diario-*.tmp"))
  end

  def test_save_rejects_corrupt_state_without_overwriting
    ReadingDiary::Storage.save(@path, @state)
    previous = File.binread(@path)
    @state["books"][0]["current_page"] = 500
    assert_raises(ReadingDiary::Error) { ReadingDiary::Storage.save(@path, @state) }
    assert_equal previous, File.binread(@path)
  end

  def test_load_rejects_corrupt_json
    File.write(@path, "{invalid")
    error = assert_raises(ReadingDiary::Error) { ReadingDiary::Storage.load(@path) }
    assert_match(/JSON/, error.message)
  end

  def test_load_rejects_invalid_document
    File.write(@path, "[]")
    assert_raises(ReadingDiary::Error) { ReadingDiary::Storage.load(@path) }
    File.write(@path, '{"books":{}}')
    assert_raises(ReadingDiary::Error) { ReadingDiary::Storage.load(@path) }
  end

  def test_load_rejects_invalid_session_history
    ReadingDiary.add_session(@state, id: "book", date: "2026-11-08", page: 20, note: "ok")
    @state["books"][0]["current_page"] = 10
    File.write(@path, JSON.generate(@state))
    assert_raises(ReadingDiary::Error) { ReadingDiary::Storage.load(@path) }
  end

  def test_transaction_creates_file_and_persists_result
    result = ReadingDiary::Storage.transaction(@path) do |state|
      ReadingDiary.add_book(state, id: "first", title: "Primeiro", pages: 60)
    end
    assert_equal "first", result["id"]
    assert_equal "first", ReadingDiary::Storage.load(@path)["books"][0]["id"]
    assert File.exist?("#{@path}.lock")
  end

  def test_transaction_rolls_back_on_validation_error
    ReadingDiary::Storage.save(@path, @state)
    before = File.binread(@path)
    assert_raises(ReadingDiary::Error) do
      ReadingDiary::Storage.transaction(@path) do |state|
        ReadingDiary.add_book(state, id: "new", title: "Novo", pages: 5)
        raise ReadingDiary::Error, "falha simulada"
      end
    end
    assert_equal before, File.binread(@path)
  end

  def test_transaction_rolls_back_on_invalid_final_state
    ReadingDiary::Storage.save(@path, @state)
    assert_raises(ReadingDiary::Error) do
      ReadingDiary::Storage.transaction(@path) { |state| state["books"][0]["current_page"] = 500 }
    end
    assert_equal 0, ReadingDiary::Storage.load(@path)["books"][0]["current_page"]
  end

  def test_concurrent_transactions_do_not_lose_books
    threads = 12.times.map do |index|
      Thread.new do
        ReadingDiary::Storage.transaction(@path) do |state|
          ReadingDiary.add_book(state, id: "book-#{index}", title: "Livro #{index}", pages: 10)
        end
      end
    end
    threads.each(&:value)
    assert_equal 12, ReadingDiary::Storage.load(@path)["books"].size
  end

  def test_backup_preserves_original_and_creates_copy
    ReadingDiary::Storage.save(@path, @state)
    destination = File.join(@directory, "backup.json")
    assert_equal destination, ReadingDiary::Storage.backup(@path, destination)
    assert_equal @state, JSON.parse(File.read(destination))
    assert_equal @state, ReadingDiary::Storage.load(@path)
    assert_equal 0o600, File.stat(destination).mode & 0o777
  end

  def test_backup_refuses_to_overwrite_existing_file
    ReadingDiary::Storage.save(@path, @state)
    destination = File.join(@directory, "backup.json")
    File.write(destination, "original")
    assert_raises(ReadingDiary::Error) { ReadingDiary::Storage.backup(@path, destination) }
    assert_equal "original", File.read(destination)
  end

  def test_backup_requires_existing_source
    assert_raises(ReadingDiary::Error) do
      ReadingDiary::Storage.backup(@path, File.join(@directory, "backup.json"))
    end
  end

  def test_save_refuses_nonexistent_parent
    assert_raises(ReadingDiary::Error) do
      ReadingDiary::Storage.save(File.join(@directory, "missing", "books.json"), @state)
    end
  end

  def test_save_refuses_directory_as_file
    assert_raises(ReadingDiary::Error) { ReadingDiary::Storage.save(@directory, @state) }
  end

  def test_load_and_save_refuse_symbolic_link
    target = File.join(@directory, "target.json")
    File.write(target, JSON.generate(@state))
    File.symlink(target, @path)
    assert_raises(ReadingDiary::Error) { ReadingDiary::Storage.load(@path) }
    assert_raises(ReadingDiary::Error) { ReadingDiary::Storage.save(@path, @state) }
    assert_equal JSON.generate(@state), File.read(target)
  end

  def test_transaction_refuses_symbolic_lock_file
    File.symlink(@path, "#{@path}.lock")
    assert_raises(ReadingDiary::Error) do
      ReadingDiary::Storage.transaction(@path) { |state| state }
    end
  end

  def test_invalid_paths_are_rejected
    ["", "\0", nil].each do |path|
      assert_raises(ReadingDiary::Error) { ReadingDiary::Storage.check_path!(path) }
    end
  end
end
