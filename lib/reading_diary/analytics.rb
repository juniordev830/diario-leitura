# frozen_string_literal: true

require "date"
require_relative "catalog"

module ReadingDiary
  def self.daily_pages_for(book)
    previous = 0
    days = Hash.new(0)
    book.fetch("sessions").each do |session|
      gained = session.fetch("page") - previous
      days[session.fetch("date")] += gained
      previous = session.fetch("page")
    end
    days.sort.to_h
  end

  def self.daily_pages(state, from: nil, to: nil)
    validate_range!(from, to)
    totals = Hash.new(0)
    books(state).each do |book|
      daily_pages_for(book).each do |date, pages|
        next if from && date < from
        next if to && date > to
        totals[date] += pages
      end
    end
    totals.sort.to_h
  end

  def self.validate_range!(from, to)
    [from, to].compact.each do |date|
      begin
        raise Error, "data invalida" unless date.is_a?(String) && Date.iso8601(date).iso8601 == date
      rescue Date::Error, TypeError
        raise Error, "data invalida"
      end
    end
    raise Error, "intervalo invertido" if from && to && from > to
    true
  end

  def self.book_report(state, id:)
    book = find_book(state, id)
    daily = daily_pages_for(book)
    remaining = book["pages"] - book["current_page"]
    active_days = daily.count { |_, pages| pages.positive? }
    average = active_days.zero? ? 0.0 : (book["current_page"].to_f / active_days).round(2)
    {
      "id" => book["id"],
      "title" => book["title"],
      "total_pages" => book["pages"],
      "read_pages" => book["current_page"],
      "remaining_pages" => remaining,
      "completion_percent" => (100.0 * book["current_page"] / book["pages"]).round(2),
      "sessions" => book["sessions"].length,
      "active_days" => active_days,
      "average_pages_per_active_day" => average,
      "last_read" => book["sessions"].last&.fetch("date"),
      "goal_pages_per_day" => book["goal"],
      "tags" => book.fetch("tags", []),
      "status" => remaining.zero? ? "finished" : (book["current_page"].zero? ? "unread" : "reading")
    }
  end

  def self.overview(state)
    validate!(state)
    reports = books(state).map { |book| book_report(state, id: book["id"]) }
    daily = daily_pages(state)
    {
      "books" => reports.length,
      "unread" => reports.count { |book| book["status"] == "unread" },
      "reading" => reports.count { |book| book["status"] == "reading" },
      "finished" => reports.count { |book| book["status"] == "finished" },
      "pages_read" => reports.sum { |book| book["read_pages"] },
      "pages_total" => reports.sum { |book| book["total_pages"] },
      "sessions" => reports.sum { |book| book["sessions"] },
      "active_days" => daily.count { |_, pages| pages.positive? },
      "most_recent_activity" => daily.keys.last,
      "streak" => reading_streak(daily),
      "books_by_progress" => reports.sort_by { |book| [-book["completion_percent"], book["id"]] }
    }
  end

  def self.reading_streak(daily)
    active = daily.select { |_, pages| pages.positive? }.keys
    return { "longest" => 0, "last" => 0, "ended_on" => nil } if active.empty?
    longest = 1
    run = 1
    active.each_cons(2) do |previous, current|
      run = (Date.iso8601(current) - Date.iso8601(previous)).to_i == 1 ? run + 1 : 1
      longest = [longest, run].max
    end
    { "longest" => longest, "last" => run, "ended_on" => active.last }
  end

  def self.period_report(state, from:, to:)
    validate_range!(from, to)
    raise Error, "periodo exige datas inicial e final" unless from && to
    days = daily_pages(state, from: from, to: to)
    by_book = books(state).map do |book|
      values = daily_pages_for(book).select { |date, _| date >= from && date <= to }
      { "id" => book["id"], "pages" => values.values.sum, "days" => values.count { |_, count| count.positive? } }
    end
    {
      "from" => from, "to" => to,
      "days" => (Date.iso8601(to) - Date.iso8601(from)).to_i + 1,
      "pages" => days.values.sum,
      "active_days" => days.count { |_, count| count.positive? },
      "average_pages_per_calendar_day" => (days.values.sum.to_f / ((Date.iso8601(to) - Date.iso8601(from)).to_i + 1)).round(2),
      "by_book" => by_book,
      "daily" => days
    }
  end

  def self.goal_report(state, id:, on:)
    validate_range!(on, on)
    book = find_book(state, id)
    goal = book["goal"]
    raise Error, "meta diaria nao configurada" unless goal
    date = Date.iso8601(on)
    from = (date - 6).iso8601
    last_week = daily_pages_for(book).select { |day, _| day >= from && day <= on }
    total = last_week.values.sum
    expected = goal * 7
    {
      "id" => id, "from" => from, "to" => on,
      "goal_per_day" => goal, "target_pages" => expected,
      "actual_pages" => total,
      "difference" => total - expected,
      "achieved" => total >= expected,
      "active_days" => last_week.count { |_, count| count.positive? },
      "today_pages" => last_week.fetch(on, 0)
    }
  end

  def self.estimate_finish(state, id:, on:)
    validate_range!(on, on)
    book = find_book(state, id)
    remaining = book["pages"] - book["current_page"]
    return { "id" => id, "days" => 0, "date" => on, "method" => "finished" } if remaining.zero?
    goal = book["goal"]
    if goal
      days = (remaining.to_f / goal).ceil
      return { "id" => id, "days" => days, "date" => (Date.iso8601(on) + days).iso8601, "method" => "goal" }
    end
    recent_start = (Date.iso8601(on) - 29).iso8601
    recent = daily_pages_for(book).select { |date, _| date >= recent_start && date <= on }
    pace = recent.values.sum / 30.0
    return { "id" => id, "days" => nil, "date" => nil, "method" => "insufficient_activity" } if pace.zero?
    days = (remaining / pace).ceil
    { "id" => id, "days" => days, "date" => (Date.iso8601(on) + days).iso8601, "method" => "recent_30_days" }
  end

  def self.history(state, id: nil, from: nil, to: nil)
    validate_range!(from, to)
    source = id ? [find_book(state, id)] : books(state)
    source.flat_map do |book|
      previous = 0
      book["sessions"].filter_map do |session|
        pages = session["page"] - previous
        previous = session["page"]
        next if from && session["date"] < from
        next if to && session["date"] > to
        { "book_id" => book["id"], "date" => session["date"], "page" => session["page"],
          "pages_read" => pages, "note" => session["note"] }
      end
    end.sort_by { |entry| [entry["date"], entry["book_id"], entry["page"]] }
  end

  def self.monthly_pages(state)
    daily_pages(state).each_with_object(Hash.new(0)) do |(date, pages), months|
      months[date[0, 7]] += pages
    end.sort.to_h
  end
end
