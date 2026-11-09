#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/reading_diary/cli"

exit ReadingDiary::CLI.run(ARGV)
