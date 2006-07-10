require 'rubygems'
Gem::manage_gems
require 'rake/gempackagetask'

PKG_NAME = %q{ftpfxp}
PKG_VERSION = %q{0.0.1}

spec = Gem::Specification.new do |s|
	s.platform = Gem::Platform::RUBY
	s.summary = %q{Extension to Net::FTP providing FXP and SSL/TLS support}
	s.name = PKG_NAME
	s.authors = %q{Alex Lee}
	s.email = %q{alexeen@gmail.com}
	s.homepage = %q{http//ftpfxp.rubyforge.org/}
	s.rubyforge_project = PKG_NAME
	s.version = PKG_VERSION
	s.require_path = 'lib'
	s.autorequire = PKG_NAME
	s.files = FileList['lib/*.rb', 'lib/*/*.rb', 'samples/*.rb'].to_a
	s.extra_rdoc_files = ['README', 'LICENSE.txt', 'COPYING.txt']
end
