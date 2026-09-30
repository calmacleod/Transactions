require_relative 'compat/unicode'
raise 'accent' unless NativeUnicode.nfkd('Café') == "Cafe\u0301"
raise 'compatibility decomposition' unless NativeUnicode.nfkd('ﬁＡ①') == 'fiA1'
raise 'canonical ordering' unless NativeUnicode.nfkd("a\u0301\u0327") == "a\u0327\u0301"
previous = NativeUnicode.nfkd('Café')
NativeUnicode.nfkd('１２３４５６７８９')
raise 'returned string storage' unless previous == "Cafe\u0301"
puts 'Native Unicode smoke passed'
