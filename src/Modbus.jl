module Modbus
	module libmodbus
		using CBinding
		
		let
			incdir = joinpath(dirname(@__DIR__), "deps/usr/include/modbus")
			libdir = joinpath(dirname(@__DIR__), "deps/usr/lib")
			
			c`-I$(incdir) -fparse-all-comments -L$(libdir) -lmodbus`
		end
		
		const c"struct timeval" = Cvoid
		const c"int8_t"  = Int8
		const c"int16_t" = Int16
		const c"int32_t" = Int32
		const c"int64_t" = Int64
		const c"uint8_t"  = UInt8
		const c"uint16_t" = UInt16
		const c"uint32_t" = UInt32
		const c"uint64_t" = UInt64
		
		c"""
			#include <modbus.h>
			#include <modbus-rtu.h>
			#include <modbus-tcp.h>
		"""ji
	end
	
	
	using .libmodbus
	using Sockets
	
	export ModbusDevice, ModbusRef
	
	
	abstract type ModbusKind end
	struct TCP <: ModbusKind end
	
	mutable struct ModbusDevice
		ptr::Ptr{modbus_t}
		kind::ModbusKind
		
		function ModbusDevice(ptr::Ptr{modbus_t}, kind::ModbusKind)
			mb = new(ptr, kind)
			finalizer(mb) do x
				ptr == C_NULL || close(x)
			end
			return mb
		end
	end
	
	function ModbusDevice(addr::IPAddr, port::Integer)
		ptr = modbus_new_tcp(string(addr), port)
		systemerror("modbus_new_tcp", ptr == C_NULL)
		systemerror("modbus_connect", modbus_connect(ptr) != 0)
		return ModbusDevice(ptr, TCP())
	end
	
	function Base.close(mb::ModbusDevice)
		modbus_close(mb.ptr)
		modbus_free(mb.ptr)
		mb.ptr = C_NULL
	end
	
	
	
	struct ModbusRef{T}
		mb::ModbusDevice
		addr::Int
		count::Int
		words::Vector{UInt16}
		
		ModbusRef{T}(mb::ModbusDevice, addr::Int, count::Int = 1, numwords::Int = 2) where {T} = new{T}(mb, addr, count, zeros(UInt16, numwords*count))
	end
	
	Base.length(ref::ModbusRef) = ref.count
	Base.size(ref::ModbusRef) = (ref.count,)
	Base.eltype(ref::ModbusRef{T}) where {T} = T
	Base.iterate(ref::ModbusRef, state = 1) = state > length(ref) ? nothing : (ref[state], state+1)
	
	function Base.read(ref::ModbusRef)
		# TODO: break up reads into pages (limited number of words can be read at a time)
		systemerror("modbus_read_registers", modbus_read_registers(ref.mb.ptr, ref.addr, length(ref.words), ref.words) != length(ref.words))
	end
	
	function Base.fetch(ref::ModbusRef, ind::Int = 1)
		val = UInt32(ref.words[(ind-1)*2 + 1]) | (UInt32(ref.words[(ind-1)*2 + 2]) << 16)
		val = eltype(ref) <: AbstractFloat ?
			reinterpret(Float32, val) :
			eltype(ref) <: Signed ?
				reinterpret(Int32, val) :
				eltype(ref) <: Bool ?
					(val != 0) :
					val
		return eltype(ref)(val)
	end
	
	function Base.write(ref::ModbusRef, val, ind::Int = 1)
		val = convert(eltype(ref), val)
		val = eltype(ref) <: AbstractFloat ?
			Float32(val) :
			eltype(ref) <: Signed ?
				Int32(val) :
				eltype(ref) <: Bool ?
					(val ? ~zero(UInt32) : zero(UInt32)) :
					UInt32(val)
		val = reinterpret(UInt32, val)
		ref.words[(ind-1)*2 + 1] = val & 0xffff
		ref.words[(ind-1)*2 + 2] = (val >> 16) & 0xffff
	end
	
	function Base.flush(ref::ModbusRef)
		# TODO: break up writes into pages (limited number of words can be written at a time)
		systemerror("modbus_write_registers", modbus_write_registers(ref.mb.ptr, ref.addr, length(ref.words), ref.words) != length(ref.words))
	end
	
	function Base.getindex(ref::ModbusRef, ind::Int = 1)
		read(ref)
		return fetch(ref, ind)
	end
	
	function Base.setindex!(ref::ModbusRef, val, ind::Int = 1)
		write(ref, val, ind)
		flush(ref)
	end
end
