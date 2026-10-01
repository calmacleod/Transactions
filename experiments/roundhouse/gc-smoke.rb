# A String parameter lent from a stack local is then captured and written.
# An unrelated heap cell with the same name must not make it a GC object.
def append(out, values)
  writer = proc { |value| out << value.to_s }
  values.each { |value| writer.call(value) }
end

def heap_cell
  out = +''
  writer = proc { |value| out << value.to_s }
  writer.call('heap')
  out
end

def render
  out = +''
  append(out, [1, 2, 3])
  out
end

1000.times do
  raise 'wrong output' unless render == '123'
  raise 'wrong heap capture' unless heap_cell == 'heap'
end
puts 'Borrowed String capture and independent heap cell: passed'
