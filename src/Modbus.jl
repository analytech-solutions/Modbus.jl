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
	
	
	export LibModbus
	
	
end
