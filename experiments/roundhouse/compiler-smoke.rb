stamp = Time.at(1_500.125)
read_time = -> { stamp.to_f }
raise 'initial time capture' unless read_time.call == 1_500.125
stamp = Time.at(2_000.5)
raise 'reassigned time capture' unless read_time.call == 2_000.5
read_object = -> { stamp }
raise 'time object return' unless read_object.call.to_f == 2_000.5

class CompilerSmoke
  def self.lend(text)
    yield text
  end

  def self.rescue_slot
    text = 'hello'.dup
    begin
      text = 'changed'.dup
      lend(text) { |value| value << ' world' }
      raise 'exercise rescue'
    rescue RuntimeError
      raise 'rescued string slot' unless text == 'changed world'
    end
    text
  end

  def self.grouped
    { groups: ['alpha', 'beta', 'alpha'].group_by { |value| value }.transform_values { |items| items.length } }
  end
end
raise 'volatile string lending' unless CompilerSmoke.rescue_slot == 'changed world'
raise 'string keyed group inside symbol keyed return' unless CompilerSmoke.grouped[:groups] == { 'alpha' => 2, 'beta' => 1 }
# A user-owned formatter must not suppress the boxed builtin Time arm.
class CompilerDateLike
  def strftime(pattern)
    pattern == '%Y' ? 'calendar' : 'other'
  end
end
formatters = [CompilerDateLike.new, Time.at(0).utc]
raise 'mixed object and Time formatting' unless formatters.map { |value| value.strftime('%Y') } == ['calendar', '1970']

# Force a boxed receiver and a generated merge expression beyond 600 bytes.
require 'json'
boxed_hash = JSON.parse('{"source":1}')
merged = boxed_hash.merge(
  entry_00: "value-00",
  entry_01: "value-01",
  entry_02: "value-02",
  entry_03: "value-03",
  entry_04: "value-04",
  entry_05: "value-05",
  entry_06: "value-06",
  entry_07: "value-07",
  entry_08: "value-08",
  entry_09: "value-09",
  entry_10: "value-10",
  entry_11: "value-11",
  entry_12: "value-12",
  entry_13: "value-13",
  entry_14: "value-14",
  entry_15: "value-15",
  entry_16: "value-16",
  entry_17: "value-17",
  entry_18: "value-18",
  entry_19: "value-19",
  entry_20: "value-20",
  entry_21: "value-21",
  entry_22: "value-22",
  entry_23: "value-23",
  entry_24: "value-24",
  entry_25: "value-25",
  entry_26: "value-26",
  entry_27: "value-27",
  entry_28: "value-28",
  entry_29: "value-29",
  entry_30: "value-30",
  entry_31: "value-31",
  entry_32: "value-32",
  entry_33: "value-33",
  entry_34: "value-34",
  entry_35: "value-35"
)
raise 'long hash merge expression truncated' unless merged[:entry_35] == 'value-35' && merged['source'] == 1

# A nullable Integer reader widens this result slot to a boxed value.
class CompilerDayFactory
  attr_reader :day

  def initialize(day = nil)
    @day = day
  end

  def self.day(value)
    new(value)
  end
end
class CompilerAccessorReader
  def self.read(value)
    value.day
  end
end
readers = [CompilerDayFactory.new, CompilerDayFactory.new(17), Time.utc(2024, 2, 29)]
raise 'mixed nullable Integer and Time day accessor' unless readers.map { |value| CompilerAccessorReader.read(value) } == [nil, 17, 29]

puts 'Compiler compatibility smoke passed'
