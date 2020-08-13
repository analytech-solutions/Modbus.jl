module Modbus
	baremodule LibModbus
		using CBinding: 𝐣𝐥
		
		const int8_t  = 𝐣𝐥.Int8
		const int16_t = 𝐣𝐥.Int16
		const int32_t = 𝐣𝐥.Int32
		const int64_t = 𝐣𝐥.Int64
		const uint8_t  = 𝐣𝐥.UInt8
		const uint16_t = 𝐣𝐥.UInt16
		const uint32_t = 𝐣𝐥.UInt32
		const uint64_t = 𝐣𝐥.UInt64
		
		𝐣𝐥.Base.include(𝐣𝐥.@__MODULE__, 𝐣𝐥.joinpath(𝐣𝐥.dirname(𝐣𝐥.@__DIR__), "deps", "libmodbus.jl"))
	end
	
	
	using Sockets
	
	export LibModbus, ModbusDevice, ModbusRef
	
	
	abstract type ModbusKind end
	struct TCP <: ModbusKind end
	
	mutable struct ModbusDevice
		ptr::Ptr{LibModbus.modbus_t}
		kind::ModbusKind
		
		function ModbusDevice(ptr::Ptr{LibModbus.modbus_t}, kind::ModbusKind)
			mb = new(ptr, kind)
			finalizer(mb) do x
				LibModbus.modbus_close(x.ptr)
				LibModbus.modbus_free(x.ptr)
			end
			return mb
		end
	end
	
	function ModbusDevice(addr::IPAddr, port::Integer)
		ptr = LibModbus.modbus_new_tcp(string(addr), port)
		systemerror("modbus_new_tcp", ptr == C_NULL)
		systemerror("modbus_connect", LibModbus.modbus_connect(ptr) != 0)
		return ModbusDevice(ptr, TCP())
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
		systemerror("modbus_read_registers", LibModbus.modbus_read_registers(ref.mb.ptr, ref.addr, length(ref.words), ref.words) != length(ref.words))
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
		systemerror("modbus_write_registers", LibModbus.modbus_write_registers(ref.mb.ptr, ref.addr, length(ref.words), ref.words) != length(ref.words))
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
