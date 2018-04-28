require File.expand_path('../lib/breezy/version', __FILE__)

Gem::Specification.new do |s|
  s.name     = 'breezy'
  s.version  = Breezy::VERSION
  s.author   = 'Johny Ho'
  s.email    = 'jho406@gmail.com'
  s.license  = 'MIT'
  s.homepage = 'https://github.com/jho406/breezy/'
  s.summary  = 'Rails integration for BreezyJS'
  s.description = s.summary
  s.files    =   Dir['MIT-LICENSE', 'README.md', 'lib/**/*', 'app/**/*']
  s.test_files = Dir["test/*"]

  s.add_dependency 'actionpack', '>= 5.0'
  s.add_dependency 'breezy_template', '~> 0.4'
  s.add_dependency 'webpacker', '~> 3.0'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'sqlite3'
end
