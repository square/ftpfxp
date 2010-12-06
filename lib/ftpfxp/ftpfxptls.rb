#
#	= ftpfxptlx.rb - FXP with SSL/TLS enhancements to the basic FTP Client Library.
#
#	Written by Alex Lee <alexeen@gmail.com>.
#
#	This library is distributed under the terms of the Ruby license.
#	You can freely distribute/modify this library.
#
require 'socket'
require 'openssl'
require 'ftpfxp'

module Net
	# :stopdoc:
	class FTPFXPTLSError < FTPFXPError; end
	class FTPFXPTLSSrcSiteError < FTPFXPTLSError; end
	class FTPFXPTLSDstSiteError < FTPFXPTLSError; end
	# :startdoc:

	#
	# This class implements the File Transfer Protocol with
	# SSL/TLS secure connections. This class makes secure
	# file transfers extremely easy yet also provides the
	# low level control for users who wish to do things their
	# own ways.
	#
	# == Major Methods
	#
	# - #login
	# - #fxpprotp
	# - #fxpprotc
	# - #fxpgetcpsvport
	# - #ftpccc
	# - #fxpsscnon
	# - #fxpsscnoff
	# - #fxpto
	# - #fxpsscnto
	#
	class FTPFXPTLS < FTPFXP
		include OpenSSL

		# When +true+, transfers are performed securely. Default: +true+.
		attr_reader :secure_on
		attr_accessor :client_cert
		attr_accessor :client_key

		#
		# A synonym for <tt>FTPFXPTLS.new</tt>. but with a manditory host parameter.
		#
		# If a block is given, it is passed the +FTP+ object, which will be closed
		# when the block finishes, or when an exception is raised.
		#
		def FTPFXPTLS.open(host, user = nil, passwd = nil, mode = 0, acct = nil)
			ftpfxptls = new(host)
			if user
				ftpfxptls.login(user, passwd, mode, acct)
			end
			if block_given?
				begin
					yield ftpfxptls
				ensure
					ftpfxptls.close
				end
			else
				ftpfxptls
			end
		end

		#
		# This method authenticates a user with the ftp server connection.
		# If no +username+ given, defaults to +anonymous+.
		# If no +mode+ given, defaults to +TLS AUTH+.
		# - mode = 0 for +TLS+ (default)
		# - mode = 1 for +SSL+
		#
		def login(user = "anonymous", passwd = nil, mode = 0, acct = nil)
			# SSL/TLS context.
			ctx = create_ssl_context()
			if 1 == mode
				voidcmd('AUTH SSL')
			else
				voidcmd('AUTH TLS')
			end
			@sock = OpenSSL::SSL::SSLSocket.new(@sock, ctx)
			@sock.connect

			print "get: #{@sock.peer_cert.to_text}" if @debug_mode

			# Call the original login method.
			super(user, passwd, acct)

			# Protection buffer size must be set to 0 since FTP-TLS does
			# not require this, but it still must be set.
			fxppbsz(0)

			# Set to P since we're using TLS.
			fxpprotp
			@secure_on = true
		end

		# :stopdoc:
		#
		# Notes of support of each command extension.
		# Servers known to support SSCN:
		#	glftpd, surgeftp, Gene6, RaidenFTPD, Serv-U
		# Servers known to support CPSV
		#	glftpd, surgeftp, vsftpd, ioftpd, RaidenFTPd, and most others ...
		#	Note: Serv-U does not support CPSV.
		#
		# :startdoc:

		#
		# This method sets the +protection buffer size+.
		# Usually this is set to 0 for SSL/TLS transfers.
		#
		def fxppbsz(size)
			synchronize do
				putline("PBSZ #{size}")
				return getresp
			end
		end

		#
		# This method notifies the server to start using protection mode.
		# Must issue this command on both control connections
		# before +CPSV+ or +SSCN+ when preparing secure FXP.
		# Both servers will attempt to initiate SSL/TLS handshake
		# regardless if it is Active or Passive mode.
		#
		def fxpprotp
			synchronize do
				# PROT P - Private - Integrity and Privacy
				# PROT E - Confidential - Privacy without Integrity
				# PROT S - Safe - Integrity without Privacy
				# PROT C - Clear - Neither Integrity nor Privacy
				# For TLS, the data connection can only be C or P.
				putline('PROT P')
				return getresp
			end
		end

		#
		# Issue this command on the server will set the data
		# connection to +unencrypted mode+ and no SSL/TLS handshake
		# will be initiated for subsequent transfers.
		#
		def fxpprotc
			synchronize do
				putline('PROT C')
				return getresp
			end
		end

		#
		# This is the exact same command as PASV, except it requires the
		# control connection to be in protected mode (PROT P) and it tells
		# the server NOT to initiate the SSL/TLS handshake. The other
		# side of CPSV is a PROT P and PORT command, which tells the server
		# to do as usual and initiate SSL/TLS handshake.
		# Server must support CPSV FTP extension protocol
		# command. Most advance FTP servers implements CPSV.
		#
		def fxpgetcpsvport
			synchronize do
				putline('CPSV')
				return getresp
			end
		end

		#
		# This executes the +CCC+ (Clear Command Channel) command.
		# Though the server may not allow this command because
		# there are security issues with this.
		#
		def ftpccc
			synchronize do
				putline('CCC')
				@secure_on = false
				return getresp
			end
		end

		#
		# Toggle the +SSCN+ mode to on for this server. SSCN
		# requires that protected mode must be turned on
		# (ie. PROT P). If SSCN is on, it tells the server
		# to act in client mode for SSL/TLS handshakes.
		# Server must support the SSCN FTP extension protocol
		# command.
		#
		def fxpsscnon
			synchronize do
				putline('SSCN ON')
				return getresp
			end
		end

		#
		# Toggle the +SSCN+ mode to off for this server. If
		# SSCN is off, it tells the server to act in server
		# mode (default) for SSL/TLS handshakes.
		# Server must support the SSCN FTP extension protocol
		# command.
		#
		def fxpsscnoff
			synchronize do
				putline('SSCN OFF')
				return getresp
			end
		end

		#
    # This +FXP+ the specified source path to the destination path
    # on the destination site. Path names should be for files only.
		# <em>Do not call this method if you're using SSCN.</em>
		# This method uses +CPSV+. This raises an exception
		# <tt>FTPFXPTLSSrcSiteError</tt> if errored on source site and
		# raises an exception <tt>FTPFXPTLSDstSiteError</tt> if errored
		# on destination site.
		#
		def fxpto(dst, dstpath, srcpath)
			if not @secure_on
				fxpprotp
				@secure_on = true
			end

			pline = fxpgetcpsvport
			comp = pline.split(/\s+/)
			ports = String.new(comp[4].gsub('(', '').gsub(')', ''))
			dst.fxpsetport(ports)
			dst.fxpstor(dstpath)
			fxpretr(srcpath)
			resp = {}
			resp[:srcresp] = fxpwait
			raise FTPFXPTLSSrcSiteError unless '226' == resp[:srcresp][0,3]
			resp[:dstresp] = dst.fxpwait
			raise FTPFXPTLSDstSiteError unless '226' == resp[:dstresp][0,3]
			return resp
		end

		#
    # This +FXP+ the specified source path to the destination path
    # on the destination site. Path names should be for files only.
		# <em>Do not call this method if you're using CPSV.</em>
		# This method uses +SSCN+.
		#
		def fxpsscnto(dst, dstpath, srcpath)
			if not @secure_on
				fxpprotp
				@secure_on = true
			end

			fxpsscnoff # We are the server side.
			dst.fxpsscnon # They are the client side.
			pline = fxpgetpasvport
			comp = pline.split(/\s+/)
			ports = String.new(comp[4].gsub('(', '').gsub(')', ''))
			dst.fxpsetport(ports)
			dst.fxpstor(dstpath)
			fxpretr(srcpath)
			resp = {}
			resp[:srcresp] = fxpwait
			raise FTPFXPTLSSrcSiteError unless '226' == resp[:srcresp][0,3]
			resp[:dstresp] = dst.fxpwait
			raise FTPFXPTLSDstSiteError unless '226' == resp[:dstresp][0,3]
			return resp
		end

		#
		# Override the transfercmd to support SSL sockets.
		#
		def transfercmd(cmd, rest_offset = nil)
			if @passive
				host, port = makepasv

				if @secure_on
					ctx = create_ssl_context()

					# A secure data connection is required.
					conn = OpenSSL::SSL::SSLSocket.new(open_socket(host, port), ctx)
				else
					conn = open_socket(host, port)
				end

				# Sets the point where a file transfer should start.
				if @resume and rest_offset
					resp = sendcmd("REST " + rest_offset.to_s) 
					if resp[0] != ?3
						raise FTPReplyError, resp
					end
				end
				resp = sendcmd(cmd)
				if resp[0] != ?1
					raise FTPReplyError, resp
				end

				# Establish connection on secure socket.
				conn.connect
			else
				sock = makeport
				if @resume and rest_offset
					resp = sendcmd("REST " + rest_offset.to_s) 
					if resp[0] != ?3
						raise FTPReplyError, resp
					end
				end
				resp = sendcmd(cmd)
				if resp[0] != ?1
					raise FTPReplyError, resp
				end

				if @secure_on
					ctx = create_ssl_context()

					# Secure server connection required.
					sslsock = OpenSSL::SSL::SSLSocket.new(sock, ctx)
					# Accept the connection.
					conn = sslsock.accept

					# These listening sockets are no longer required.
					sslsock.close
				else
					conn = sock.accept
				end

				sock.close
			end
			return conn
		end
		private :transfercmd

		def create_ssl_context
			ctx = OpenSSL::SSL::SSLContext.new
			ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
			ctx.key = instance_variable_defined?(:@client_key) ? @client_key : nil
			ctx.cert = instance_variable_defined?(:@client_cert) ? @client_cert : nil
			ctx
		end
	end
end

