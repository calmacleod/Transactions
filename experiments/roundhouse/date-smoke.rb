require_relative '../../tmp/roundhouse/toolchain/runtime/ruby/active_support_ext'
require_relative '../../tmp/roundhouse/toolchain/runtime/spinel/active_support_time_parsing'
require_relative 'compat/date'

january = Date.iso8601('2024-01-31')
raise 'month clamp' unless january.advance(months: 1).iso8601 == '2024-02-29'
raise 'week boundary' unless Date.iso8601('2026-10-01').beginning_of_week.iso8601 == '2026-09-28'
raise 'month boundary' unless Date.iso8601('2026-10-01').end_of_month.iso8601 == '2026-10-31'
raise 'day subtraction' unless Date.iso8601('2026-10-01') - Date.iso8601('2026-09-29') == 2
raise 'date keys' unless { january => 123 }.fetch(Date.iso8601('2024-01-31'), 0) == 123
raise 'date grouping' unless [january, Date.iso8601('2024-01-31')].group_by { |d| d }.size == 1
raise 'date hydration' unless ActiveSupport.parse_db_date('2026-10-01').iso8601 == '2026-10-01'
range = DateRange.new(Date.iso8601('2026-10-01'), Date.iso8601('2026-10-31'))
raise 'inclusive end' unless range.cover?(Date.iso8601('2026-10-31'))
raise 'exclusive end' if DateRange.new(range.begin, range.end, true).cover?(range.end)
raise 'invalid date accepted' unless begin
  Date.iso8601('2026-02-29')
  false
rescue ArgumentError
  true
end
values = [Date.iso8601('2026-10-01'), Time.utc(2026, 10, 2)]
raise 'boxed date and time formatting' unless values.map { |value| value.strftime('%Y-%m-%d') } == ['2026-10-01', '2026-10-02']
puts 'Native date contracts passed'
