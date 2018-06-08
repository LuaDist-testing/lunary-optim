local _M = {}
local _NAME = ... or 'test'

local _G = require '_G'

local libbit,libstruct
if _VERSION=="Lua 5.2" then
	pcall(function() libbit = require 'bit32' end)
else
	pcall(function() libbit = require 'bit' end)
end
pcall(function() libstruct = require 'struct' end)

if _NAME=='test' then
	_M.util = require("serial.util")
else
	_M.util = require(_NAME..".util")
end

--============================================================================

-- log facilities

_M.verbose = false

local function warning(message, level)
	if not level then
		level = 1
	end
	if _M.verbose then
		print(debug.traceback("warning: "..message, level+1))
	end
end

-- debug facilities

local err_stack = {}
local function push(...)
	local t = {...}
	for i=1,select('#', ...) do t[i] = tostring(t[i]) end
	err_stack[#err_stack+1] = table.concat(t, " ")
end
local function pop()
	err_stack[#err_stack] = nil
end
local function stackstr()
	local t = {}
	for i=#err_stack,1,-1 do
		t[#t+1] = err_stack[i]
	end
	return "in "..table.concat(t, "\nin ")
end
local function ioerror(msg)
	local t = {}
	for i=#err_stack,1,-1 do
		t[#t+1] = err_stack[i]
	end
	local str = "io error:\n\t"..stackstr():gsub("\n", "\n\t").."\nwith message: "..msg
	err_stack = {}
	return str
end
local function eoferror()
	err_stack = {}
	return "end of stream"
end
local _error = error
local function error(msg, level)
	local t = {}
	for i=#err_stack,1,-1 do
		t[#t+1] = err_stack[i]
	end
	return _error(msg.."\nlunary traceback:\n\tin "..table.concat(t, "\n\tin "), level and level + 1 or 2)
end
local function assert(...)
	local argc = select('#', ...)
	if argc==0 then
		error("bad argument #1 to 'assert' (value expected)", 2)
	elseif not ... then
		if argc==1 then
			error("assertion failed!", 2)
		else
			local msg = select(2, ...)
			local t = type(msg)
			if t=='string' or t=='number' then
				error(msg, 2)
			else
				error("bad argument #2 to 'assert' (string expected, got "..t..")", 2)
			end
		end
	else
		return ...
	end
end

-- portable pack/unpack

local pack,unpack
if _VERSION=="Lua 5.1" then
	pack = function(...) return {n=select('#', ...), ...} end
	unpack = _G.unpack
elseif _VERSION=="Lua 5.2" then
	pack = table.pack
	unpack = table.unpack
else
	error("unsupported Lua version")
end

-- stream reading helpers

local function getbytes(stream, nbytes)
	local data,err = stream:getbytes(nbytes)
	if data==nil then return nil,ioerror(err) end
	if #data < nbytes then return nil,eoferror() end
	return data
end

local function putbytes(stream, data)
	local success,err = stream:putbytes(data)
	if not success then return nil,ioerror(err) end
	return true
end

local function getbits(stream, nbits)
	local data,err = stream:getbits(nbits)
	if data==nil then return nil,ioerror(err) end
	if #data < nbits then return nil,eoferror() end
	return data
end

local function putbits(stream, data)
	local success,err = stream:putbits(data)
	if not success then return nil,ioerror(err) end
	return true
end

--============================================================================

-- function read.typename(stream, typeparams...) return value end
-- function write.typename(stream, value, typeparams...) return true end
-- function serialize.typename(value, typeparams...) return string end

local read_mt = {}
local write_mt = {}
local serialize_mt = {}

_M.read = setmetatable({}, read_mt)
_M.write = setmetatable({}, write_mt)
_M.serialize = setmetatable({}, serialize_mt)

_M.struct = {}
_M.fstruct = {}
_M.alias = {}

------------------------------------------------------------------------------

function read_mt:__call(stream, typename, ...)
	local read = assert(_M.read[typename], "no type named "..tostring(typename))
	return read(stream, ...)
end

function read_mt:__index(k)
	local struct = _M.struct[k]
	if struct then
		local read = function(stream)
			push('read', 'struct', k)
			local value,err = _M.read._struct(stream, struct)
			if value==nil then return nil,err end
			pop()
			return value
		end
		self[k] = read
		return read
	end
	local fstruct = _M.fstruct[k]
	if fstruct then
		local read = function(stream, ...)
			return _M.read.fstruct(stream, fstruct, ...)
		end
		self[k] = read
		return read
	end
	local alias = _M.alias[k]
	if alias then
		local read
		local t = type(alias)
		if t=='function' then
			read = function(stream, ...)
				push('read', 'alias', k)
				local value,err = _M.read(stream, alias(...))
				if value==nil and err~=nil then return nil,err end
				pop()
				return value
			end
		elseif t=='string' then
			read = function(stream, ...)
				push('read', 'alias', k)
				local value,err = _M.read(stream, alias)
				if value==nil and err~=nil then return nil,err end
				pop()
				return value
			end
		elseif t=='table' then
			read = function(stream, ...)
				push('read', 'alias', k)
				local value,err = _M.read(stream, unpack(alias))
				if value==nil and err~=nil then return nil,err end
				pop()
				return value
			end
		end
		if read then
			self[k] = read
			return read
		end
	end
end

------------------------------------------------------------------------------

function write_mt:__call(stream, value, typename, ...)
	local write = assert(_M.write[typename], "no type named "..tostring(typename))
	return write(stream, value, ...)
end

function write_mt:__index(k)
	local struct = _M.struct[k]
	if struct then
		local write = function(stream, object)
			push('write', 'struct', k)
			local success,err = _M.write.struct(stream, object, struct)
			if not success then return nil,err end
			pop()
			return true
		end
		local wrapper = _M.util.wrap("write."..k, write)
		self[k] = wrapper
		return wrapper
	end
	local fstruct = _M.fstruct[k]
	if fstruct then
		local write = function(stream, object, ...)
			return select(1, _M.write.fstruct(stream, object, fstruct, ...))
		end
		local wrapper = _M.util.wrap("write."..k, write)
		self[k] = wrapper
		return wrapper
	end
	local alias = _M.alias[k]
	if alias then
		local write
		local t = type(alias)
		if t=='function' then
			write = function(stream, value, ...)
				push('write', 'alias', k)
				local success,err = _M.write(stream, value, alias(...))
				if not success then return nil,err end
				pop()
				return true
			end
		elseif t=='string' then
			write = function(stream, value, ...)
				push('write', 'alias', k)
				local success,err = _M.write(stream, value, alias)
				if not success then return nil,err end
				pop()
				return true
			end
		elseif t=='table' then
			write = function(stream, value, ...)
				push('write', 'alias', k)
				local success,err = _M.write(stream, value, unpack(alias))
				if not success then return nil,err end
				pop()
				return true
			end
		end
		if write then
			local wrapper = _M.util.wrap("write."..k, write)
			self[k] = wrapper
			return wrapper
		end
	end
	local serialize = rawget(_M.serialize, k)
	if serialize then
		local write = function(stream, ...)
			local data,err = serialize(...)
			if data==nil then return nil,err end
			local success,err = putbytes(stream, data)
			if not success then return nil,err end
			return true
		end
		self[k] = write
		return write
	end
end

------------------------------------------------------------------------------

function serialize_mt:__call(value, typename, ...)
	local serialize = assert(_M.serialize[typename], "no type named "..tostring(typename))
	return serialize(value, ...)
end

function serialize_mt:__index(k)
	local write = _M.write[k]
	if write then
		local serialize = function(...)
			local stream = _M.buffer()
			local success,err = write(stream, ...)
			if not success then
				return nil,err
			end
			-- :FIXME: deal with bits
			return stream.data
		end
		self[k] = serialize
		return serialize
	end
end

--============================================================================

function _M.read.uint(stream, nbits, endianness)
	push('read', 'uint')
	assert(nbits==1 or endianness=='le' or endianness=='be', "invalid endianness "..tostring(endianness))
	if nbits=='*' then
		assert(stream.bitlength, "infinite precision integers can only be read from streams with a length")
		nbits = stream:bitlength()
	end
	local data,err = getbits(stream, nbits)
	if data==nil then return nil,err end
	if #data < nbits then return nil,eoferror() end
	local bits = {string.byte(data, 1, #data)}
	local value = 0
	if nbits==1 then
		value = bits[1]
	elseif endianness=='le' then
		for i,bit in ipairs(bits) do
			value = value + bit * 2^(i-1)
		end
	elseif endianness=='be' then
		for i,bit in ipairs(bits) do
			value = value + bit * 2^(nbits-i)
		end
	end
	pop()
	return value
end

function _M.write.uint(stream, value, nbits, endianness)
	push('write', 'uint')
	assert(nbits==1 or endianness=='le' or endianness=='be', "invalid endianness "..tostring(endianness))
	assert(type(value)=='number', "value is not a number")
	assert(value==math.floor(value), "value is not an integer")
	assert(value < 2^nbits, "integer out of range")
	local bits = {}
	for i=nbits-1,0,-1 do
		local bit = 2^i
		if value >= bit then
			table.insert(bits, '\1')
			value = value - bit
		else
			table.insert(bits, '\0')
		end
	end
	bits = table.concat(bits)
	if endianness=='le' then
		bits = bits:reverse()
	end
	local success,err = putbits(stream, bits)
	if not success then return nil,err end
	pop()
	return true
end

function _M.serialize.uint(stream, value, nbits, endianness)
	push('serialize', 'uint')
	error("serialize not supported for uint")
	pop()
end

------------------------------------------------------------------------------

function _M.read.sint(stream, nbits, endianness)
	push('read', 'sint')
	local value,err = _M.read(stream, 'uint', nbits, endianness)
	if value==nil then return nil,err end
	if value >= 2^(nbits-1) then
		value = value - 2^nbits
	end
	pop()
	return value
end

function _M.write.sint(stream, value, nbits, endianness)
	push('write', 'sint')
	assert(value, math.floor(value), "value is not an integer")
	assert(-2^(nbits-1) <= value and value < 2^(nbits-1), "integer out of range")
	if value < 0 then
		value = value + 2^nbits
	end
	local success,err = _M.write(stream, value, 'uint', nbits, endianness)
	if not success then return nil,err end
	pop()
	return true
end

------------------------------------------------------------------------------

function _M.read.uint8(stream)
	push('read', 'uint8')
	local data,err = getbytes(stream, 1)
	if data==nil then return nil,err end
	pop()
	return string.byte(data)
end

function _M.write.uint8(stream, value)
	push('write', 'uint8')
	assert(type(value)=='number', "value is not a number")
	assert(value==math.floor(value), "value is not an integer")
	assert(value < 2^8, "integer out of range")
	local a = value
	if value < 0 or value >= 2^8 or math.floor(value)~=value then
		error("invalid value")
	end
	local data = string.char(a)
	local success,err = putbytes(stream, data)
	if not success then return nil,err end
	pop()
	return true
end

------------------------------------------------------------------------------

local function read_sint(nbits, sint, uint)
	return function(stream, ...)
		push('read', sint)
		local value,err = _M.read(stream, uint, ...)
		if value==nil then return nil,err end
		if value >= 2^(nbits-1) then
			value = value - 2^nbits
		end
		pop()
		return value
	end
end

local function write_sint(nbits, sint, uint)
	return function(stream, value, ...)
		push('write', sint)
		assert(value, math.floor(value), "value is not an integer")
		assert(-2^(nbits-1) <= value and value < 2^(nbits-1), "integer out of range")
		if value < 0 then
			value = value + 2^nbits
		end
		local success,err = _M.write(stream, value, uint, ...)
		if not success then return nil,err end
		pop()
		return true
	end
end

------------------------------------------------------------------------------

_M.read.sint8 = read_sint(8, 'sint8', 'uint8')
_M.write.sint8 = write_sint(8, 'sint8', 'uint8')

------------------------------------------------------------------------------

function _M.read.uint16(stream, endianness)
	push('read', 'uint16')
	local data,err = getbytes(stream, 2)
	if data==nil then return nil,err end
	local a,b
	if endianness=='le' then
		b,a = string.byte(data, 1, 2)
	elseif endianness=='be' then
		a,b = string.byte(data, 1, 2)
	else
		error("unknown endianness")
	end
	pop()
	return a * 256 + b
end

function _M.write.uint16(stream, value, endianness)
	push('write', 'uint16')
	assert(type(value)=='number', "value is not a number")
	assert(value==math.floor(value), "value is not an integer")
	assert(value < 2^16, "integer out of range")
	local b = value % 256
	value = (value - b) / 256
	local a = value % 256
	local data
	if endianness=='le' then
		data = string.char(b, a)
	elseif endianness=='be' then
		data = string.char(a, b)
	else
		error("unknown endianness")
	end
	local success,err = putbytes(stream, data)
	if not success then return nil,err end
	pop()
	return true
end

------------------------------------------------------------------------------

_M.read.sint16 = read_sint(16, 'sint16', 'uint16')
_M.write.sint16 = write_sint(16, 'sint16', 'uint16')

------------------------------------------------------------------------------

function _M.read.uint32(stream, endianness)
	push('read', 'uint32')
	local data,err = getbytes(stream, 4)
	if data==nil then return nil,err end
	local a,b,c,d
	if endianness=='le' then
		d,c,b,a = string.byte(data, 1, 4)
	elseif endianness=='be' then
		a,b,c,d = string.byte(data, 1, 4)
	else
		error("unknown endianness")
	end
	pop()
	return ((a * 256 + b) * 256 + c) * 256 + d
end

function _M.write.uint32(stream, value, endianness)
	push('write', 'uint32')
	assert(type(value)=='number', "value is not a number")
	assert(value==math.floor(value), "value is not an integer")
	assert(value < 2^32, "integer out of range")
	local d = value % 256
	value = (value - d) / 256
	local c = value % 256
	value = (value - c) / 256
	local b = value % 256
	value = (value - b) / 256
	local a = value % 256
	local data
	if endianness=='le' then
		data = string.char(d, c, b, a)
	elseif endianness=='be' then
		data = string.char(a, b, c, d)
	else
		error("unknown endianness")
	end
	local success,err = putbytes(stream, data)
	if not success then return nil,err end
	pop()
	return true
end

------------------------------------------------------------------------------

_M.read.sint32 = read_sint(32, 'sint32', 'uint32')
_M.write.sint32 = write_sint(32, 'sint32', 'uint32')

------------------------------------------------------------------------------

function _M.read.uint64(stream, endianness)
	push('read', 'uint64')
	-- read bytes
	local data,err = getbytes(stream, 8)
	if data==nil then return nil,err end
	-- convert to number
	local buffer = _M.buffer(data)
	local h,l
	if endianness=='le' then
		l,err = _M.read(buffer, 'uint32', 'le')
		if not l then return nil,err end
		h,err = _M.read(buffer, 'uint32', 'le')
		if not h then return nil,err end
	elseif endianness=='be' then
		h,err = _M.read(buffer, 'uint32', 'be')
		if not h then return nil,err end
		l,err = _M.read(buffer, 'uint32', 'be')
		if not l then return nil,err end
	else
		error("unknown endianness")
	end
	local value = h * 2^32 + l
	-- check that we didn't lose precision
	local l2 = value % 2^32
	local h2 = (value - l2) / 2^32
	if h2~=h or l2~=l then
		-- int64 as string is little-endian
		if endianness=='le' then
			value = data
		else
			value = data:reverse()
		end
	end
	pop()
	return value
end

function _M.write.uint64(stream, value, endianness)
	push('write', 'uint64')
	local tvalue = type(value)
	if tvalue=='number' then
		assert(value==math.floor(value), "value is not an integer")
		assert(value < 2^64, "integer out of range")
		local l = value % 2^32
		local h = (value - l) / 2^32
		local success,err
		if endianness=='le' then
			success,err = _M.write(stream, l, 'uint32', 'le')
			if not success then return nil,err end
			success,err = _M.write(stream, h, 'uint32', 'le')
			if not success then return nil,err end
		elseif endianness=='be' then
			success,err = _M.write(stream, h, 'uint32', 'be')
			if not success then return nil,err end
			success,err = _M.write(stream, l, 'uint32', 'be')
			if not success then return nil,err end
		else
			error("unknown endianness")
		end
	elseif tvalue=='string' then
		assert(#value==8)
		local data
		-- int64 as string is little-endian
		if endianness=='le' then
			data = value
		elseif endianness=='be' then
			data = value:reverse()
		else
			error("unknown endianness")
		end
		local success,err = putbytes(stream, data)
		if not success then return nil,err end
	else
		error("uint64 value must be a number or a string")
	end
	pop()
	return true
end

------------------------------------------------------------------------------

function _M.read.sint64(stream, endianness)
	push('read', 'sint64')
	-- read bytes
	local data,err = getbytes(stream, 8)
	if data==nil then return nil,err end
	-- convert to number
	local buffer = _M.buffer(data)
	local h,l
	if endianness=='le' then
		l,err = _M.read(buffer, 'uint32', 'le')
		if not l then return nil,err end
		h,err = _M.read(buffer, 'uint32', 'le')
		if not h then return nil,err end
	elseif endianness=='be' then
		h,err = _M.read(buffer, 'uint32', 'be')
		if not h then return nil,err end
		l,err = _M.read(buffer, 'uint32', 'be')
		if not l then return nil,err end
	else
		error("unknown endianness")
	end
	if h >= 2^31 then
		h = h - 2^32 + 1
		l = l - 2^32
	end
	local value = h * 2^32 + l
	-- check that we didn't lose precision
	local l2,h2
	if value < 0 then
		h2 = math.ceil(value / 2^32)
		l2 = value - h2 * 2^32
	else
		h2 = math.floor(value / 2^32)
		l2 = value - h2 * 2^32
	end
	if h2~=h or l2~=l then
		-- int64 as string is little-endian
		if endianness=='le' then
			value = data
		else
			value = data:reverse()
		end
	end
	pop()
	return value
end

function _M.write.sint64(stream, value, endianness)
	push('write', 'uint64')
	local tvalue = type(value)
	if tvalue=='number' then
		assert(value==math.floor(value), "value is not an integer")
		assert(-2^63 <= value and value < 2^63, "integer out of range")
		local l,h
		if value < 0 then
			h = math.ceil(value / 2^32)
			l = value - h * 2^32
			h = h + 2^32 - 1
			l = l + 2^32
		else
			h = math.floor(value / 2^32)
			l = value - h * 2^32
		end
		local success,err
		if endianness=='le' then
			success,err = _M.write(stream, l, 'uint32', 'le')
			if not success then return nil,err end
			success,err = _M.write(stream, h, 'uint32', 'le')
			if not success then return nil,err end
		elseif endianness=='be' then
			success,err = _M.write(stream, h, 'uint32', 'be')
			if not success then return nil,err end
			success,err = _M.write(stream, l, 'uint32', 'be')
			if not success then return nil,err end
		else
			error("unknown endianness")
		end
	elseif tvalue=='string' then
		assert(#value==8)
		local data
		-- int64 as string is little-endian
		if endianness=='le' then
			data = value
		elseif endianness=='be' then
			data = value:reverse()
		else
			error("unknown endianness")
		end
		local success,err = putbytes(stream, data)
		if not success then return nil,err end
	else
		error("uint64 value must be a number or a string")
	end
	pop()
	return true
end

------------------------------------------------------------------------------

function _M.read.enum(stream, enum, int_t, ...)
	push('read', 'enum')
	if type(int_t)~='table' or select('#', ...)>=1 then
		int_t = {int_t, ...}
	end
	local value,err = _M.read(stream, unpack(int_t))
	if value==nil then
		return nil,assert(err, "type '"..int_t[1].."' returned nil but no error")
	end
	local svalue = enum[value]
	if svalue==nil then
		warning("unknown enum number "..tostring(value)..(_M.util.enum_names[enum] and (" for enum "..tostring(enum)) or "")..", keeping numerical value")
		svalue = value
	end
	pop()
	return svalue
end

function _M.write.enum(stream, value, enum, int_t, ...)
	push('write', 'enum')
	if type(int_t)~='table' or select('#', ...)>=1 then
		int_t = {int_t, ...}
	end
	local ivalue
	if type(value)=='number' then
		ivalue = value
	else
		ivalue = enum[value]
	end
	assert(ivalue, "unknown enum string '"..tostring(value).."'")
	local success,err = _M.write(stream, ivalue, unpack(int_t))
	if not success then return nil,err end
	pop()
	return true
end

------------------------------------------------------------------------------

function _M.read.mapping(stream, mapping, value_t, ...)
	push('read', 'mapping')
	if type(value_t)~='table' or select('#', ...)>=1 then
		value_t = {value_t, ...}
	end
	local valuel,err = _M.read(stream, unpack(value_t))
	if valuel==nil and err==nil then return nil,err end
	local valueh = mapping[valuel]
	pop()
	return valueh
end

function _M.write.mapping(stream, valueh, mapping, value_t, ...)
	push('write', 'mapping')
	if type(value_t)~='table' or select('#', ...)>=1 then
		value_t = {value_t, ...}
	end
	local valuel = mapping[valueh]
	local success,err = _M.write(stream, valuel, unpack(value_t))
	if not success then return nil,err end
	pop()
	return true
end

------------------------------------------------------------------------------

if libbit then

function _M.read.flags(stream, flagset, int_t, ...)
	push('read', 'flags')
	if type(int_t)~='table' or select('#', ...)>=1 then
		int_t = {int_t, ...}
	end
	local int,err = _M.read(stream, unpack(int_t))
	if int==nil then return nil,err end
	local value = {}
	for k,v in pairs(flagset) do
		-- ignore reverse or invalid mappings (allows use of same dict in enums)
		if type(v)=='number' and libbit.band(int, v) ~= 0 then
			value[k] = true
		end
	end
	pop()
	return value
end

function _M.write.flags(stream, value, flagset, int_t, ...)
	push('write', 'flags')
	if type(int_t)~='table' or select('#', ...)>=1 then
		int_t = {int_t, ...}
	end
	local ints = {}
	for flag,k in pairs(value) do
		assert(k==true, "flag has value other than true ("..tostring(k)..")")
		ints[#ints+1] = flagset[flag]
	end
	if #ints==0 then
		value = 0
	else
		value = libbit.bor(unpack(ints))
	end
	local success,err = _M.write(stream, value, unpack(int_t))
	if not success then return nil,err end
	pop()
	return true
end

end

------------------------------------------------------------------------------

function _M.read.array(stream, size_t, value_t, ...)
	push('read', 'array')
	if type(value_t)~='table' or select('#', ...)>=1 then
		value_t = {value_t, ...}
	end
	
	-- determine size
	local size
	if size_t=='*' then
		size = '*'
	elseif type(size_t)=='number' then
		size = size_t
	elseif type(size_t)=='table' then
		-- read size
		local err
		size,err = _M.read(stream, unpack(size_t))
		if size==nil then return nil,err end
	else
		error("invalid size definition")
	end
	
	-- read value array
	local value = {}
	if size_t=='*' then
		assert(stream.bytelength, "infinite arrays can only be read from streams with a length")
		while stream:bytelength() > 0 do
			local elem,err = _M.read(stream, unpack(value_t))
			if elem==nil then return nil,err end
			value[#value+1] = elem
		end
	else
		for i=1,size do
			local elem,err = _M.read(stream, unpack(value_t))
			if elem==nil then return nil,err end
			value[i] = elem
		end
	end
	pop()
	return value
end

function _M.write.array(stream, value, size_t, value_t, ...)
	push('write', 'array')
	if type(value_t)~='table' or select('#', ...)>=1 then
		value_t = {value_t, ...}
	end
	
	-- determine size
	local size
	if size_t=='*' then
		size = #value
	elseif type(size_t)=='number' then
		size = size_t
	elseif type(size_t)=='table' then
		size = #value
	else
		error("invalid size definition")
	end
	assert(size == #value, "provided array size doesn't match")
	
	-- write size if necessary
	if type(size_t)=='table' then
		success,err = _M.write(stream, size, unpack(size_t))
		if not success then return nil,err end
	end
	
	-- write value array
	for i=1,size do
		local success,err = _M.write(stream, value[i], unpack(value_t))
		if not success then return nil,err end
	end
	pop()
	return true
end

------------------------------------------------------------------------------

_M.alias.sizedarray = function(...) return 'array', ... end

------------------------------------------------------------------------------

function _M.read.paddedvalue(stream, size_t, padding, value_t, ...)
	push('read', 'paddedvalue')
	if type(value_t)~='table' or select('#', ...)>=1 then
		value_t = {value_t, ...}
	end
	assert(type(size_t)=='number' or type(size_t)=='table', "size definition should be a number or a type definition array")
	assert(type(value_t)=='table', "value type definition should be an array")
	assert(value_t[1], "value type definition array is empty")
	
	-- read size
	local size,err
	if type(size_t)=='number' then
		size = size_t
	elseif size_t.included then
		size,err = _M.read(stream, unpack(size_t))
		local sdata = _M.serialize(size, unpack(size_t))
		if #sdata > size then
			return nil,ioerror("included size is too small to include itself")
		else
			size = size - #sdata
		end
	else
		size,err = _M.read(stream, unpack(size_t))
	end
	if size==nil then return nil,err end
	
	-- read serialized value
	local vdata,err
	if size > 0 then
		vdata,err = getbytes(stream, size)
		if vdata==nil then return nil,err end
	else
		vdata = ""
	end
	
	-- build a buffer stream
	local vbuffer = _M.buffer(vdata)
	
	-- read the value from the buffer
	local value,err = _M.read(vbuffer, unpack(value_t))
	if value==nil and err~=nil then return nil,err end
	
	-- if the buffer is not empty save trailing bytes or generate an error
	if vbuffer:bytelength() > 0 then
		local __trailing_bytes = vbuffer:getbytes(vbuffer:bytelength())
		if padding then
			-- remove padding
			if padding=='\0' then
				__trailing_bytes = __trailing_bytes:match("^(.-)%z*$")
			else
				__trailing_bytes = __trailing_bytes:match("^(.-)%"..padding.."*$")
			end
		end
		if #__trailing_bytes > 0 then
			local msg = "trailing bytes in sized value not read by value serializer "..tostring(value_t[1])..""
			if type(value)=='table' then
				warning(msg)
				value.__trailing_bytes = __trailing_bytes
			else
				error(msg)
			end
		end
	end
	pop()
	return value
end

function _M.write.paddedvalue(stream, value, size_t, padding, value_t, ...)
	push('write', 'paddedvalue')
	if type(value_t)~='table' or select('#', ...)>=1 then
		value_t = {value_t, ...}
	end
	-- get serialization functions
	local size_serialize
	if type(size_t)=='table' then
		assert(size_t[1], "size type definition array is empty")
		size_serialize = assert(_M.serialize[size_t[1]], "unknown size type "..tostring(size_t[1]).."")
	elseif type(size_t)=='number' then
		size_serialize = size_t
	else
		error("size_t should be a type definition array or a number")
	end
	assert(padding==nil or type(padding)=='string' and #padding==1, "padding should be nil or a single character")
	assert(type(value_t)=='table', "value type definition should be an array")
	assert(value_t[1], "value type definition array is empty")
	local value_serialize = assert(_M.serialize[value_t[1]], "unknown value type "..tostring(value_t[1]).."")
	-- serialize value
	local vdata,err = value_serialize(value, unpack(value_t, 2))
	if vdata==nil then return nil,err end
	-- if value has trailing bytes append them
	if type(value)=='table' and value.__trailing_bytes then
		vdata = vdata .. value.__trailing_bytes
	end
	local size = #vdata
	local sdata
	if type(size_serialize)=='number' then
		if padding then
			-- check we don't exceed the padded size
			assert(size<=size_serialize, "value size exceeds padded size")
			vdata = vdata .. string.rep(padding, size_serialize-size)
		else
			assert(size==size_serialize, "value size doesn't match sizedvalue size")
		end
	elseif size_t.included then
		local sdata1,err = size_serialize(size, unpack(size_t, 2))
		if sdata1==nil then return nil,err end
		local sdata2,err = size_serialize(size + #sdata1, unpack(size_t, 2))
		if sdata2==nil then return nil,err end
		if #sdata2 ~= #sdata1 then return nil,ioerror("included size has variable length") end
		sdata = sdata2
	else
		local sdata1,err = size_serialize(size, unpack(size_t, 2))
		if sdata1==nil then return nil,err end
		sdata = sdata1
	end
	if sdata then
		local success,err = putbytes(stream, sdata)
		if not success then return nil,err end
	end
	local success,err = putbytes(stream, vdata)
	if not success then return nil,err end
	pop()
	return true
end

------------------------------------------------------------------------------

function _M.read.sizedvalue(stream, size_t, value_t, ...)
	push('read', 'sizedvalue')
	local results = pack(_M.read.paddedvalue(stream, size_t, nil, value_t, ...))
	pop()
	return unpack(results, 1, results.n)
end

function _M.write.sizedvalue(stream, value, size_t, value_t, ...)
	push('write', 'sizedvalue')
	local success,err = _M.write.paddedvalue(stream, value, size_t, nil, value_t, ...)
	if not success then return nil,err end
	pop()
	return true
end

------------------------------------------------------------------------------

function _M.read.cstring(stream)
	push('read', 'cstring')
	local bytes = {}
	repeat
		local byte,err = _M.read.uint8(stream)
		if not byte then return nil,err end
		bytes[#bytes+1] = byte
	until byte==0
	pop()
	return string.char(unpack(bytes, 1, #bytes-1)) -- remove trailing 0
end

function _M.write.cstring(stream, value)
	push('write', 'cstring')
	assert(type(value)=='string', "value is not a string")
	assert(not value:find('\0'), "a C string cannot contain embedded zeros")
	local data = value..'\0'
	local success,err = putbytes(stream, data)
	if not success then return nil,err end
	pop()
	return true
end

------------------------------------------------------------------------------

if libstruct then

function _M.read.float(stream, endianness)
	push('read', 'float')
	local format
	if endianness=='le' then
		format = "<f"
	elseif endianness=='be' then
		format = ">f"
	else
		error("unknown endianness")
	end
	local data,err = getbytes(stream, 4)
	if data==nil then return nil,err end
	pop()
	return libstruct.unpack(format, data)
end

function _M.write.float(stream, value, endianness)
	push('write', 'float')
	local format
	if endianness=='le' then
		format = "<f"
	elseif endianness=='be' then
		format = ">f"
	else
		error("unknown endianness")
	end
	local data = libstruct.pack(format, value)
	if #data ~= 4 then
		error("struct library \"f\" format doesn't correspond to a 32 bits float")
	end
	local success,err = putbytes(stream, data)
	if not success then return nil,err end
	pop()
	return true
end

else

local function grab_byte(v)
	return math.floor(v / 256), string.char(math.floor(v) % 256)
end

local function s2f_le(x)
	local sign = 1
	local mantissa = string.byte(x, 3) % 128
	for i = 2, 1, -1 do mantissa = mantissa * 256 + string.byte(x, i) end
	if string.byte(x, 4) > 127 then sign = -1 end
	local exponent = (string.byte(x, 4) % 128) * 2 + math.floor(string.byte(x, 3) / 128)
	if exponent == 0 then return 0 end
	mantissa = (math.ldexp(mantissa, -23) + 1) * sign
	return math.ldexp(mantissa, exponent - 127)
end

local function s2f_be(x)
	return s2f_le(x:reverse())
end

local function f2s_le(x)
	local sign = 0
	if x < 0 then sign = 1; x = -x end
	local mantissa, exponent = math.frexp(x)
	if x == 0 then -- zero
		mantissa = 0; exponent = 0
	else
		mantissa = (mantissa * 2 - 1) * math.ldexp(0.5, 24)
		exponent = exponent + 126
	end
	local v, byte = "" -- convert to bytes
	x, byte = grab_byte(mantissa); v = v..byte -- 7:0
	x, byte = grab_byte(x); v = v..byte -- 15:8
	x, byte = grab_byte(exponent * 128 + x); v = v..byte -- 23:16
	x, byte = grab_byte(sign * 128 + x); v = v..byte -- 31:24
	return v
end

local function f2s_be(x)
	return f2s_le(x):reverse()
end

function _M.read.float(stream, endianness)
	push('read', 'float')
	local format
	if endianness=='le' then
		format = s2f_le
	elseif endianness=='be' then
		format = s2f_be
	else
		error("unknown endianness")
	end
	local data,err = getbytes(stream, 4)
	if data==nil then return nil,err end
	pop()
	return format(data)
end

function _M.write.float(stream, value, endianness)
	push('write', 'float')
	local format
	if endianness=='le' then
		format = f2s_le
	elseif endianness=='be' then
		format = f2s_be
	else
		error("unknown endianness")
	end
	local data = format(value)
	if #data ~= 4 then
		error("struct library \"f\" format doesn't correspond to a 32 bits float")
	end
	local success,err = putbytes(stream, data)
	if not success then return nil,err end
	pop()
	return true
end

end

------------------------------------------------------------------------------

if libstruct then

function _M.read.double(stream, endianness)
	push('read', 'double')
	local format
	if endianness=='le' then
		format = "<d"
	elseif endianness=='be' then
		format = ">d"
	else
		error("unknown endianness")
	end
	local data,err = getbytes(stream, 8)
	if data==nil then return nil,err end
	local value,err = libstruct.unpack(format, data)
	if not value then return nil,err end
	pop()
	return value
end

function _M.write.double(stream, value, endianness)
	push('write', 'double')
	local format
	if endianness=='le' then
		format = "<d"
	elseif endianness=='be' then
		format = ">d"
	else
		error("unknown endianness")
	end
	local data = libstruct.pack(format, value)
	if #data ~= 8 then
		error("struct library \"d\" format doesn't correspond to a 64 bits float")
	end
	local success,err = putbytes(stream, data)
	if not success then return nil,err end
	pop()
	return true
end

end

------------------------------------------------------------------------------

function _M.read.bytes(stream, size_t, ...)
	push('read', 'bytes')
	if size_t~='*' and type(size_t)~='number' and (type(size_t)~='table' or select('#', ...)>=1) then
		size_t = {size_t, ...}
	end
	
	-- determine size
	local size
	if size_t=='*' then
		size = '*'
	elseif type(size_t)=='number' then
		size = size_t
	elseif type(size_t)=='table' then
		-- read size
		local err
		size,err = _M.read(stream, unpack(size_t))
		if size==nil then return nil,err end
	else
		error("invalid size definition")
	end
	
	-- read value bytes
	if size=='*' then
		assert(stream.bytelength, "infinite byte sequences can only be read from streams with a length")
		size = stream:bytelength()
	end
	local data,err = getbytes(stream, size)
	if data==nil then return nil,err end
	pop()
	return data
end

function _M.write.bytes(stream, value, size_t, ...)
	push('write', 'bytes')
	if size_t~='*' and type(size_t)~='number' and (type(size_t)~='table' or select('#', ...)>=1) then
		size_t = {size_t, ...}
	end
	assert(type(value)=='string', "bytes value is not a string")
	
	-- determine size
	local size
	if size_t=='*' then
		size = #value
	elseif type(size_t)=='number' then
		size = size_t
	elseif type(size_t)=='table' then
		size = #value
	else
		error("invalid size definition")
	end
	assert(size == #value, "byte string has not the correct length ("..size.." expected, got "..#value..")")
	
	-- write size if necessary
	if type(size_t)=='table' then
		success,err = _M.write(stream, size, unpack(size_t))
		if not success then return nil,err end
	end
	
	-- write value array
	local success,err = putbytes(stream, value)
	if not success then return nil,err end
	pop()
	return true
end

------------------------------------------------------------------------------

_M.alias.char = {'bytes', 1}

------------------------------------------------------------------------------

_M.alias.sizedbuffer = function(...) return 'bytes', ... end

------------------------------------------------------------------------------

function _M.read.hex(stream, bytes_t, ...)
	push('read', 'hex')
	if type(bytes_t)~='table' then
		bytes_t = {bytes_t, ...}
	end
	local bytes,err = _M.read(stream, unpack(bytes_t))
	if bytes==nil then return nil,err end
	local value = _M.util.bin2hex(bytes)
	pop()
	return value
end

function _M.write.hex(stream, value, bytes_t, ...)
	push('write', 'hex')
	if type(bytes_t)~='table' then
		bytes_t = {bytes_t, ...}
	end
	assert(type(value)=='string', "hex value is not a string")
	local bytes = _M.util.hex2bin(value)
	local success,err = _M.write(stream, bytes, unpack(bytes_t))
	if not success then return nil,err end
	pop()
	return true
end

------------------------------------------------------------------------------

_M.alias.bytes2hex = function(count)
	return 'hex', 'bytes', count
end

------------------------------------------------------------------------------

function _M.read.base32(stream, bytes_t, ...)
	push('read', 'base32')
	if type(bytes_t)~='table' then
		bytes_t = {bytes_t, ...}
	end
	local bytes,err = _M.read(stream, unpack(bytes_t))
	if bytes==nil then return nil,err end
	local value = _M.util.bin2base32(bytes)
	pop()
	return value
end

function _M.write.base32(stream, value, bytes_t, ...)
	push('write', 'base32')
	if type(bytes_t)~='table' then
		bytes_t = {bytes_t, ...}
	end
	assert(type(value)=='string', "base32 value is not a string")
	local bytes = _M.util.base322bin(value)
	local success,err = _M.write(stream, bytes, unpack(bytes_t))
	if value==nil then return nil,err end
	pop()
	return value
end

------------------------------------------------------------------------------

_M.alias.bytes2base32 = function(count)
	return 'base32', 'bytes', count
end

------------------------------------------------------------------------------

function _M.read.boolean(stream, int_t, ...)
	push('read', 'boolean')
	if type(int_t)~='table' or select('#', ...)>=1 then
		int_t = {int_t, ...}
	end
	local int,err = _M.read(stream, unpack(int_t))
	if int==nil then return nil,err end
	local value
	if int==0 then
		value = false
	elseif int==1 then
		value = true
	else
		warning("boolean value is not 0 or 1, it's "..tostring(int))
		value = int
	end
	pop()
	return value
end

function _M.write.boolean(stream, value, int_t, ...)
	push('write', 'boolean')
	if type(int_t)~='table' or select('#', ...)>=1 then
		int_t = {int_t, ...}
	end
	local int
	if type(value)=='boolean' then
		int = value and 1 or 0
	else
		int = value
	end
	local data,err = _M.write(stream, int, unpack(int_t))
	if data==nil then return nil,err end
	pop()
	return data
end

------------------------------------------------------------------------------

_M.alias.boolean8 = {'boolean', 'uint8'}

------------------------------------------------------------------------------

function _M.read.truenil(stream, int_t, ...)
	push('read', 'truenil')
	if type(int_t)~='table' or select('#', ...)>=1 then
		int_t = {int_t, ...}
	end
	local int,err = _M.read(stream, unpack(int_t))
	if int==nil then return nil,err end
	local value
	if int==0 then
		value = nil
	elseif int==1 then
		value = true
	else
		warning("truenil value is not 0 or 1, it's "..tostring(int))
		value = int
	end
	pop()
	return value
end

function _M.write.truenil(stream, value, int_t, ...)
	push('write', 'truenil')
	if type(int_t)~='table' or select('#', ...)>=1 then
		int_t = {int_t, ...}
	end
	local int
	if type(value)=='boolean' or value==nil then
		int = value and 1 or 0
	else
		int = value
	end
	local data,err = _M.write(stream, int, unpack(int_t))
	if data==nil then return nil,err end
	pop()
	return data
end

------------------------------------------------------------------------------

function _M.read._struct(stream, fields)
	local object = {}
	for _,field in ipairs(fields) do
		local key = field[1]
		push('read', 'field', key)
		local tk = type(key)
		assert(tk=='nil' or tk=='boolean' or tk=='number' or tk=='string', "only interned value types can be used as struct key")
		local value,err = _M.read(stream, select(2, unpack(field)))
		if value==nil and err~=nil then return nil,err end
		object[key] = value
		pop()
	end
	return object
end

function _M.read.struct(stream, fields)
	push('read', 'struct')
	local value,err = _M.read._struct(stream, fields)
	if value==nil then return nil,err end
	pop()
	return value
end

function _M.write._struct(stream, value, fields)
	for _,field in ipairs(fields) do
		local key = field[1]
		push('write', 'field', key)
		local tk = type(key)
		assert(tk=='nil' or tk=='boolean' or tk=='number' or tk=='string', "only interned value types can be used as struct key")
		local success,err = _M.write(stream, value[key], select(2, unpack(field)))
		if not success then return nil,err end
		pop()
	end
	return true
end

function _M.write.struct(stream, value, fields)
	push('write', 'struct')
	local success,err = _M.write._struct(stream, value, fields)
	if not success then return nil,err end
	pop()
	return true
end

------------------------------------------------------------------------------

local cyield = coroutine.yield
local cwrap,unpack = coroutine.wrap,unpack
local token = {}

function _M.read.fstruct(stream, f, ...)
	push('read', 'fstruct')
	local params = {n=select('#', ...), ...}
	local object = {}
	local wrapper = setmetatable({}, {
		__index = object,
		__newindex = object,
		__call = function(self, field, ...)
			if select('#', ...)>0 then
				push('read', 'field', field)
				local type = ...
				local read = _M.read[type]
				if not read then error("no function to read field of type "..tostring(type)) end
				local value,err = read(stream, select(2, ...))
				if value==nil and err~=nil then
					cyield(token, nil, err)
				end
				object[field] = value
				pop()
			else
				return --[[_M.util.wrap("field "..field, ]]function(type, ...)
					push('read', 'field', field)
					local read = _M.read[type]
					if not read then error("no function to read field of type "..tostring(type)) end
					local value,err = read(stream, ...)
					if value==nil and err~=nil then
						cyield(token, nil, assert(err, "type '"..type.."' returned nil, but no error"))
					end
					object[field] = value
					pop()
				end--[[)]]
			end
		end,
	})
	local coro = cwrap(function()
		f(wrapper, wrapper, unpack(params, 1, params.n))
		return token, true
	end)
	local results = pack(coro())
	while results[1]~=token do
		results = pack(coro(cyield(unpack(results, 1, results.n))))
	end
	local success,err = unpack(results, 2)
	if not success then return nil,err end
	pop()
	return object
end

function _M.write.fstruct(stream, object, f, ...)
	push('write', 'fstruct')
	local params = {n=select('#', ...), ...}
	local wrapper = setmetatable({}, {
		__index = object,
		__newindex = object,
		__call = function(self, field, ...)
			if select('#', ...)>0 then
				push('write', 'field', field)
				local type = ...
				local write = _M.write[type]
				if not write then error("no function to write field of type "..tostring(type)) end
				local success,err = write(stream, object[field], select(2, ...))
				if not success then
					cyield(token, nil, err)
				end
				pop()
			else
				return function(type, ...)
					push('write', 'field', field)
					local write = _M.write[type]
					if not write then error("no function to write field of type "..tostring(type)) end
					local success,err = write(stream, object[field], ...)
					if not success then
						cyield(token, nil, err)
					end
					pop()
				end
			end
		end,
	})
	local coro = cwrap(function()
		f(wrapper, wrapper, unpack(params, 1, params.n))
		return token, true
	end)
	local results = pack(coro())
	while results[1]~=token do
		results = pack(coro(cyield(unpack(results, 1, results.n))))
	end
	local success,err = unpack(results, 2)
	if not success then return nil,err end
	pop()
	return true
end

------------------------------------------------------------------------------

function _M.read.constant(stream, constant, value_t, ...)
	push('read', 'constant')
	if type(value_t)~='table' or select('#', ...)>=1 then
		value_t = {value_t, ...}
	end
	local value,err = _M.read(stream, unpack(value_t))
	if value==nil and err~=nil then return nil,err end
	if value~=constant then
		error("invalid constant value in stream ("..tostring(constant).." expected, got "..tostring(value)..")")
	end
	pop()
	return nil
end

function _M.write.constant(stream, value, constant, value_t, ...)
	push('write', 'constant')
	assert(value==nil, "constant should have a nil value")
	if type(value_t)~='table' or select('#', ...)>=1 then
		value_t = {value_t, ...}
	end
	local success,err = _M.write(stream, constant, unpack(value_t))
	if not success then return nil,err end
	pop()
	return true
end

------------------------------------------------------------------------------

function _M.read.taggedvalue(stream, tag_t, mapping, selector)
	push('read', 'taggedvalue')
	assert(type(tag_t)=='table', "tag type definition should be an array")
	assert(tag_t[1], "tag type definition array is empty")
	
	-- read tag
	local tag,err = _M.read(stream, unpack(tag_t))
	if tag==nil and err~=nil then return nil,err end
	
	-- get value serialization function
	assert(type(mapping)=='table', "mapping should be a table")
	local value_t = assert(mapping[tag], "no mapping for tag")
	assert(type(value_t)=='table', "value type definition should be an array")
	assert(value_t[1], "value type definition array is empty")
	
	-- read serialized value
	local value,err = _M.read(stream, unpack(value_t))
	if value==nil and err~=nil then return nil,err end
	if selector then
		assert(selector(value)==tag, "taggedvalue selector misbehaved when applied to a read value")
	else
		value = {
			tag = tag,
			value = value,
		}
	end
	pop()
	return value
end

function _M.write.taggedvalue(stream, value, tag_t, mapping, selector)
	push('write', 'taggedvalue')
	-- get tag
	local tag
	if selector then
		tag = selector(value)
	else
		tag = value.tag
		value = value.value
	end
	-- get serialization functions
	assert(type(tag_t)=='table', "tag type definition should be an array")
	assert(tag_t[1], "tag type definition array is empty")
	assert(type(mapping)=='table', "mapping should be a table")
	local value_t = assert(mapping[tag], "no mapping for tag")
	assert(type(value_t)=='table', "value type definition should be an array")
	assert(value_t[1], "value type definition array is empty")
	-- write tag and value
	local success,err = _M.write(stream, tag, unpack(tag_t))
	if not success then return nil,err end
	local success,err = _M.write(stream, value, unpack(value_t))
	if not success then return nil,err end
	pop()
	return true
end

------------------------------------------------------------------------------

function _M.read.empty(stream, value2)
	push('read', 'empty')
	-- simply return the predefined value
	pop()
	return value2
end

function _M.write.empty(stream, value, value2)
	push('write', 'empty')
	local t = type(value2)
	-- for non-referenced types, check that the value match
	if t=='nil' or t=='boolean' or t=='number' or t=='string' then
		assert(value==value2, "empty value doesn't match the type definition")
	end
	-- don't write anything in the stream
	pop()
	return true
end

--============================================================================

-- force function instantiation for all known types
for type in pairs(_M.serialize) do
	local _ = _M.write[type]
end
for type in pairs(_M.write) do
	local _ = _M.serialize[type]
end
for type in pairs(_M.struct) do
	local _ = _M.write[type] -- this forces write and serialize creation
	local _ = _M.read[type]
end

--============================================================================

local stream_methods = {}

if libbit then

local function B2b(bytes, endianness)
	assert(endianness=='le' or endianness=='be', "invalid endianness "..tostring(endianness))
	bytes = {string.byte(bytes, 1, #bytes)}
	local bits = {}
	for _,byte in ipairs(bytes) do
		if endianness=='le' then
			for i=0,7 do
				bits[#bits+1] = libbit.band(byte, 2^i) > 0 and 1 or 0
			end
		elseif endianness=='be' then
			for i=7,0,-1 do
				bits[#bits+1] = libbit.band(byte, 2^i) > 0 and 1 or 0
			end
		end
	end
	return string.char(unpack(bits))
end

local function b2B(bits, endianness)
	assert(endianness=='le' or endianness=='be', "invalid endianness "..tostring(endianness))
	bits = {string.byte(bits, 1, #bits)}
	local bytes = {}
	local nbytes = #bits / 8
	assert(nbytes==math.floor(nbytes))
	for B=0,nbytes-1 do
		local byte = 0
		if endianness=='le' then
			for b=0,7 do
				byte = byte + bits[B*8+b+1] * 2^b
			end
		elseif endianness=='be' then
			for b=0,7 do
				byte = byte + bits[B*8+b+1] * 2^(7-b)
			end
		end
		bytes[B+1] = byte
	end
	return string.char(unpack(bytes))
end

function stream_methods:getbits(nbits)
	local data = ""
	-- use remaining bits
	if #self.rbits > 0 then
		local a,b = self.rbits:sub(1, nbits),self.rbits:sub(nbits+1)
		data = data..a
		self.rbits = b
	end
	if #data < nbits then
		assert(#self.rbits==0)
		local nbytes = math.ceil((nbits - #data) / 8)
		local bytes = self:getbytes(nbytes)
		local bits = B2b(bytes, self.byte_endianness or 'le')
		local a,b = bits:sub(1, nbits-#data),bits:sub(nbits-#data+1)
		data = data..a
		self.rbits = b
	end
	return data
end

function stream_methods:putbits(data)
	-- append bits
	self.wbits = self.wbits..data
	-- send full bytes
	if #self.wbits >= 8 then
		local bits = self.wbits
		local nbytes = math.floor(#bits / 8)
		bits,self.wbits = bits:sub(1, nbytes * 8),bits:sub(nbytes * 8 + 1)
		local bytes = b2B(bits, self.byte_endianness or 'le')
		return self:putbytes(bytes)
	else
		return true
	end
end

function stream_methods:bitlength()
	return #self.rbits + self:bytelength() * 8
end

end

------------------------------------------------------------------------------

local buffer_methods = {}
local buffer_mt = {__index=buffer_methods}

function _M.buffer(data, byte_endianness)
	return setmetatable({data=data or "", rbits="", wbits="", byte_endianness=byte_endianness}, buffer_mt)
end

function buffer_methods:getbytes(nbytes)
	local result
	if nbytes >= #self.data then
		result,self.data = self.data,""
	else
		result,self.data = self.data:sub(1, nbytes),self.data:sub(nbytes+1)
	end
	return result
end

function buffer_methods:putbytes(data)
	self.data = self.data..data
	return #data
end

function buffer_methods:bytelength()
	return #self.data
end

buffer_methods.getbits = stream_methods.getbits
buffer_methods.putbits = stream_methods.putbits
buffer_methods.bitlength = stream_methods.bitlength

------------------------------------------------------------------------------

local filestream_methods = {}
local filestream_mt = {__index=filestream_methods}

function _M.filestream(file, byte_endianness)
	-- assume the passed object behaves like a file
--	if io.type(file)~='file' then
--		error("bad argument #1 to filestream (file expected, got "..(io.type(file) or type(file))..")", 2)
--	end
	return setmetatable({file=file, rbits="", wbits="", byte_endianness=byte_endianness}, filestream_mt)
end

function filestream_methods:getbytes(nbytes)
	assert(type(nbytes)=='number')
	local data = ""
	while #data < nbytes do
		local bytes,err = self.file:read(nbytes - #data)
		-- eof
		if bytes==nil and err==nil then break end
		-- error
		if not bytes then return nil,err end
		-- accumulate bytes
		data = data..bytes
	end
	return data
end

function filestream_methods:putbytes(data)
	local written,err = self.file:write(data)
	if not written then return nil,err end
	return true
end

function filestream_methods:bytelength()
	local cur = self.file:seek()
	local len = self.file:seek('end')
	self.file:seek('set', cur)
	return len - cur
end

filestream_methods.getbits = stream_methods.getbits
filestream_methods.putbits = stream_methods.putbits
filestream_methods.bitlength = stream_methods.bitlength

------------------------------------------------------------------------------

local tcpstream_methods = {}
local tcpstream_mt = {__index=tcpstream_methods}

function _M.tcpstream(socket, byte_endianness)
	-- assumes the passed object behaves like a luasocket TCP socket
--	if io.type(file)~='file' then
--		error("bad argument #1 to filestream (file expected, got "..(io.type(file) or type(file))..")", 2)
--	end
	return setmetatable({socket=socket, rbits="", wbits="", byte_endianness=byte_endianness}, tcpstream_mt)
end

function tcpstream_methods:getbytes(nbytes)
	assert(type(nbytes)=='number')
	local data = ""
	while #data < nbytes do
		local bytes,err = self.socket:receive(nbytes - #data)
		-- error
		if not bytes then return nil,err end
		-- eof
		if #bytes==0 then break end
		-- accumulate bytes
		data = data..bytes
	end
	return data
end

function tcpstream_methods:putbytes(data)
	assert(type(data)=='string')
	local total = 0
	local written,err = self.socket:send(data)
	while written and written < #data do
		total = total + written
		data = data:sub(#written + 1)
		written,err = self.socket:send(data)
	end
	if not written then return nil,err end
	return true
end

tcpstream_methods.getbits = stream_methods.getbits
tcpstream_methods.putbits = stream_methods.putbits
tcpstream_methods.bitlength = stream_methods.bitlength

------------------------------------------------------------------------------

local nbstream_methods = {}
local nbstream_mt = {__index=nbstream_methods}

function _M.nbstream(socket, byte_endianness)
	-- assumes the passed object behaves like a nb TCP socket
	return setmetatable({socket=socket, rbits="", wbits="", byte_endianness=byte_endianness}, nbstream_mt)
end

function nbstream_methods:getbytes(nbytes)
	assert(type(nbytes)=='number')
	local data = ""
	while #data < nbytes do
		local bytes,err = self.socket:read(nbytes - #data)
		-- error
		if not bytes and err=='aborted' then break end
		if not bytes then return nil,err end
		-- eof
		if #bytes==0 then break end
		-- accumulate bytes
		data = data..bytes
	end
	return data
end

function nbstream_methods:putbytes(data)
	assert(type(data)=='string')
	local total = 0
	local written,err = self.socket:write(data)
	while written and written < #data do
		total = total + written
		data = data:sub(#written + 1)
		written,err = self.socket:write(data)
	end
	if not written then return nil,err end
	return true
end

nbstream_methods.getbits = stream_methods.getbits
nbstream_methods.putbits = stream_methods.putbits
nbstream_methods.bitlength = stream_methods.bitlength

--============================================================================

if _NAME=='test' then

-- use random numbers to improve coverage without trying all values, but make
-- sure tests are repeatable
math.randomseed(0)

local function randombuffer(size)
	local t = {}
	for i=1,size do
		t[i] = math.random(0, 255)
	end
	return string.char(unpack(t))
end

local buffer = _M.buffer
local read = _M.read
local write = _M.write
local serialize = _M.serialize

local funcs = {}
local tested = {}
if arg and arg[0] then
	local file = assert(io.open(arg[0], "rb"))
	content = assert(file:read('*all'))
	assert(file:close())
	
	content = content:gsub('(--%[(=*)%[.-]%2])', function(str) return str:gsub('%S', ' ') end)
	content = content:gsub('%-%-.-\n', function(str) return str:gsub('%S', ' ') end)
	
	for push in content:gmatch('push%b()') do
		local args = {}
		local allstrings = true
		for arg in (push:sub(6, -2)..','):gmatch('%s*(.-)%s*,') do
			if not arg:match('^([\'"]).*%1$') then
				allstrings = false
				break
			end
			table.insert(args, arg:sub(2, -2))
		end
		if allstrings then
			table.insert(funcs, table.concat(args, " "))
		end
	end
	
	local _push = push
--	local _pop = pop
	
	function push(...)
		local t = {...}
		for i=1,select('#', ...) do t[i] = tostring(t[i]) end
		local str = table.concat(t, " ")
		tested[str] = true
		return _push(...)
	end
--	function pop(...)
--		return _pop(...)
--	end
end

-- uint8

assert(read(buffer("\042"), 'uint8')==42)
assert(read(buffer("\242"), 'uint8')==242)

assert(serialize(42, 'uint8')=="\042")
assert(serialize(242, 'uint8')=="\242")

-- sint8

assert(read(buffer("\042"), 'sint8')==42)
assert(read(buffer("\242"), 'sint8')==-14)

assert(serialize(42, 'sint8')=="\042")
assert(serialize(-14, 'sint8')=="\242")

-- uint16

assert(read(buffer("\037\042"), 'uint16', 'le')==10789)
assert(read(buffer("\237\042"), 'uint16', 'le')==10989)
assert(read(buffer("\037\242"), 'uint16', 'le')==61989)
assert(read(buffer("\237\242"), 'uint16', 'le')==62189)

assert(read(buffer("\037\042"), 'uint16', 'be')==9514)
assert(read(buffer("\237\042"), 'uint16', 'be')==60714)
assert(read(buffer("\037\242"), 'uint16', 'be')==9714)
assert(read(buffer("\237\242"), 'uint16', 'be')==60914)

assert(serialize(10789, 'uint16', 'le')=="\037\042")
assert(serialize(10989, 'uint16', 'le')=="\237\042")
assert(serialize(61989, 'uint16', 'le')=="\037\242")
assert(serialize(62189, 'uint16', 'le')=="\237\242")

assert(serialize(9514, 'uint16', 'be')=="\037\042")
assert(serialize(60714, 'uint16', 'be')=="\237\042")
assert(serialize(9714, 'uint16', 'be')=="\037\242")
assert(serialize(60914, 'uint16', 'be')=="\237\242")

-- sint16

assert(read(buffer("\037\042"), 'sint16', 'le')==10789)
assert(read(buffer("\237\042"), 'sint16', 'le')==10989)
assert(read(buffer("\037\242"), 'sint16', 'le')==-3547)
assert(read(buffer("\237\242"), 'sint16', 'le')==-3347)

assert(read(buffer("\037\042"), 'sint16', 'be')==9514)
assert(read(buffer("\237\042"), 'sint16', 'be')==-4822)
assert(read(buffer("\037\242"), 'sint16', 'be')==9714)
assert(read(buffer("\237\242"), 'sint16', 'be')==-4622)

assert(serialize(10789, 'sint16', 'le')=="\037\042")
assert(serialize(10989, 'sint16', 'le')=="\237\042")
assert(serialize(-3547, 'sint16', 'le')=="\037\242")
assert(serialize(-3347, 'sint16', 'le')=="\237\242")

assert(serialize(9514, 'sint16', 'be')=="\037\042")
assert(serialize(-4822, 'sint16', 'be')=="\237\042")
assert(serialize(9714, 'sint16', 'be')=="\037\242")
assert(serialize(-4622, 'sint16', 'be')=="\237\242")

-- uint32

assert(read(buffer("\037\000\000\042"), 'uint32', 'le')==704643109)
assert(read(buffer("\037\000\000\242"), 'uint32', 'le')==4060086309)
assert(read(buffer("\237\000\000\042"), 'uint32', 'le')==704643309)
assert(read(buffer("\237\000\000\242"), 'uint32', 'le')==4060086509)

assert(read(buffer("\037\000\000\042"), 'uint32', 'be')==620757034)
assert(read(buffer("\037\000\000\242"), 'uint32', 'be')==620757234)
assert(read(buffer("\237\000\000\042"), 'uint32', 'be')==3976200234)
assert(read(buffer("\237\000\000\242"), 'uint32', 'be')==3976200434)

assert(serialize(704643109, 'uint32', 'le')=="\037\000\000\042")
assert(serialize(4060086309, 'uint32', 'le')=="\037\000\000\242")
assert(serialize(704643309, 'uint32', 'le')=="\237\000\000\042")
assert(serialize(4060086509, 'uint32', 'le')=="\237\000\000\242")

assert(serialize(620757034, 'uint32', 'be')=="\037\000\000\042")
assert(serialize(620757234, 'uint32', 'be')=="\037\000\000\242")
assert(serialize(3976200234, 'uint32', 'be')=="\237\000\000\042")
assert(serialize(3976200434, 'uint32', 'be')=="\237\000\000\242")

-- sint32

assert(read(buffer("\037\000\000\042"), 'sint32', 'le')==704643109)
assert(read(buffer("\037\000\000\242"), 'sint32', 'le')==-234880987)
assert(read(buffer("\237\000\000\042"), 'sint32', 'le')==704643309)
assert(read(buffer("\237\000\000\242"), 'sint32', 'le')==-234880787)

assert(read(buffer("\037\000\000\042"), 'sint32', 'be')==620757034)
assert(read(buffer("\037\000\000\242"), 'sint32', 'be')==620757234)
assert(read(buffer("\237\000\000\042"), 'sint32', 'be')==-318767062)
assert(read(buffer("\237\000\000\242"), 'sint32', 'be')==-318766862)

assert(serialize(704643109, 'sint32', 'le')=="\037\000\000\042")
assert(serialize(-234880987, 'sint32', 'le')=="\037\000\000\242")
assert(serialize(704643309, 'sint32', 'le')=="\237\000\000\042")
assert(serialize(-234880787, 'sint32', 'le')=="\237\000\000\242")

assert(serialize(620757034, 'sint32', 'be')=="\037\000\000\042")
assert(serialize(620757234, 'sint32', 'be')=="\037\000\000\242")
assert(serialize(-318767062, 'sint32', 'be')=="\237\000\000\042")
assert(serialize(-318766862, 'sint32', 'be')=="\237\000\000\242")

-- uint64

assert(read(buffer("\000\000\000\000\037\000\000\042"), 'uint64', 'le')==2^32*704643109)
assert(read(buffer("\000\000\000\000\037\000\000\242"), 'uint64', 'le')==2^32*4060086309)
assert(read(buffer("\000\000\000\000\237\000\000\042"), 'uint64', 'le')==2^32*704643309)
assert(read(buffer("\000\000\000\000\237\000\000\242"), 'uint64', 'le')==2^32*4060086509)

assert(read(buffer("\000\000\000\000\037\000\000\042"), 'uint64', 'be')==620757034)
assert(read(buffer("\000\000\000\000\037\000\000\242"), 'uint64', 'be')==620757234)
assert(read(buffer("\000\000\000\000\237\000\000\042"), 'uint64', 'be')==3976200234)
assert(read(buffer("\000\000\000\000\237\000\000\242"), 'uint64', 'be')==3976200434)

assert(read(buffer("\037\000\000\042\000\000\000\000"), 'uint64', 'le')==704643109)
assert(read(buffer("\037\000\000\242\000\000\000\000"), 'uint64', 'le')==4060086309)
assert(read(buffer("\237\000\000\042\000\000\000\000"), 'uint64', 'le')==704643309)
assert(read(buffer("\237\000\000\242\000\000\000\000"), 'uint64', 'le')==4060086509)

assert(read(buffer("\037\000\000\042\000\000\000\000"), 'uint64', 'be')==2^32*620757034)
assert(read(buffer("\037\000\000\242\000\000\000\000"), 'uint64', 'be')==2^32*620757234)
assert(read(buffer("\237\000\000\042\000\000\000\000"), 'uint64', 'be')==2^32*3976200234)
assert(read(buffer("\237\000\000\242\000\000\000\000"), 'uint64', 'be')==2^32*3976200434)

assert(read(buffer("\000\000\000\037\042\000\000\000"), 'uint64', 'le')==181009383424)
assert(read(buffer("\000\000\000\037\242\000\000\000"), 'uint64', 'le')==1040002842624)
assert(read(buffer("\000\000\000\237\042\000\000\000"), 'uint64', 'le')==184364826624)
assert(read(buffer("\000\000\000\237\242\000\000\000"), 'uint64', 'le')==1043358285824)

assert(read(buffer("\000\000\000\037\042\000\000\000"), 'uint64', 'be')==159618433024)
assert(read(buffer("\000\000\000\037\242\000\000\000"), 'uint64', 'be')==162973876224)
assert(read(buffer("\000\000\000\237\042\000\000\000"), 'uint64', 'be')==1018611892224)
assert(read(buffer("\000\000\000\237\242\000\000\000"), 'uint64', 'be')==1021967335424)

assert(read(buffer("\037\000\000\000\000\000\000\042"), 'uint64', 'le')=="\037\000\000\000\000\000\000\042")
assert(read(buffer("\037\000\000\000\000\000\000\242"), 'uint64', 'le')=="\037\000\000\000\000\000\000\242")
assert(read(buffer("\237\000\000\000\000\000\000\042"), 'uint64', 'le')=="\237\000\000\000\000\000\000\042")
assert(read(buffer("\237\000\000\000\000\000\000\242"), 'uint64', 'le')=="\237\000\000\000\000\000\000\242")

assert(read(buffer("\037\000\000\000\000\000\000\042"), 'uint64', 'be')=="\042\000\000\000\000\000\000\037")
assert(read(buffer("\037\000\000\000\000\000\000\242"), 'uint64', 'be')=="\242\000\000\000\000\000\000\037")
assert(read(buffer("\237\000\000\000\000\000\000\042"), 'uint64', 'be')=="\042\000\000\000\000\000\000\237")
assert(read(buffer("\237\000\000\000\000\000\000\242"), 'uint64', 'be')=="\242\000\000\000\000\000\000\237")

assert(serialize(2^32*704643109, 'uint64', 'le')=="\000\000\000\000\037\000\000\042")
assert(serialize(2^32*4060086309, 'uint64', 'le')=="\000\000\000\000\037\000\000\242")
assert(serialize(2^32*704643309, 'uint64', 'le')=="\000\000\000\000\237\000\000\042")
assert(serialize(2^32*4060086509, 'uint64', 'le')=="\000\000\000\000\237\000\000\242")

assert(serialize(620757034, 'uint64', 'be')=="\000\000\000\000\037\000\000\042")
assert(serialize(620757234, 'uint64', 'be')=="\000\000\000\000\037\000\000\242")
assert(serialize(3976200234, 'uint64', 'be')=="\000\000\000\000\237\000\000\042")
assert(serialize(3976200434, 'uint64', 'be')=="\000\000\000\000\237\000\000\242")

assert(serialize(704643109, 'uint64', 'le')=="\037\000\000\042\000\000\000\000")
assert(serialize(4060086309, 'uint64', 'le')=="\037\000\000\242\000\000\000\000")
assert(serialize(704643309, 'uint64', 'le')=="\237\000\000\042\000\000\000\000")
assert(serialize(4060086509, 'uint64', 'le')=="\237\000\000\242\000\000\000\000")

assert(serialize(2^32*620757034, 'uint64', 'be')=="\037\000\000\042\000\000\000\000")
assert(serialize(2^32*620757234, 'uint64', 'be')=="\037\000\000\242\000\000\000\000")
assert(serialize(2^32*3976200234, 'uint64', 'be')=="\237\000\000\042\000\000\000\000")
assert(serialize(2^32*3976200434, 'uint64', 'be')=="\237\000\000\242\000\000\000\000")

assert(serialize(181009383424, 'uint64', 'le')=="\000\000\000\037\042\000\000\000")
assert(serialize(1040002842624, 'uint64', 'le')=="\000\000\000\037\242\000\000\000")
assert(serialize(184364826624, 'uint64', 'le')=="\000\000\000\237\042\000\000\000")
assert(serialize(1043358285824, 'uint64', 'le')=="\000\000\000\237\242\000\000\000")

assert(serialize(159618433024, 'uint64', 'be')=="\000\000\000\037\042\000\000\000")
assert(serialize(162973876224, 'uint64', 'be')=="\000\000\000\037\242\000\000\000")
assert(serialize(1018611892224, 'uint64', 'be')=="\000\000\000\237\042\000\000\000")
assert(serialize(1021967335424, 'uint64', 'be')=="\000\000\000\237\242\000\000\000")

assert(serialize("\037\000\000\000\000\000\000\042", 'uint64', 'le')=="\037\000\000\000\000\000\000\042")
assert(serialize("\037\000\000\000\000\000\000\242", 'uint64', 'le')=="\037\000\000\000\000\000\000\242")
assert(serialize("\237\000\000\000\000\000\000\042", 'uint64', 'le')=="\237\000\000\000\000\000\000\042")
assert(serialize("\237\000\000\000\000\000\000\242", 'uint64', 'le')=="\237\000\000\000\000\000\000\242")

assert(serialize("\042\000\000\000\000\000\000\037", 'uint64', 'be')=="\037\000\000\000\000\000\000\042")
assert(serialize("\242\000\000\000\000\000\000\037", 'uint64', 'be')=="\037\000\000\000\000\000\000\242")
assert(serialize("\042\000\000\000\000\000\000\237", 'uint64', 'be')=="\237\000\000\000\000\000\000\042")
assert(serialize("\242\000\000\000\000\000\000\237", 'uint64', 'be')=="\237\000\000\000\000\000\000\242")

-- sint64

assert(read(buffer("\000\000\000\000\000\000\000\000"), 'sint64', 'le')==0)

assert(read(buffer("\001\000\000\000\000\000\000\000"), 'sint64', 'le')==1)
assert(read(buffer("\255\000\000\000\000\000\000\000"), 'sint64', 'le')==255)
assert(read(buffer("\000\001\000\000\000\000\000\000"), 'sint64', 'le')==256)
assert(read(buffer("\000\000\001\000\000\000\000\000"), 'sint64', 'le')==256^2)
assert(read(buffer("\000\000\000\001\000\000\000\000"), 'sint64', 'le')==256^3)
assert(read(buffer("\000\000\000\000\001\000\000\000"), 'sint64', 'le')==256^4)

assert(read(buffer("\001\002\003\004\005\000\000\000"), 'sint64', 'le')==1*256^0 + 2*256^1 + 3*256^2 + 4*256^3 + 5*256^4)
assert(read(buffer("\001\002\003\004\005\006\000\000"), 'sint64', 'le')==1*256^0 + 2*256^1 + 3*256^2 + 4*256^3 + 5*256^4 + 6*256^5)
assert(read(buffer("\001\002\003\004\005\006\007\000"), 'sint64', 'le')==1*256^0 + 2*256^1 + 3*256^2 + 4*256^3 + 5*256^4 + 6*256^5 + 7*256^6)
assert(read(buffer("\000\002\003\004\005\006\007\008"), 'sint64', 'le')==2*256^1 + 3*256^2 + 4*256^3 + 5*256^4 + 6*256^5 + 7*256^6 + 8*256^7)
assert(read(buffer("\001\002\003\004\005\006\007\008"), 'sint64', 'le')=="\001\002\003\004\005\006\007\008")

assert(read(buffer("\255\255\255\255\255\255\255\255"), 'sint64', 'le')==-1)
assert(read(buffer("\000\255\255\255\255\255\255\255"), 'sint64', 'le')==-256)
assert(read(buffer("\255\254\255\255\255\255\255\255"), 'sint64', 'le')==-1-256)
assert(read(buffer("\255\255\254\255\255\255\255\255"), 'sint64', 'le')==-1-256^2)
assert(read(buffer("\255\255\255\254\255\255\255\255"), 'sint64', 'le')==-1-256^3)
assert(read(buffer("\255\255\255\255\254\255\255\255"), 'sint64', 'le')==-1-256^4)

assert(read(buffer("\254\253\252\251\250\255\255\255"), 'sint64', 'le')==-1 -1*256^0 - 2*256^1 - 3*256^2 - 4*256^3 - 5*256^4)
assert(read(buffer("\254\253\252\251\250\249\255\255"), 'sint64', 'le')==-1 -1*256^0 - 2*256^1 - 3*256^2 - 4*256^3 - 5*256^4 - 6*256^5)
assert(read(buffer("\254\253\252\251\250\249\248\255"), 'sint64', 'le')==-1 -1*256^0 - 2*256^1 - 3*256^2 - 4*256^3 - 5*256^4 - 6*256^5 - 7*256^6)
assert(read(buffer("\000\254\252\251\250\249\248\247"), 'sint64', 'le')==- 2*256^1 - 3*256^2 - 4*256^3 - 5*256^4 - 6*256^5 - 7*256^6 - 8*256^7)

assert(read(buffer("\000\000\000\000\000\000\000\000"), 'sint64', 'be')==0)

assert(read(buffer("\000\000\000\000\000\000\000\001"), 'sint64', 'be')==1)
assert(read(buffer("\000\000\000\000\000\000\000\255"), 'sint64', 'be')==255)
assert(read(buffer("\000\000\000\000\000\000\001\000"), 'sint64', 'be')==256)
assert(read(buffer("\000\000\000\000\000\001\000\000"), 'sint64', 'be')==256^2)
assert(read(buffer("\000\000\000\000\001\000\000\000"), 'sint64', 'be')==256^3)
assert(read(buffer("\000\000\000\001\000\000\000\000"), 'sint64', 'be')==256^4)

assert(read(buffer("\000\000\000\005\004\003\002\001"), 'sint64', 'be')==1*256^0 + 2*256^1 + 3*256^2 + 4*256^3 + 5*256^4)
assert(read(buffer("\000\000\006\005\004\003\002\001"), 'sint64', 'be')==1*256^0 + 2*256^1 + 3*256^2 + 4*256^3 + 5*256^4 + 6*256^5)
assert(read(buffer("\000\007\006\005\004\003\002\001"), 'sint64', 'be')==1*256^0 + 2*256^1 + 3*256^2 + 4*256^3 + 5*256^4 + 6*256^5 + 7*256^6)
assert(read(buffer("\008\007\006\005\004\003\002\000"), 'sint64', 'be')==2*256^1 + 3*256^2 + 4*256^3 + 5*256^4 + 6*256^5 + 7*256^6 + 8*256^7)
assert(read(buffer("\008\007\006\005\004\003\002\001"), 'sint64', 'be')=="\001\002\003\004\005\006\007\008")

assert(read(buffer("\255\255\255\255\255\255\255\255"), 'sint64', 'be')==-1)
assert(read(buffer("\255\255\255\255\255\255\255\000"), 'sint64', 'be')==-256)
assert(read(buffer("\255\255\255\255\255\255\254\255"), 'sint64', 'be')==-1-256)
assert(read(buffer("\255\255\255\255\255\254\255\255"), 'sint64', 'be')==-1-256^2)
assert(read(buffer("\255\255\255\255\254\255\255\255"), 'sint64', 'be')==-1-256^3)
assert(read(buffer("\255\255\255\254\255\255\255\255"), 'sint64', 'be')==-1-256^4)

assert(read(buffer("\255\255\255\250\251\252\253\254"), 'sint64', 'be')==-1 -1*256^0 - 2*256^1 - 3*256^2 - 4*256^3 - 5*256^4)
assert(read(buffer("\255\255\249\250\251\252\253\254"), 'sint64', 'be')==-1 -1*256^0 - 2*256^1 - 3*256^2 - 4*256^3 - 5*256^4 - 6*256^5)
assert(read(buffer("\255\248\249\250\251\252\253\254"), 'sint64', 'be')==-1 -1*256^0 - 2*256^1 - 3*256^2 - 4*256^3 - 5*256^4 - 6*256^5 - 7*256^6)
assert(read(buffer("\247\248\249\250\251\252\254\000"), 'sint64', 'be')==- 2*256^1 - 3*256^2 - 4*256^3 - 5*256^4 - 6*256^5 - 7*256^6 - 8*256^7)

assert(serialize(0, 'sint64', 'le')=="\000\000\000\000\000\000\000\000")

assert(serialize(1, 'sint64', 'le')=="\001\000\000\000\000\000\000\000")
assert(serialize(255, 'sint64', 'le')=="\255\000\000\000\000\000\000\000")
assert(serialize(256, 'sint64', 'le')=="\000\001\000\000\000\000\000\000")
assert(serialize(256^2, 'sint64', 'le')=="\000\000\001\000\000\000\000\000")
assert(serialize(256^3, 'sint64', 'le')=="\000\000\000\001\000\000\000\000")
assert(serialize(256^4, 'sint64', 'le')=="\000\000\000\000\001\000\000\000")

assert(serialize(1*256^0 + 2*256^1 + 3*256^2 + 4*256^3 + 5*256^4, 'sint64', 'le')=="\001\002\003\004\005\000\000\000")

assert(serialize(-1, 'sint64', 'le')=="\255\255\255\255\255\255\255\255")
assert(serialize(-256, 'sint64', 'le')=="\000\255\255\255\255\255\255\255")
assert(serialize(-1-256, 'sint64', 'le')=="\255\254\255\255\255\255\255\255")
assert(serialize(-1-256^2, 'sint64', 'le')=="\255\255\254\255\255\255\255\255")
assert(serialize(-1-256^3, 'sint64', 'le')=="\255\255\255\254\255\255\255\255")
assert(serialize(-1-256^4, 'sint64', 'le')=="\255\255\255\255\254\255\255\255")

assert(serialize(-1 -1*256^0 - 2*256^1 - 3*256^2 - 4*256^3 - 5*256^4, 'sint64', 'le')=="\254\253\252\251\250\255\255\255")

assert(serialize(0, 'sint64', 'be')=="\000\000\000\000\000\000\000\000")

assert(serialize(1, 'sint64', 'be')=="\000\000\000\000\000\000\000\001")
assert(serialize(255, 'sint64', 'be')=="\000\000\000\000\000\000\000\255")
assert(serialize(256, 'sint64', 'be')=="\000\000\000\000\000\000\001\000")
assert(serialize(256^2, 'sint64', 'be')=="\000\000\000\000\000\001\000\000")
assert(serialize(256^3, 'sint64', 'be')=="\000\000\000\000\001\000\000\000")
assert(serialize(256^4, 'sint64', 'be')=="\000\000\000\001\000\000\000\000")

assert(serialize(1*256^0 + 2*256^1 + 3*256^2 + 4*256^3 + 5*256^4, 'sint64', 'be')=="\000\000\000\005\004\003\002\001")

assert(serialize(-1, 'sint64', 'be')=="\255\255\255\255\255\255\255\255")
assert(serialize(-256, 'sint64', 'be')=="\255\255\255\255\255\255\255\000")
assert(serialize(-1-256, 'sint64', 'be')=="\255\255\255\255\255\255\254\255")
assert(serialize(-1-256^2, 'sint64', 'be')=="\255\255\255\255\255\254\255\255")
assert(serialize(-1-256^3, 'sint64', 'be')=="\255\255\255\255\254\255\255\255")
assert(serialize(-1-256^4, 'sint64', 'be')=="\255\255\255\254\255\255\255\255")

assert(serialize(-1 -1*256^0 - 2*256^1 - 3*256^2 - 4*256^3 - 5*256^4, 'sint64', 'be')=="\255\255\255\250\251\252\253\254")

-- enum

local foo_e = _M.util.enum{
	bar = 1,
	baz = 2,
}

assert(read(buffer("\001"), 'enum', foo_e, 'uint8')=='bar')
assert(read(buffer("\002\000"), 'enum', foo_e, 'uint16', 'le')=='baz')

assert(serialize('bar', 'enum', foo_e, 'uint8')=="\001")
assert(serialize('baz', 'enum', foo_e, 'uint16', 'le')=="\002\000")

-- mapping

local foo_m = _M.util.enum{
	bar = 'A',
	baz = 'B',
}

assert(read(buffer("A\000"), 'mapping', foo_m, 'cstring')=='bar')
assert(read(buffer("\001B"), 'mapping', foo_m, 'bytes', 'uint8')=='baz')

assert(serialize('bar', 'mapping', foo_m, 'cstring')=="A\000")
assert(serialize('baz', 'mapping', foo_m, 'bytes', 'uint8')=="\001B")

-- flags

if libbit then

local foo_f = {
	bar = 1,
	baz = 2,
}

local value = read(buffer("\001"), 'flags', foo_f, 'uint8')
assert(value.bar==true and next(value, next(value))==nil)
local value = read(buffer("\003\000"), 'flags', foo_f, 'uint16', 'le')
assert(value.bar==true and value.baz==true and next(value, next(value, next(value)))==nil)

assert(serialize({bar=true}, 'flags', foo_f, 'uint8')=="\001")
assert(serialize({bar=true, baz=true}, 'flags', foo_f, 'uint16', 'le')=="\003\000")

else
	print("cannot test 'flags' datatype (optional dependency 'bit' missing)")
end

-- bytes

assert(read(buffer("fo"), 'bytes', 2)=='fo')
assert(read(buffer("foo"), 'bytes', 2)=='fo')

assert(serialize('fo', 'bytes', 2)=="fo")

assert(read(buffer("\002fo"), 'bytes', 'uint8')=='fo')
assert(read(buffer("\002\000foo"), 'bytes', 'uint16', 'le')=='fo')

assert(serialize('fo', 'bytes', 'uint8')=="\002fo")
assert(serialize('fo', 'bytes', 'uint16', 'le')=="\002\000fo")

-- array

local value = read(buffer("\037\042"), 'array', 2, 'uint8')
assert(value[1]==37 and value[2]==42 and next(value, next(value, next(value)))==nil)
local value = read(buffer("\000\042\000\037"), 'array', '*', 'uint16', 'be')
assert(value[1]==42 and value[2]==37 and next(value, next(value, next(value)))==nil)

local value = read(buffer("\002\037\042\000"), 'array', {'uint8'}, 'uint8')
assert(value[1]==37 and value[2]==42 and next(value, next(value, next(value)))==nil)
local value = read(buffer("\002\000\000\037\000\042\038"), 'array', {'uint16', 'le'}, 'uint16', 'be')
assert(value[1]==37 and value[2]==42 and next(value, next(value, next(value)))==nil)
local value = read(buffer("\002\000\000\037\000\042\038"), 'array', {'uint16', 'le'}, {'uint16', 'be'})
assert(value[1]==37 and value[2]==42 and next(value, next(value, next(value)))==nil)

assert(serialize({37, 42}, 'array', {'uint8'}, 'uint8')=="\002\037\042")
assert(serialize({37, 42}, 'array', {'uint16', 'le'}, 'uint16', 'be')=="\002\000\000\037\000\042")
assert(serialize({37, 42}, 'array', {'uint16', 'le'}, {'uint16', 'be'})=="\002\000\000\037\000\042")

-- paddedvalue

assert(read(buffer("\037\000\000"), 'paddedvalue', 3, '\000', 'uint8')==37)
assert(read(buffer("\004\042\000\000\000"), 'paddedvalue', {'uint8'}, '\000', 'uint8')==42)
assert(read(buffer("\004\042\000\000"), 'paddedvalue', {'uint8', included=true}, '\000', 'uint8')==42)
local value = read(buffer("\002\042"), 'paddedvalue', {'uint8', included=true}, '\000', {'array', 1, 'uint8'})
assert(type(value)=='table' and #value==1 and value[1]==42 and value.__trailing_bytes==nil)
local value = read(buffer("\005\042\000\000\000"), 'paddedvalue', {'uint8', included=true}, '\000', {'array', 1, 'uint8'})
assert(type(value)=='table' and #value==1 and value[1]==42 and value.__trailing_bytes==nil) -- :FIXME: we lost the information of how many padding bytes we had
local value = read(buffer("\005\042\000\000\001"), 'paddedvalue', {'uint8', included=true}, '\000', {'array', 1, 'uint8'})
assert(type(value)=='table' and #value==1 and value[1]==42 and value.__trailing_bytes=="\000\000\001")
local value = read(buffer("\005\042\001\000\00"), 'paddedvalue', {'uint8', included=true}, '\000', {'array', 1, 'uint8'})
assert(type(value)=='table' and #value==1 and value[1]==42 and value.__trailing_bytes=="\001") -- :FIXME: we lost the information of how many clean padding bytes we had

assert(serialize(37, 'paddedvalue', 3, '\000', 'uint8')=="\037\000\000")
assert(serialize(42, 'paddedvalue', {'uint8'}, '\000', 'uint8')=="\001\042")
assert(serialize(42, 'paddedvalue', {'uint8', included=true}, '\000', 'uint8')=="\002\042")
assert(serialize({42}, 'paddedvalue', {'uint8', included=true}, '\000', {'array', 1, 'uint8'})=="\002\042")
assert(serialize({42, __trailing_bytes="\000\000\000"}, 'paddedvalue', {'uint8', included=true}, '\000', {'array', 1, 'uint8'})=="\005\042\000\000\000")
assert(serialize({42, __trailing_bytes="\000\000\001"}, 'paddedvalue', {'uint8', included=true}, '\000', {'array', 1, 'uint8'})=="\005\042\000\000\001")

-- sizedvalue

local value = read(buffer("\037\000\000"), 'sizedvalue', 2, 'array', '*', 'uint8')
assert(value[1]==37 and value[2]==0 and next(value, next(value, next(value)))==nil)
assert(read(buffer("\000\004foobar"), 'sizedvalue', {'uint16', 'be'}, 'bytes', '*')=="foob")
assert(read(buffer("\000\006foobar"), 'sizedvalue', {'uint16', 'be', included=true}, 'bytes', '*')=="foob")

assert(serialize({37, 0}, 'sizedvalue', 2, 'array', '*', 'uint8')=="\037\000")
assert(serialize("foob", 'sizedvalue', {'uint16', 'be'}, 'bytes', '*')=="\000\004foob")
assert(serialize("foob", 'sizedvalue', {'uint16', 'be', included=true}, 'bytes', '*')=="\000\006foob")

-- cstring

assert(read(buffer("foo\000bar"), 'cstring')=="foo")

-- float

--print(string.byte(serialize(-37e-12, 'float', 'le'), 1, 4))

assert(serialize(37e12, 'float', 'le')=='\239\154\006\086')
assert(serialize(-3.1953823392725e-34, 'float', 'le')=='\157\094\212\135')
assert(read(buffer("\000\000\000\000"), 'float', 'le')==0)
assert(read(buffer("\000\000\128\063"), 'float', 'le')==1)
assert(read(buffer("\000\000\000\064"), 'float', 'le')==2)
assert(read(buffer("\000\000\040\066"), 'float', 'le')==42)
assert(read(buffer("\239\154\006\086"), 'float', 'le')==36999998210048) -- best approx for 37e12 as float
assert(read(buffer("\000\000\000\063"), 'float', 'le')==0.5)
assert(math.abs(read(buffer("\010\215\163\060"), 'float', 'le') / 0.02 - 1) < 1e-7)
assert(math.abs(read(buffer("\076\186\034\046"), 'float', 'le') / 37e-12 - 1) < 1e-8)
assert(read(buffer("\000\000\128\191"), 'float', 'le')==-1)
assert(read(buffer("\000\000\000\192"), 'float', 'le')==-2)
assert(read(buffer("\000\000\040\194"), 'float', 'le')==-42)
assert(math.abs(read(buffer("\239\154\006\214"), 'float', 'le') / -37e12 - 1) < 1e-7)
assert(math.abs(read(buffer("\076\186\034\174"), 'float', 'le') / -37e-12 - 1) < 1e-8)

-- double

assert(serialize(37e12, 'double', 'le')=='\000\000\168\237\093\211\192\066')
assert(serialize(-3.1953823392725e-34, 'double', 'le')=='\079\000\000\160\211\139\250\184')
assert(read(buffer("\000\000\000\000\000\000\000\000"), 'double', 'le')==0)
assert(read(buffer("\000\000\000\000\000\000\240\063"), 'double', 'le')==1)
assert(read(buffer("\000\000\000\000\000\000\000\064"), 'double', 'le')==2)
assert(read(buffer("\000\000\000\000\000\000\069\064"), 'double', 'le')==42)
assert(read(buffer("\000\000\168\237\093\211\192\066"), 'double', 'le')==37e12)
assert(read(buffer("\000\000\000\224\093\211\192\066"), 'double', 'le')==36999998210048) -- best float approx for 37e12
assert(read(buffer("\000\000\000\000\000\000\224\063"), 'double', 'le')==0.5)
assert(math.abs(read(buffer("\123\020\174\071\225\122\148\063"), 'double', 'le') / 0.02 - 1) < 1e-7)
assert(math.abs(read(buffer("\164\022\093\125\073\087\196\061"), 'double', 'le') / 37e-12 - 1) < 1e-8)
assert(read(buffer("\000\000\000\000\000\000\240\191"), 'double', 'le')==-1)
assert(read(buffer("\000\000\000\000\000\000\000\192"), 'double', 'le')==-2)
assert(read(buffer("\000\000\000\000\000\000\069\192"), 'double', 'le')==-42)
assert(math.abs(read(buffer("\000\000\168\237\093\211\192\194"), 'double', 'le') / -37e12 - 1) < 1e-7)
assert(math.abs(read(buffer("\164\022\093\125\073\087\196\189"), 'double', 'le') / -37e-12 - 1) < 1e-8)


-- bytes2hex

assert(read(buffer("fo"), 'bytes2hex', 2)=='666F')
assert(read(buffer("foo"), 'bytes2hex', 2)=='666F')

assert(serialize('666F', 'bytes2hex', 2)=="fo")

-- bytes2base32

assert(read(buffer("fooba"), 'bytes2base32', 5)=='MZXW6YTB')
assert(read(buffer("foobar"), 'bytes2base32', 5)=='MZXW6YTB')

assert(serialize('MZXW6YTB', 'bytes2base32', 5)=="fooba")

-- boolean

assert(read(buffer("\000"), 'boolean', 'uint8')==false)
assert(read(buffer("\000\001"), 'boolean', 'uint16', 'be')==true)
assert(read(buffer("\002\000"), 'boolean', 'sint16', 'le')==2)

assert(serialize(false, 'boolean', 'uint8')=="\000")
assert(serialize(true, 'boolean', 'uint16', 'be')=="\000\001")
assert(serialize(2, 'boolean', 'sint16', 'le')=="\002\000")

-- boolean8

assert(read(buffer("\000"), 'boolean8')==false)
assert(read(buffer("\001"), 'boolean8')==true)
assert(read(buffer("\002\000"), 'boolean8')==2)

assert(serialize(false, 'boolean8')=="\000")
assert(serialize(true, 'boolean8')=="\001")
assert(serialize(2, 'boolean8')=="\002")

-- truenil

assert(read(buffer("\000"), 'truenil', 'uint8')==nil)
assert(read(buffer("\000\001"), 'truenil', 'uint16', 'be')==true)
assert(read(buffer("\002\000"), 'truenil', 'sint16', 'le')==2)

assert(serialize(nil, 'truenil', 'uint8')=="\000")
assert(serialize(true, 'truenil', 'uint16', 'be')=="\000\001")
assert(serialize(2, 'truenil', 'sint16', 'le')=="\002\000")

-- struct

local foo_s = {
	{'foo', 'uint8'},
	{'bar', 'uint16', 'be'},
}
_M.struct.foo_s = foo_s

local value = read(buffer("\001\002\003\004"), 'struct', foo_s)
assert(value.foo==1 and value.bar==515 and next(value, next(value, next(value)))==nil)
local value = read(buffer("\001\002\003\004"), 'foo_s')
assert(value.foo==1 and value.bar==515 and next(value, next(value, next(value)))==nil)
assert(serialize({foo=1, bar=515}, 'foo_s')=="\001\002\003")
assert(pcall(serialize, {foo=1, bar=nil}, 'foo_s')==false)
assert(select(2, pcall(serialize, {foo=1, bar=nil}, 'foo_s')):match("value is not a number"))

-- fstruct

function _M.fstruct.foo_fs(self)
	self 'foo' ('uint8')
	self 'bar' ('uint16', 'be')
end

local value = read(buffer("\001\002\003\004"), 'foo_fs')
assert(value.foo==1 and value.bar==515 and next(value, next(value, next(value)))==nil)
assert(serialize(value, 'foo_fs')=="\001\002\003")

-- buffers

if libbit then
	local b = buffer("\042\037")
	-- 0010010100101010
	assert(b:getbits(3)=='\0\1\0')
	assert(b:getbits(8)=='\1\0\1\0\0\1\0\1')

	local b = buffer("\042\037")
	b.byte_endianness = 'be'
	-- 0010101000100101
	assert(b:getbits(3)=='\0\0\1')
	assert(b:getbits(8)=='\0\1\0\1\0\0\0\1')

	local b = buffer("")
	assert(b:putbytes("\042"))
	assert(b:getbytes(1)=="\042")
	assert(b:putbits('\0\1\0'))
	assert(b:putbits('\1\0\1\0\0'))
	local bytes = b:getbytes(1)
	assert(bytes=="\042")
else
	print("cannot test bit streams (optional dependency 'bit' missing)")
end

-- filestream

do
	require 'io'
	local file = io.tmpfile()
	local out = _M.filestream(file)
	write(out, "foo", 'bytes', 3)
	write(out, "bar", 'cstring')
	file:seek('set', 0)
	local in_ = _M.filestream(file)
	assert(read(in_, 'cstring')=="foobar")
	file:close()
end

-- tcp stream

local socket
if pcall(function() socket = require 'socket' end) then
	local server,port
	for i=1,10 do
		port = 50000+i
		server = socket.bind('*', port)
		if server then break end
	end
	if server then
		local a = socket.connect('127.0.0.1', port)
		local b = server:accept()
		local out = _M.tcpstream(a)
		write(out, "foo", 'bytes', 3)
		write(out, "bar", 'cstring')
		local in_ = _M.tcpstream(b)
		a:send("foo")
		assert(read(in_, 'cstring')=="foobar")
	else
		print("cannot test tcp streams (could not bind a server socket)")
	end
else
	print("cannot test tcp streams (optional dependency 'socket' missing)")
end

-- uint

if libbit then
	-- \042\037 -> 0101010010100100
	assert(read(buffer("\042\037"), 'uint', 4, 'le')==2+8)
	assert(read(buffer("\042\037"), 'uint', 4, 'be')==1+4)

	local b = buffer("\042\037\000")
	b.byte_endianness = 'be'
	-- \042\037 'be' -> 0010101000100101
	assert(read(b, 'uint', 4, 'le')==4)
	assert(read(b, 'uint', 7, 'be')==81)
	assert(b:bitlength()==5+8)

--	print(read(buffer("\042\037"), 'uint', 13, 'le'))
--	print(">", string.byte(buffer("\042\037"):getbits(16), 1, 16))
	assert(read(buffer("\042\037"), 'uint', 13, 'le')==2+8+32+256+1024) -- 0101010010100 100
	assert(read(buffer("\042\037", 'be'), 'uint', 13, 'le')==4+16+64+1024) -- 0010101000100 101
	assert(read(buffer("\042\037", 'be'), 'uint', '*', 'le')==4+16+64+1024+8192+32768) -- 0010101000100101

	local t = read(buffer("\042\037"), 'array', 13, 'uint', 1) -- 0101010010100 100
	assert(type(t)=='table')
	assert(#t==13)
	assert(t[1]==0)
	assert(t[4]==1)
	assert(t[7]==0)
	assert(t[11]==1)
	assert(t[13]==0)
	
	local b = buffer("")
	write(b, {0,1,0,1,0,1,0,0,1,0,1,0,0}, 'array', 13, 'uint', 1) -- 0101010010100
	assert(b.data=="\042") -- only full bytes are commited to the buffer
	write(b, {1,0,0}, 'array', 3, 'uint', 1) -- 100
	assert(b.data=="\042\037")
	
	assert(not pcall(serialize, 0, 'uint', 1))
	assert(not pcall(serialize, 0, 'uint', 8, 'le'))
else
	print("cannot test 'uint' datatype (optional dependency 'bit' missing)")
end

-- sint

if libbit then
	-- \170\037 -> 1101010010100100
	assert(read(buffer("\170\037"), 'sint', 4, 'le')==-6)
	assert(read(buffer("\170\037"), 'sint', 4, 'be')==5)
	
	assert(serialize(0, 'sint', 8, 'le')=="\000")
	assert(serialize(4194303, 'sint', 24, 'le')=="\255\255\063")
else
	print("cannot test 'sint' datatype (optional dependency 'bit' missing)")
end

-- constant

local value,err = read(buffer("\237\042"), 'constant', 10989, 'uint16', 'le')
assert(value==nil and err==nil)

assert(serialize(nil, 'constant', 37e12, 'float', 'le')=='\239\154\006\086')

_M.struct.s_const = {
	{'const', 'constant', 42, 'uint8'},
	{'var', 'uint8'},
}

local value,err = read(buffer("\042\086"), 's_const')
assert(type(value)=='table')
assert(next(value)=='var')
assert(next(value, 'var')==nil)
assert(value.var==86)

assert(serialize({
	var = 87,
}, 's_const')=='\042\087')

-- taggedvalue

_M.alias.tv_plain = {'taggedvalue', {'uint8'}, {
	{'uint8'},
	{'uint16', 'le'},
}}

local value = assert(read(buffer("\001\042"), 'tv_plain'))
assert(type(value)=='table')
assert(next(value)=='tag' or next(value)=='value')
assert(next(value, 'tag')==nil or next(value, 'tag')=='value')
assert(next(value, 'value')==nil or next(value, 'value')=='tag')
assert(value.tag==1)
assert(value.value==42)
local value = assert(read(buffer("\002\237\037"), 'tv_plain'))
assert(type(value)=='table')
assert(next(value)=='tag' or next(value)=='value')
assert(next(value, 'tag')==nil or next(value, 'tag')=='value')
assert(next(value, 'value')==nil or next(value, 'value')=='tag')
assert(value.tag==2)
assert(value.value==9709)

assert(serialize({tag=1, value=42}, 'tv_plain')=="\001\042")
assert(serialize({tag=2, value=9709}, 'tv_plain')=="\002\237\037")

_M.alias.tv_selector = {'taggedvalue', {'cstring'}, {
	number = {'uint8'},
	string = {'cstring'},
}, type} -- use standard Lua 'type' function as selector

assert(read(buffer("number\000\042"), 'tv_selector')==42)
assert(read(buffer("string\000foo\000"), 'tv_selector')=="foo")

assert(serialize(42, 'tv_selector')=="number\000\042")
assert(serialize("foo", 'tv_selector')=="string\000foo\000")

-- empty

assert(serialize("foo", 'empty', "foo")=="")
assert(read("", 'empty', 42)==42)

-- alias

_M.alias.alias1_t = {'uint32', 'le'}

assert(read(buffer("\037\000\000\042"), 'alias1_t')==704643109)
assert(serialize(704643109, 'alias1_t')=="\037\000\000\042")

_M.alias.alias2_t = 'uint8'

assert(read(buffer("\037\000\000\042"), 'alias2_t')==37)
assert(serialize(37, 'alias2_t')=="\037")

_M.alias.alias3_t = function(foo, endianness) return 'uint32',endianness end

assert(read(buffer("\037\000\000\042"), 'alias3_t', 'foo', 'le')==704643109)
assert(serialize(704643109, 'alias3_t', 'foo', 'le')=="\037\000\000\042")

_M.alias.alias4_t = function(endianness, size_t, ...) return 'array', {size_t, ...}, 'uint32', endianness end

local value = read(buffer("\000\002\042\000\000\000\037\000\000\000"), 'alias4_t', 'le', 'uint16', 'be')
assert(type(value)=='table' and value[1]==42 and value[2]==37 and next(value, next(value, next(value)))==nil)
assert(serialize({42, 37}, 'alias4_t', 'le', 'uint16', 'be')=="\000\002\042\000\000\000\037\000\000\000")

_M.alias.alias5_t = {'constant', '%1', 'cstring'} -- %n were only briefly supported

assert(serialize(nil, 'alias5_t', 'foo')=="%1\000")
local value,err = read(buffer("%1\000"), 'alias5_t', 'foo')
assert(value==nil and err==nil)
local value,err = read(buffer("%1"), 'alias5_t', 'foo')
assert(value==nil and err=='end of stream')

_M.alias.alias6_t = function(str) return 'constant', str, 'cstring' end

assert(serialize(nil, 'alias6_t', 'foo')=="foo\000")
local value,err = read(buffer("foo\000"), 'alias6_t', 'foo')
assert(value==nil and err==nil)
local value,err = read(buffer("foo"), 'alias6_t', 'foo')
assert(value==nil and err=='end of stream')

--

for _,func in ipairs(funcs) do
	if not tested[func] then
		print("serialization function '"..func.."' has not been tested")
	end
end

--

print("all tests passed successfully")

end

return _M

--[[
Copyright (c) 2009-2012 Jérôme Vuarand

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]

-- vi: ts=4 sts=4 sw=4 noet
