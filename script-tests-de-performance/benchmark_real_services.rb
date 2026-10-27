# frozen_string_literal: true
# ==============================================================================
# POSTGRESQL PERFORMANCE AUDIT HARNESS
# Real-world Application Services Benchmark on 19.6M Rows
#
# Author: Romain Chavalle
# Description:
#   This harness loads the full Rails application runtime without shortcuts or
#   extrapolations, instruments ActiveRecord SQL queries via ActiveSupport::Notifications,
#   and measures wall-clock execution time and database query durations.
# ==============================================================================

ENV["DATABASE_URL"] ||= "postgresql://postgres:postgres@localhost:5435/good_meal_benchmark"

# Load the host Rails environment
rails_root = ENV["RAILS_ROOT"] || "/home/romain/code/romainchavalle/OPENCLASSROOMS/PROJET-OPEN/good_meal"
require File.expand_path("config/environment", rails_root)

puts "\n" + "=" * 80
puts "POSTGRESQL PERFORMANCE AUDIT HARNESS - REAL SERVICES BENCHMARK"
puts "Target Database : #{ActiveRecord::Base.connection.current_database}"
puts "Scale Context   : Surveys: #{Survey.count} | Answers: #{Answer.count} | Customer Indicators: #{CustomerIndicator.count}"
puts "=" * 80 + "\n"

# Benchmark Target Configuration (Representative Multi-Unit Franchise Dataset)
group = Group.find(750)
user = User.find_by(admin: true) || group.users.first
session_id = SecureRandom.hex(16)

# Real filter scenario: 21 restaurants, 8 historical annual ranges, filtered by demographic indicator
raw_resto_ids = "2491,2504,2494,2507,2490,2503,2492,2495,2501,2509,2496,2499,2506,2505,2720,2508,3957,4729,2497,2500,2502".split(",").map(&:to_i)
parsed_indicators = { "Âge" => ["31 - 45 ans"] }

filter_params_dashboard = {
  timeframe: "thisYear",
  start_date: Date.new(2026, 1, 1),
  end_date: Date.new(2026, 12, 31),
  restaurant_ids: raw_resto_ids,
  indicators: parsed_indicators,
  num_ranges: 8
}

filter_params_gq = filter_params_dashboard.merge(
  gq: "Qualité de service"
)

# Test suite executing the 4 critical dashboard builders
tests = [
  {
    name: "1. Dashboard::NpsEvolutionDataBuilder (NPS Evolution)",
    block: -> {
      builder = Dashboard::NpsEvolutionDataBuilder.new(
        user: user,
        group: group,
        session_id: session_id,
        qvct: false,
        filter_params: filter_params_dashboard
      )
      builder.build
    }
  },
  {
    name: "2. Dashboard::CsatEvolutionDataBuilder (CSAT Evolution)",
    block: -> {
      builder = Dashboard::CsatEvolutionDataBuilder.new(
        user: user,
        group: group,
        session_id: session_id,
        qvct: false,
        filter_params: filter_params_dashboard
      )
      builder.build
    }
  },
  {
    name: "3. DetailGroupeQuestion::CsatTableBuilder (GQ - CSAT Table)",
    block: -> {
      builder = DetailGroupeQuestion::CsatTableBuilder.new(
        user: user,
        group: group,
        session_id: session_id,
        filter_params: filter_params_gq
      )
      builder.build
    }
  },
  {
    name: "4. DetailGroupeQuestion::QuestionsBuilder (GQ - Questions List)",
    block: -> {
      builder = DetailGroupeQuestion::QuestionsBuilder.new(
        user: user,
        group: group,
        session_id: session_id,
        filter_params: filter_params_gq
      )
      builder.build
    }
  }
]

results = []

tests.each do |t|
  puts "\n>>> Executing : #{t[:name]}..."
  
  sql_queries = []
  total_sql_time = 0.0

  # Instrument ActiveRecord query execution via Rails event bus
  subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, start, finish, _id, payload|
    next if payload[:name] =~ /SCHEMA|TRANSACTION/
    duration = (finish - start) * 1000.0
    sql_queries << { sql: payload[:sql], duration: duration }
    total_sql_time += duration
  end

  wall_clock_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  
  begin
    t[:block].call
    wall_clock_time = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - wall_clock_start) * 1000.0).round(2)
    slowest_query = sql_queries.max_by { |q| q[:duration] }

    puts "    [SUCCESS] Total Duration : #{wall_clock_time} ms | SQL Cumulative : #{total_sql_time.round(2)} ms (#{sql_queries.count} queries)"
    if slowest_query
      truncated_sql = slowest_query[:sql].gsub(/\s+/, " ").strip[0..120]
      puts "    [WORST QUERY] #{slowest_query[:duration].round(2)} ms : #{truncated_sql}..."
    end

    results << {
      name: t[:name],
      wall_clock: wall_clock_time,
      sql_time: total_sql_time.round(2),
      queries_count: sql_queries.count
    }
  rescue StandardError => e
    puts "    [ERROR] Failed with exception : #{e.class} - #{e.message}"
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end

puts "\n" + "=" * 80
puts "CONSOLIDATED BENCHMARK SUMMARY"
puts "=" * 80
printf "%-60s | %-12s | %-12s | %-12s\n", "Service Tested", "Total Time", "SQL Time", "Query Count"
puts "-" * 100
results.each do |r|
  printf "%-60s | %10.1f ms | %10.1f ms | %10d\n", r[:name], r[:wall_clock], r[:sql_time], r[:queries_count]
end
puts "=" * 80 + "\n"
