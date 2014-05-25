#
# = ftpfxp.rb - FXP enhancements to the basic FTP Client Library.
#
# Written by Alex Lee <alexeen@gmail.com>.
#
# This library is distributed under the terms of the Ruby license.
# You can freely distribute/modify this library.
#
require 'net/ftp'

module Net

	# :stopdoc:
	class FTPFXPError < FTPError; end
	class FTPFXPSrcSiteError < FTPFXPError; end
	class FTPFXPDstSiteError < FTPFXPError; end
	# :startdoc:

  #
  # This class implements the File Transfer Protocol with
  # FXP Server-to-Server transfer. This class makes FXP
  # file transfers extremely easy yet also provides the
  # low level control for users who wish to do things their
  # own ways.
  #
  # == Major Methods
  #
  # - #feat
  # - #xdupe
  # - #fxpgetpasvport
	# - #fxpsetport
	# - #fxpstor
	# - #fxpretr
	# - #fxpwait
	# - #fxpto
	# - #fastlist
	# - #file_exists
	# - #path_exists
  #
	class FTPFXP < FTP
		#
		# Issue the +FEAT+ command to dump a list of FTP extensions supported
		# by this FTP server. Please note that this list is based on what
		# the server wants to return.
		#
		def feat
			synchronize do
				putline('FEAT')
				return getresp
			end
		end

		#
		# Sets the <tt>extended dupe checking mode</tt> on the ftp server.
		# If no mode specified, it returns the current mode.
		# mode=0 : Disables the extended dupe checking mode.
		# mode=1 : X-DUPE replies several file names per line.
		# mode=2 : Server replies with one file name per X-DUPE line.
		# mode=3 : Server replies with one filename per X-DUPE line with no truncation.
		# mode=4 : All files listed in one long line up to max 1024 characters.
		# For details, visit <em>http://www.smartftp.com/Products/SmartFTP/RFC/x-dupe-info.txt</em>
		#
		def xdupe(mode=nil)
			synchronize do
				if mode.nil?
					putline('SITE XDUPE')
					return getresp
				else
					putline("SITE XDUPE #{mode.to_i}")
					return getresp
				end
			end
		end

		#
		# Returns the +passive+ port values on this ftp server.
		#
		def fxpgetpasvport
			synchronize do
				# Get the passive IP and port values for next transfer.
				putline('PASV')
				return getresp
			end
		end

		#
		# Sets the +IP+ and +port+ for next transfer on this ftp server.
		#
		def fxpsetport(ipnport)
			synchronize do
				putline("PORT #{ipnport}")
				return getresp
			end
		end

		#
		# This is called on the destination side of the FXP.
		# This should be called before +fxpretr+.
		#
		def fxpstor(file)
			synchronize do
				voidcmd('TYPE I')
				putline("STOR #{file}")
				return getresp
			end
		end

		#
		# This is called on the source side of the FXP.
		# This should be called after +fxpstor+.
		#
		def fxpretr(file)
			synchronize do
				voidcmd('TYPE I')
				putline("RETR #{file}")
				return getresp
			end
		end

		#
		# This waits for the FXP to finish on the current ftp server.
		# If this is the source, it should return 226 Transfer Complete,
		# on success. If this is the destination, it should return
		# 226 File receive OK.
		#
		def fxpwait
			synchronize do
				return getresp
			end
		end

		#
		# This FXP the specified source path to the destination path
		# on the destination site. Path names should be for files only.
		# This raises an exception <tt>FTPFXPSrcSiteError</tt> if errored
		# on source site and raises an exception <tt>FTPFXPDstSiteError</tt>
		# if errored on destination site.
		#
		def fxpto(dst, dstpath, srcpath)
			pline = fxpgetpasvport
			comp = pline.split(/\s+/)
			ports = String.new(comp[4].gsub('(', '').gsub(')', ''))
			dst.fxpsetport(ports)
			dst.fxpstor(dstpath)
			fxpretr(srcpath)
			resp = {}
			resp[:srcresp] = fxpwait
			raise FTPFXPSrcSiteError unless '226' == resp[:srcresp][0,3]
			resp[:dstresp] = dst.fxpwait
			raise FTPFXPDstSiteError unless '226' == resp[:dstresp][0,3]
			return resp
		end

		#
		# This is a faster implementation of LIST where we use +STAT -l+
		# on supported servers. (All latest versions of ftp servers should
		# support this!) The path argument is optional, but it will call
		# +STAT -l+ on the path if it is specified.
		#
		def fastlist(path = nil)
			synchronize do
				if path.nil?
				  putline('STAT -l')
				else
				  putline("STAT -l #{path}")
				end
				return getresp
			end
		end

		#
		# Check if a file path exists.
		#
		def file_exists(path)
			resp = fastlist(path)
			status = false
			resp.each do |entry|
				next if '213' == entry[0,3] # Skip these useless lines.
				status = true if '-rw' == entry[0,3]
			end
			return status
		end

		#
		# Check if a path exists.
		#
		def path_exists(path)
			resp = fastlist(path)
			status = false
			resp.each do |entry|
				next if '213' == entry[0,3] # Skip these useless lines.
				status = true
			end
			return status
		end
	end
end

