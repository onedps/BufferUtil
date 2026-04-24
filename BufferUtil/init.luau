--!native
--!optimize 2
--!strict

--[[ 
Some items in buffer_util may be confusing due to different code styles, 
but this is necessary for optimization and code simplification.
]]

-- TOO MUCH TRASH!!!

local create = buffer.create
local buf_len = buffer.len
local copy = buffer.copy

local writestring = buffer.writestring
local readstring = buffer.readstring
local fromstring = buffer.fromstring

local writeu8 = buffer.writeu8
local writeu16 = buffer.writeu16
local writef64 = buffer.writef64
local writef32 = buffer.writef32

local readu8 = buffer.readu8
local readu16 = buffer.readu16
local readf64 = buffer.readf64
local readf32 = buffer.readf32

local SIZE_8 = 1
local SIZE_16 = 2
local SIZE_32 = 4
local SIZE_64 = 8
local MAX_BUFFER_SIZE = 1000000 -- max for sized buffer

local data_types = require("@self/DataTypes")

local buffer_util = {}
buffer_util = setmetatable(buffer_util, {__index = data_types})

local GetIdx = function(type: keyof<typeof(buffer_util)>)
	local idx = 0

	for k,v in pairs(buffer_util) do
		if k == type then return idx end
		idx += 1
	end

	return 0
end

local GetTypeByIdx = function(idx: number)
	for k,v in pairs(buffer_util) do
		if GetIdx(k) == idx then return k end
	end

	return 0
end

-- im lazy and i think others are no less, so i code this func to avoid calc size manually
local CalcSize = function(type: keyof<typeof(buffer_util)>, value: any)
	local buf = create(MAX_BUFFER_SIZE)
	local size = 0

	copy(buf, 0, buffer_util[type].Write(buf, 0, value), 0)

	for i = 0, MAX_BUFFER_SIZE - 1 do
		size += readu8(buf, i) > 0 and 1 or 0
	end

	return size
end

-- #tbl throw error or 0 with only index tbl (maps)
local GetTableLenght = function(tbl: {[any]: any})
	local len = 0

	for k,v in tbl do
		len += 1
	end

	return len
end

buffer_util.Resize = function(self, buf: buffer, size: number)
	assert(buf_len(buf) < size, "buf size cannot be less than size")

	local new = create(size)
	buffer.copy(new, 0, buf)

	return new
end

buffer_util.number = {
	Write = function(buf: buffer, offset: number, value: number): buffer
		buf = buf or create(SIZE_32)
		writef32(buf, offset, value)

		return buf
	end,
	
	Read = function(buf: buffer, offset: number): number
		return readf32(buf, offset)
	end,
}

buffer_util.Double = {
	Write = function(buf: buffer, offset: number, value: number): buffer
		buf = buf or create(SIZE_64)
		writef64(buf, offset, value)

		return buf
	end,
	
	Read = function(buf: buffer, offset: number): number
		return readf64(buf, offset)
	end,
}

buffer_util.boolean = {
	Write = function(buf: buffer, offset: number, value: boolean): buffer
		buf = buf or create(SIZE_8)
		writeu8(buf, offset, value and 1 or 0)

		return buf
	end,
	
	Read = function(buf: buffer, offset: number): boolean
		return readu8(buf, offset) == 1 and true or false
	end,
}

buffer_util.string = {
	Write = function(buf: buffer, offset: number, value: string): buffer
		if buf == buf then writestring(buf, offset, value) else buf = fromstring(value) end

		return buf
	end,
	
	Read = function(buf: buffer, offset: number, count: number): string
		return readstring(buf, offset, count)
	end,
}

buffer_util.table = {
    Write = function(buf: buffer, offset: number, value: {[any]: any})
		local value_type = typeof(value)
		buf = buf or create(CalcSize(value_type, value))

		-- testing writer/reader prototype (1. Read u8 at offset. 2. Get type by index in u8 and read type to offset + 1)
		writeu8(buf, offset, GetIdx(value_type))
		offset += 1

        for k,v in value do
			local of_k, of_v = typeof(k), typeof(v)

			writeu8(buf, offset, GetIdx(of_k))
			offset += 1

			buffer_util[of_k].Write(buf, offset, k)
			offset += CalcSize(of_k, k)

			writeu8(buf, offset, GetIdx(of_v))
			offset += 1

			buffer_util[of_v].Write(buf, offset, v)
			offset += CalcSize(of_v, v)
		end
    end,

    Read = function(buf: buffer, offset: number)
        local tbl = {}

		for i = offset, buf_len(buf) do
			for k = 0, 4 - 1 do

			end
			local type_k = GetTypeByIdx(readu8(buf, offset + i))
			buffer_util[type_k].Read(buf, offset + i + 1)

			local type_v = GetTypeByIdx(readu8(buf, offset + i + CalcSize(typeof(buffer_util[type_k]))))
			buffer_util[type_v].Read(buf, offset + i + 3)
		end
    end,
}

return buffer_util