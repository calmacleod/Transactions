require 'bigdecimal'
raise 'half up cents' unless (BigDecimal('12.345') * 100).round == 1235
raise 'negative cents' unless (BigDecimal('-12.345') * 100).round == -1235
raise 'decimal fixed string' unless (BigDecimal('1235') / 100).round(2).to_s('F') == '12.35'
raise 'carry rounding' unless BigDecimal('9.995').round(2).to_s('F') == '10.0'
raise 'fraction rounding' unless BigDecimal('0.009').round(2).to_s('F') == '0.01'
raise 'tiny fraction rounding' unless BigDecimal('0.0001').round(2).to_s('F') == '0.0'
raise 'whole number rounding' unless BigDecimal('150').round(-2) == 200
puts 'Native decimal contracts passed'
