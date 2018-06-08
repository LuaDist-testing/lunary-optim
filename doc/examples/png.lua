local serial = require 'serial'
serial.util = require 'serial.util'
local bit
if _VERSION=="Lua 5.2" then
	bit = require 'bit32'
else
	bit = require 'bit'
end

local read = serial.read
local write = serial.write
local serialize = serial.serialize
local struct = serial.struct
local fstruct = serial.fstruct
local alias = serial.alias

-- based on http://www.libpng.org/pub/png/spec/1.2/png-1.2-pdg.html

------------------------------------------------------------------------------

-- Table of CRCs of all 8-bit messages.
local crc_table = {}
do
	for n=0,255 do
		local c = n
		for k=0,7 do
			if bit.band(c, 1)~=0 then
				c = bit.bxor(0xedb88320, bit.rshift(c, 1))
			else
				c = bit.rshift(c, 1)
			end
		end
		crc_table[n] = c
	end
end

--[[ Update a running CRC with the bytes buf[0..len-1]--the CRC
	 should be initialized to all 1's, and the transmitted value
	 is the 1's complement of the final running CRC (see the
	 crc() routine below)). ]]

local function update_crc(crc, buf) -- return unsigned long
	local c = crc -- unsigned long

	for n=1,#buf do
		c = bit.bxor(crc_table[bit.band(bit.bxor(c, string.byte(buf, n)), 0xff)], bit.rshift(c, 8))
	end
	return c
end

-- Return the CRC of the bytes buf[0..len-1].
local function crc(buf)
	local value = bit.bxor(update_crc(0xffffffff, buf), 0xffffffff)
	if value < 0 then -- luabitop (but not 5.2's bit32) returns sint32
		value = value + 2^32
	end
	return serial.serialize.uint32(value, 'be')
end

------------------------------------------------------------------------------

local png_color_type = {
	palette = 1,
	color = 2,
	alpha = 4,
}

local png_compression_method = serial.util.enum{
	deflate = 0,
}

local png_filter_method = serial.util.enum{
	default = 0,
}

local png_interlace_method = serial.util.enum{
	none = 0,
	adam7 = 1,
}

local png_standard_keywords = {
	'Title',			-- Short (one line) title or caption for image
	'Author',			-- Name of image's creator
	'Description',		-- Description of image (possibly long)
	'Copyright',		-- Copyright notice
	'Creation Time',	-- Time of original image creation
	'Software',			-- Software used to create the image
	'Disclaimer',		-- Legal disclaimer
	'Warning',			-- Warning of nature of content
	'Source',			-- Device used to create the image
	'Comment',			-- Miscellaneous comment; conversion from GIF comment
}


------------------------------------------------------------------------------

function fstruct.png_file(self)
	self 'signature' ('bytes', 8)
	assert(self.signature==string.char(137, 80, 78, 71, 13, 10, 26, 10), "invalid PNG signature")
	self 'chunks' ('array', '*', 'png_chunk')
end

function fstruct.png_chunk_raw(self)
	self 'length' ('uint32', 'be')
	self 'type' ('bytes', 4)
	self 'data' ('bytes', self.length)
	self 'crc' ('bytes', 4)
end

function read.png_chunk(stream)
	local raw = read.png_chunk_raw(stream)
	assert(crc(raw.type..raw.data)==raw.crc, "invalid chunk CRC")
	local read_data = read["png_"..raw.type.."_chunk"]
	if read_data then
		local err
		raw.data,err = read_data(serial.buffer(raw.data))
		if not raw.data then return nil,err end
	end
	return {
		type = raw.type,
		data = raw.data,
	}
end

function serialize.png_chunk(chunk)
	local raw,err = {}
	raw.type = chunk.type
	raw.data = chunk.data
	local serialize_data = serialize["png_"..raw.type.."_chunk"]
	if serialize_data then
		raw.data,err = serialize_data(raw.data)
		if not raw.data then return nil,err end
	end
	raw.length = #raw.data
	raw.crc = crc(raw.type..raw.data)
	return serialize.png_chunk_raw(raw)
end

struct.png_IHDR_chunk = {
	{'width',				'uint32', 'be'},
	{'height',				'uint32', 'be'},
	{'bit_depth',			'uint8'}, -- various restrictions depending on color_type
	{'color_type',			'flags', png_color_type, 'uint8'}, -- can only be 0, 2, 3, 4 or 6
	{'compression_method',	'enum', png_compression_method, 'uint8'},
	{'filter_method',		'enum', png_filter_method, 'uint8'},
	{'interlace_method',	'enum', png_interlace_method, 'uint8'},
}

struct.png_PLTE_color = {
	{'red',		'uint8'},
	{'green',	'uint8'},
	{'blue',	'uint8'},
}

alias.png_PLTE_chunk = {'array', '*', 'png_PLTE_color'}

--alias.png_IDAT_chunk = {'bytes', '*'}

struct.png_IEND_chunk = {}

--struct.png_tRNS_chunk = {}

function read.scaled(stream, scale, int_t, ...)
	if type(int_t)~='table' or select('#', ...)>=1 then
		int_t = {int_t, ...}
	end
	local read = assert(read[int_t[1]], "unknown int type "..tostring(int_t[1]).."")
	local value,err = read(stream, unpack(int_t, 2))
	if not value then return nil,err end
	return value / scale
end

function serialize.scaled(value, scale, int_t, ...)
	if type(int_t)~='table' or select('#', ...)>=1 then
		int_t = {int_t, ...}
	end
	local serialize = assert(serialize[int_t[1]], "unknown int type "..tostring(int_t[1]).."")
	return serialize(value * 100000, unpack(int_t, 2))
end

alias.png_gAMA_chunk = {'scaled', 100000, 'uint32', 'be'}

struct.png_cHRM_chunk = {
	{'white_point_x', 'scaled', 100000, 'uint32', 'be'},
	{'white_point_y', 'scaled', 100000, 'uint32', 'be'},
	{'red_x', 'scaled', 100000, 'uint32', 'be'},
	{'red_y', 'scaled', 100000, 'uint32', 'be'},
	{'green_x', 'scaled', 100000, 'uint32', 'be'},
	{'green_y', 'scaled', 100000, 'uint32', 'be'},
	{'blue_x', 'scaled', 100000, 'uint32', 'be'},
	{'blue_y', 'scaled', 100000, 'uint32', 'be'},
}

--struct.png_sRGB_chunk = {}
--struct.png_iCCP_chunk = {}

struct.png_iTXt_chunk = {
	{'keyword',				'cstring'},
	{'compression_flag',	'uint8'},
	{'compression_method',	'uint8'},
	{'language_tag',		'cstring'},
	{'translated_keyword',	'cstring'},
	{'text',				'bytes', '*'},
}

struct.png_tEXt_chunk = {
	{'keyword', 'cstring'},
	{'text', 'bytes', '*'},
}

--struct.png_zTXt_chunk = {}
--struct.png_bKGD_chunk = {}
--struct.png_pHYs_chunk = {}
--struct.png_sBIT_chunk = {}
--struct.png_sPLT_chunk = {}
--struct.png_hIST_chunk = {}

struct.png_tIME_chunk = {
	{'year',	'uint16', 'be'},
	{'month',	'uint8'},
	{'day',		'uint8'},
	{'hour',	'uint8'},
	{'minute',	'uint8'},
	{'second',	'uint8'},
}

