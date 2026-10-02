require 'json'

# This class also serves as the input to the emitted native rescue probe.
class RescueSmoke
  def self.missing_file(path)
    File.read(path)
    false
  rescue Errno::ENOENT
    true
  end

  def self.malformed_json(text)
    JSON.parse(text)
    false
  rescue JSON::ParserError
    true
  end

  def self.unrelated_error
    raise RuntimeError, 'unrelated error'
  rescue Errno::ENOENT, JSON::ParserError
    false
  end
end

# Emitted smoke entrypoint
raise 'missing file rescue did not match' unless RescueSmoke.missing_file('/nonexistent/roundhouse-rescue-smoke/merchant-catalog.json')
raise 'malformed JSON rescue did not match' unless RescueSmoke.malformed_json('{bad}')
raise 'valid JSON was treated as malformed' if RescueSmoke.malformed_json('{"merchants":[]}')
unrelated_escaped = false
begin
  RescueSmoke.unrelated_error
rescue RuntimeError => error
  unrelated_escaped = error.message == 'unrelated error'
end
raise 'unrelated exception was swallowed' unless unrelated_escaped
puts 'Native rescue contracts passed'
