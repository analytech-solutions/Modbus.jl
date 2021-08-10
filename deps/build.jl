using BinDeps

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
					`./configure --prefix=$(BinDeps.usrdir(modbus)) CFLAGS='-Wno-nullability-completeness' CXXFLAGS='-Wno-nullability-completeness'`
					`make install`
				end),
			)
		end)
	end),
	modbus,
)

BinDeps.@install Dict(:modbus => :_modbus)
