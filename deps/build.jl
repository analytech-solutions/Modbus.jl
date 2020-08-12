using BinDeps
using CBindingGen

BinDeps.@setup

version = get(ENV, "LIBMODBUS_VERSION",  "3.0.8")

modbus = library_dependency("libmodbus", aliases = ["modbus"])

srcdir = joinpath(BinDeps.srcdir(modbus), "libmodbus-$(version)")
lib = joinpath(BinDeps.libdir(modbus), Sys.isapple() ? "libmodbus.dylib" : "libmodbus.so")

rm(BinDeps.srcdir(modbus); force = true, recursive = true)
rm(BinDeps.usrdir(modbus); force = true, recursive = true)

provides(
	Sources,
	URI("https://github.com/stephane/libmodbus/archive/v$(version).tar.gz"),
	modbus,
	unpacked_dir = srcdir,
)

provides(
	BuildProcess,
	@build_steps(begin
		GetSources(modbus)
		@build_steps(begin
			ChangeDirectory(srcdir)
			FileRule(
				lib,
				@build_steps(begin
					`./autogen.sh`
					`./configure --prefix=$(BinDeps.usrdir(modbus))`
					`make install`
				end),
			)
		end)
	end),
	modbus,
)

BinDeps.@install Dict(:modbus => :_modbus)

incdir = joinpath(Sys.iswindows() ? bindir : BinDeps.includedir(modbus), "modbus")
cvts = convert_header("modbus.h", args = ["-I", incdir, "-fparse-all-comments"]) do cursor
	header = CodeLocation(cursor).file
	name   = string(cursor)
	
	# only wrap the libmodbus headers
	startswith(header, "$(incdir)/") || return false
	
	return true
end

open(joinpath(@__DIR__, "libmodbus.jl"), "w+") do io
	generate(io, lib => cvts)
end
