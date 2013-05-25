Gem::Specification.new do |s|
  s.name = "defunc"
  s.version = '1.0.0'
  s.summary = "Defunc traces your method calls and logs them to an IO stream"
  s.author = "Matthias Geier"
  s.homepage = "https://github.com/matthias-geier/defunc"
  s.require_path = 'lib'
  s.files = Dir['lib/*.rb']
  s.required_ruby_version = '>= 1.9.1'
end
