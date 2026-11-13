# frozen_string_literal: true
require_relative '../lib/reading_journal'
journal = ReadingJournal.new
journal.add_book(id: 'exemplo', title: 'Livro fictício', total_pages: 120, goal_pages: 60)
journal.record(id: 'exemplo', date: '2026-11-10', pages: 20, note: 'Capítulo inicial')
journal.record(id: 'exemplo', date: '2026-11-11', pages: 40, note: 'Anotações de estudo')
puts JSON.pretty_generate(journal.progress('exemplo'))
