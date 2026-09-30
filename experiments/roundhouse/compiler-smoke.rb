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
puts 'Compiler compatibility smoke passed'
