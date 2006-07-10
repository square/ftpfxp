#!/usr/bin/env ruby
require 'rubygems'
require_gem 'ftpfxp'

class TestClass
	def initialize
		@conn1 = Net::FTPFXPTLS.new
		@conn1.passive = true
		@conn1.debug_mode = true
		@conn1.connect('192.168.0.1', 21)
		@conn1.login('myuser1', 'mypass1')

		@conn2 = Net::FTPFXPTLS.new
		@conn2.passive = true
		@conn2.debug_mode = true
		@conn2.connect('192.168.0.2', 21)
		@conn2.login('myuser2', 'mypass2')
	end

	def fxp
		@conn1.fxpto(@conn2, '/dstpath/myfile.tar.bz2', '/srcpath/myfile.tar.bz2')
	end

	def close
		@conn1.close
		@conn2.close
	end
end

testrun = TestClass.new
testrun.fxp
testrun.close
