# Gregorian date values for the native runtime. A date has no time zone
# or time of day; database and JSON representations stay YYYY-MM-DD.
class Date
  DAYNAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
  attr_reader :days

  def initialize(year, month = 1, day = 1)
    raise ArgumentError, 'invalid date' if month < 1 || month > 12 || day < 1 || day > ActiveSupport.days_in_month(year, month)
    @days = ActiveSupport.civil_days(year, month, day)
  end

  def self.current
    from_time(ActiveSupport.now)
  end

  def self.today
    current
  end

  def self.from_time(time)
    new(time.year, time.mon, time.mday)
  end

  def self.iso8601(value)
    match = /\A(\d{4})-(\d{2})-(\d{2})\z/.match(value.to_s)
    raise ArgumentError, 'invalid date' unless match
    new(match[1].to_i, match[2].to_i, match[3].to_i)
  end

  def self.strptime(value, pattern)
    return iso8601(value) if pattern == '%Y-%m-%d'
    if pattern == '%Y-%m' && /\A\d{4}-\d{2}\z/.match(value)
      return iso8601(value + '-01')
    end
    raise ArgumentError, 'unsupported date format'
  end

  def self.from_days(days)
    time = Time.at(days * 86400).utc
    new(time.year, time.mon, time.mday)
  end

  def to_time
    Time.at(@days * 86400).utc
  end

  def year
    to_time.year
  end

  def month
    to_time.mon
  end

  def mon
    month
  end

  def day
    to_time.mday
  end

  def mday
    day
  end

  def wday
    to_time.wday
  end

  def strftime(pattern)
    to_time.strftime(pattern)
  end

  def iso8601
    strftime('%Y-%m-%d')
  end

  def to_s
    iso8601
  end

  def to_date
    self
  end

  def beginning_of_month
    Date.new(year, month, 1)
  end

  def end_of_month
    Date.new(year, month, ActiveSupport.days_in_month(year, month))
  end

  def beginning_of_week
    Date.from_days(@days - (wday + 6) % 7)
  end

  def end_of_week
    beginning_of_week + 6
  end

  def advance(years: 0, months: 0, weeks: 0, days: 0)
    total = year * 12 + month - 1 + years * 12 + months
    y = total.div(12)
    m = total % 12 + 1
    d = [day, ActiveSupport.days_in_month(y, m)].min
    Date.new(y, m, d) + weeks * 7 + days
  end

  def next_month(amount = 1)
    advance(months: amount)
  end

  def prev_month(amount = 1)
    advance(months: -amount)
  end

  def +(amount)
    Date.from_days(@days + amount)
  end

  def -(other)
    other.is_a?(Date) ? @days - other.days : Date.from_days(@days - other)
  end

  def <=>(other)
    @days <=> other.days
  end

  def ==(other)
    other.is_a?(Date) && @days == other.days
  end

  def eql?(other)
    self == other
  end

  def hash
    @days.hash
  end

  def <(other)
    @days < other.days
  end

  def <=(other)
    @days <= other.days
  end

  def >(other)
    @days > other.days
  end

  def >=(other)
    @days >= other.days
  end
end

# Spinel's builtin Range holds scalar endpoints. Keep date intervals as
# date values, including the inclusive/exclusive and open-ended cases.
class DateRange
  def initialize(first, last, exclusive = false)
    @first = first
    @last = last
    @exclusive = exclusive
  end

  def begin
    @first
  end

  def end
    @last
  end

  def exclude_end?
    @exclusive
  end

  def cover?(date)
    (@first.nil? || date >= @first) && (@last.nil? || (@exclusive ? date < @last : date <= @last))
  end
end

module ActiveSupport
  def self.to_date(time)
    Date.from_time(time)
  end

  def self.parse_db_date(value)
    return nil if value.nil? || value.empty?
    Date.iso8601(value[0, 10])
  end
end
