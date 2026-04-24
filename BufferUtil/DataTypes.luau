--!native
--!optimize 2
--!strict

local create = buffer.create
local copy = buffer.copy

local readu8 = buffer.readu8
local writef32 = buffer.writef32
local writeu16 = buffer.writeu16
local readf32 = buffer.readf32
local readu16 = buffer.readu16

local PI = math.pi
local TAU = math.tau

local MAX_U16 = 65535
local MAX_BUFFER_SIZE = 1000000 -- max for sized buffer

local quantize_angle = function(rad: number): number
	local a = rad % TAU
	if a > PI then a = a - TAU end

	return math.floor((a + PI) / TAU * MAX_U16 + 0.5)
end

local unquantize_angle = function(output: number): number
	return (output / 0xFFFF) * TAU - PI
end

local data_types = {}

-- im lazy and i think others are no less, so i code this func to avoid calc size manually
local CalcSize = function(type: keyof<typeof(data_types)>, value: any)
	local buf = create(MAX_BUFFER_SIZE)
	local size = 0

	copy(buf, 0, data_types[type].Write(buf, 0, value), 0)

	for i = 0, MAX_BUFFER_SIZE - 1 do
		size += readu8(buf, i) > 0 and 1 or 0
	end

	return size
end

-- 12 bytes (3 float32)
data_types.Vector3 = {
	Write = function(buf: buffer, offset: number, value: Vector3): buffer
		buf = buf or create(CalcSize(typeof(value), value))

		writef32(buf, offset, value.X)
		writef32(buf, offset + 4, value.Y)
		writef32(buf, offset + 8, value.Z)

		return buf
	end,
	
	Read = function(buf: buffer, offset: number): Vector3
		return Vector3.new(readf32(buf, offset), readf32(buf, offset + 4), readf32(buf, offset + 8))
	end,
}

-- 18 bytes (Vector3 - 12 bytes, 3 unsigned16 - 6 bytes)
data_types.CFrame = {
	Write = function(buf: buffer, offset: number, value: CFrame): buffer
		buf = buf or create(CalcSize(typeof(value), value))

		local x, y, z = value:ToEulerAnglesXYZ()

		writef32(buf, offset, value.X)
		writef32(buf, offset + 4, value.Y)
		writef32(buf, offset + 8, value.Z)
		writeu16(buf, offset + 12, quantize_angle(x))
		writeu16(buf, offset + 14, quantize_angle(y))
		writeu16(buf, offset + 16, quantize_angle(z))

		return buf
	end,
	
	Read = function(buf: buffer, offset: number): CFrame
		local cframe = CFrame.new(readf32(buf, offset), readf32(buf, offset + 4), readf32(buf, offset + 8))
		local angles = CFrame.fromEulerAnglesXYZ(unquantize_angle(readu16(buf, offset + 12)), unquantize_angle(readu16(buf, offset + 14)), unquantize_angle(readu16(buf, offset + 16)))

		return cframe * angles
	end,
}

return data_types
