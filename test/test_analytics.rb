# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/reading_diary/analytics"

class ReadingDiaryAnalyticsTest < Minitest::Test
  def setup
    @state = ReadingDiary.empty
    ReadingDiary.add_book(@state, id: "alpha", title: "Livro A", pages: 100)
    ReadingDiary.add_book(@state, id: "beta", title: "Livro B", pages: 80)
    read("alpha", "2026-11-01", 10)
    read("alpha", "2026-11-02", 30)
    read("alpha", "2026-11-02", 35)
    read("alpha", "2026-11-04", 55)
    read("beta", "2026-11-02", 20)
    read("beta", "2026-11-03", 40)
    read("beta", "2026-11-04", 80)
  end

  def read(id, date, page)
    ReadingDiary.add_session(@state, id: id, date: date, page: page, note: "Nota #{page}")
  end

  def test_daily_pages_uses_deltas_not_cumulative_page
    book = ReadingDiary.find_book(@state, "alpha")
    assert_equal({ "2026-11-01" => 10, "2026-11-02" => 25, "2026-11-04" => 20 },
                 ReadingDiary.daily_pages_for(book))
  end

  def test_daily_pages_aggregates_books_on_same_day
    assert_equal({ "2026-11-01" => 10, "2026-11-02" => 45,
                   "2026-11-03" => 20, "2026-11-04" => 60 },
                 ReadingDiary.daily_pages(@state))
  end

  def test_daily_pages_date_filters_are_inclusive
    assert_equal({ "2026-11-02" => 45, "2026-11-03" => 20 },
                 ReadingDiary.daily_pages(@state, from: "2026-11-02", to: "2026-11-03"))
  end

  def test_daily_pages_empty_range
    assert_empty ReadingDiary.daily_pages(@state, from: "2026-10-01", to: "2026-10-31")
  end

  def test_validate_range_rejects_invalid_date_and_reversed_bounds
    assert_raises(ReadingDiary::Error) { ReadingDiary.validate_range!("2026-02-30", nil) }
    assert_raises(ReadingDiary::Error) { ReadingDiary.validate_range!("2026-11-04", "2026-11-01") }
    assert_raises(ReadingDiary::Error) { ReadingDiary.validate_range!("2026-1-1", nil) }
  end

  def test_book_report_contains_progress_and_average
    report = ReadingDiary.book_report(@state, id: "alpha")
    assert_equal 55, report["read_pages"]
    assert_equal 45, report["remaining_pages"]
    assert_equal 55.0, report["completion_percent"]
    assert_equal 4, report["sessions"]
    assert_equal 3, report["active_days"]
    assert_equal 18.33, report["average_pages_per_active_day"]
    assert_equal "reading", report["status"]
  end

  def test_finished_book_report
    report = ReadingDiary.book_report(@state, id: "beta")
    assert_equal "finished", report["status"]
    assert_equal 100.0, report["completion_percent"]
    assert_equal 0, report["remaining_pages"]
  end

  def test_unread_book_has_zero_average
    ReadingDiary.add_book(@state, id: "gamma", title: "Novo", pages: 40)
    report = ReadingDiary.book_report(@state, id: "gamma")
    assert_equal "unread", report["status"]
    assert_equal 0.0, report["average_pages_per_active_day"]
    assert_nil report["last_read"]
  end

  def test_overview_counts_book_statuses
    ReadingDiary.add_book(@state, id: "gamma", title: "Novo", pages: 40)
    report = ReadingDiary.overview(@state)
    assert_equal 3, report["books"]
    assert_equal 1, report["unread"]
    assert_equal 1, report["reading"]
    assert_equal 1, report["finished"]
  end

  def test_overview_counts_pages_sessions_and_active_days
    report = ReadingDiary.overview(@state)
    assert_equal 135, report["pages_read"]
    assert_equal 180, report["pages_total"]
    assert_equal 7, report["sessions"]
    assert_equal 4, report["active_days"]
    assert_equal "2026-11-04", report["most_recent_activity"]
  end

  def test_overview_sorts_by_completion
    ids = ReadingDiary.overview(@state)["books_by_progress"].map { |book| book["id"] }
    assert_equal %w[beta alpha], ids
  end

  def test_streak_across_consecutive_days
    assert_equal({ "longest" => 4, "last" => 4, "ended_on" => "2026-11-04" },
                 ReadingDiary.reading_streak(ReadingDiary.daily_pages(@state)))
  end

  def test_streak_ignores_zero_page_sessions
    assert_equal({ "longest" => 0, "last" => 0, "ended_on" => nil },
                 ReadingDiary.reading_streak({ "2026-11-01" => 0 }))
  end

  def test_streak_resets_on_gaps
    daily = { "2026-11-01" => 5, "2026-11-02" => 1, "2026-11-05" => 4 }
    assert_equal 2, ReadingDiary.reading_streak(daily)["longest"]
    assert_equal 1, ReadingDiary.reading_streak(daily)["last"]
  end

  def test_period_report_has_calendar_average_and_breakdown
    report = ReadingDiary.period_report(@state, from: "2026-11-02", to: "2026-11-03")
    assert_equal 2, report["days"]
    assert_equal 65, report["pages"]
    assert_equal 2, report["active_days"]
    assert_equal 32.5, report["average_pages_per_calendar_day"]
    assert_equal [25, 40], report["by_book"].map { |book| book["pages"] }
  end

  def test_period_report_requires_both_dates
    assert_raises(ReadingDiary::Error) { ReadingDiary.period_report(@state, from: nil, to: "2026-11-04") }
  end

  def test_goal_report_calculates_last_seven_calendar_days
    ReadingDiary.set_goal(@state, id: "alpha", pages_per_day: 10)
    report = ReadingDiary.goal_report(@state, id: "alpha", on: "2026-11-04")
    assert_equal "2026-10-29", report["from"]
    assert_equal 70, report["target_pages"]
    assert_equal 55, report["actual_pages"]
    assert_equal(-15, report["difference"])
    refute report["achieved"]
    assert_equal 20, report["today_pages"]
  end

  def test_goal_report_without_goal_raises
    assert_raises(ReadingDiary::Error) { ReadingDiary.goal_report(@state, id: "alpha", on: "2026-11-04") }
  end

  def test_estimate_finish_prefers_explicit_goal
    ReadingDiary.set_goal(@state, id: "alpha", pages_per_day: 10)
    estimate = ReadingDiary.estimate_finish(@state, id: "alpha", on: "2026-11-04")
    assert_equal "goal", estimate["method"]
    assert_equal 5, estimate["days"]
    assert_equal "2026-11-09", estimate["date"]
  end

  def test_estimate_finished_book
    estimate = ReadingDiary.estimate_finish(@state, id: "beta", on: "2026-11-04")
    assert_equal "finished", estimate["method"]
    assert_equal 0, estimate["days"]
  end

  def test_estimate_without_recent_activity_is_unknown
    ReadingDiary.add_book(@state, id: "gamma", title: "Novo", pages: 50)
    estimate = ReadingDiary.estimate_finish(@state, id: "gamma", on: "2026-11-04")
    assert_equal "insufficient_activity", estimate["method"]
    assert_nil estimate["date"]
  end

  def test_estimate_uses_thirty_day_average_without_goal
    estimate = ReadingDiary.estimate_finish(@state, id: "alpha", on: "2026-11-04")
    assert_equal "recent_30_days", estimate["method"]
    assert_equal 25, estimate["days"]
    assert_equal "2026-11-29", estimate["date"]
  end

  def test_history_includes_session_deltas
    history = ReadingDiary.history(@state, id: "alpha")
    assert_equal [10, 20, 5, 20], history.map { |entry| entry["pages_read"] }
    assert_equal %w[2026-11-01 2026-11-02 2026-11-02 2026-11-04],
                 history.map { |entry| entry["date"] }
  end

  def test_history_filters_dates_without_losing_previous_page
    history = ReadingDiary.history(@state, id: "alpha", from: "2026-11-02", to: "2026-11-02")
    assert_equal [20, 5], history.map { |entry| entry["pages_read"] }
  end

  def test_monthly_pages_aggregates_all_books
    assert_equal({ "2026-11" => 135 }, ReadingDiary.monthly_pages(@state))
  end

  def test_overview_empty_state
    report = ReadingDiary.overview(ReadingDiary.empty)
    assert_equal 0, report["books"]
    assert_equal 0, report["pages_read"]
    assert_nil report["most_recent_activity"]
  end
end
