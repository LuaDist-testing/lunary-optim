require 'serial'

local enum_dict = {
	name1 = 1, [1] = 'name1',
	name2 = 2, [2] = 'name2',
}

local flags_dict = {
	flag1 = 1,
	flag2 = 2,
	flag3 = 4,
	flag12 = 1 + 2,
}

local buffer_string = "Hello World!"

local struct_desc = {
	{'name', 'cstring'},
	{'value', 'uint32', 'le'},
}

local fstruct_closure1 = function(value, declare_field)
	declare_field('name', 'cstring')
	declare_field('value', 'uint32', 'le')
end

local fstruct_closure2 = function(self)
	self 'name' ('cstring')
	self 'value' ('uint32', 'le')
end

local object = {
	name = "foo",
	value = 42,
}


local tests = {
	{{'uint8'}, 0x00, string.char(0x00)},
	{{'uint8'}, 0x00, string.char(0x00)},
	{{'uint8'}, 0x55, string.char(0x55)},
	{{'uint8'}, 0xaa, string.char(0xaa)},
	{{'uint8'}, 0xff, string.char(0xff)},

	{{'sint8'}, -128, string.char(0x80)},
	{{'sint8'}, -1, string.char(0xff)},
	{{'sint8'}, 0, string.char(0x00)},
	{{'sint8'}, 1, string.char(0x01)},
	{{'sint8'}, 127, string.char(0x7f)},

	{{'uint16', 'le'}, 0xbeef, string.char(0xef, 0xbe)},
	{{'uint16', 'be'}, 0xbeef, string.char(0xbe, 0xef)},

	{{'sint16', 'be'}, -32768, string.char(0x80, 0x00)},
	{{'sint16', 'be'}, -1, string.char(0xff, 0xff)},
	{{'sint16', 'be'}, 0, string.char(0x00, 0x00)},
	{{'sint16', 'be'}, 1, string.char(0x00, 0x01)},
	{{'sint16', 'be'}, 32767, string.char(0x7f, 0xff)},

	{{'uint32', 'le'}, 0xdeadbeef, string.char(0xef, 0xbe, 0xad, 0xde)},
	{{'uint32', 'be'}, 0xdeadbeef, string.char(0xde, 0xad, 0xbe, 0xef)},

	{{'sint32', 'be'}, -2147483648, string.char(0x80, 0x00, 0x00, 0x00)},
	{{'sint32', 'be'}, -1, string.char(0xff, 0xff, 0xff, 0xff)},
	{{'sint32', 'be'}, 0, string.char(0x00, 0x00, 0x00, 0x00)},
	{{'sint32', 'be'}, 1, string.char(0x00, 0x00, 0x00, 0x01)},
	{{'sint32', 'be'}, 2147483647, string.char(0x7f, 0xff, 0xff, 0xff)},

	{{'uint64', 'le'}, 0x0010feed * 2^32 + 0xdeadbeef, string.char(0xef, 0xbe, 0xad, 0xde, 0xed, 0xfe, 0x10, 0x00)},
	{{'uint64', 'be'}, 0x0010feed * 2^32 + 0xdeadbeef, string.char(0x00, 0x10, 0xfe, 0xed, 0xde, 0xad, 0xbe, 0xef)},

	{{'enum', enum_dict, {'uint8'}}, 'name1', string.char(0x01)},
	{{'enum', enum_dict, 'uint16', 'le'}, 'name2', string.char(0x02, 0x00)},

	{{'sizedbuffer', 'uint8'}, buffer_string, string.char(#buffer_string)..buffer_string},

	{{'array', 2, 'uint8'}, {42, 37}, string.char(42, 37)},
	{{'array', 4, 'uint16', 'be'}, {0xdead, 0xbeef, 0xd00d, 0xface}, string.char(0xde, 0xad, 0xbe, 0xef, 0xd0, 0x0d, 0xfa, 0xce)},

	{{'sizedvalue', {'uint8'}, 'uint64', 'le'}, 42, string.char(8, 42, 0, 0, 0, 0, 0, 0, 0)},
	{{'sizedvalue', {'uint16', 'le'}, 'cstring'}, buffer_string, string.char(#buffer_string+1, 0)..buffer_string..'\0'},
	{{'sizedvalue', {'uint8'}, 'struct', struct_desc}, object, string.char(8).."foo"..'\0'..string.char(42, 0, 0, 0)},

	{{'sizedarray', {'uint16', 'le'}, 'uint8'}, {42, 37}, string.char(2, 0, 42, 37)},

	{{'cstring'}, buffer_string, buffer_string..'\0'},

	{{'bytes', #buffer_string}, buffer_string, buffer_string},

	{{'bytes2hex', 4}, "deadbeef", string.char(0xde, 0xad, 0xbe, 0xef)},

	{{'bytes2base32', 5}, "deadbeef", string.char(0x19, 0x00, 0x30, 0x90, 0x85)},

	{{'boolean8'}, false, string.char(0x00)},
	{{'boolean8'}, true, string.char(0x01)},

	{{'boolean', 'uint16', 'le'}, false, string.char(0x00, 0x00)},
	{{'boolean', 'uint16', 'be'}, true, string.char(0x00, 0x01)},

	{{'struct', struct_desc}, object, "foo"..'\0'..string.char(42, 0, 0, 0)},

	{{'fstruct', fstruct_closure1}, object, "foo"..'\0'..string.char(42, 0, 0, 0)},

	{{'fstruct', fstruct_closure2}, object, "foo"..'\0'..string.char(42, 0, 0, 0)},
}

if pcall(require, 'bit') then

tests[#tests+1] = {{'flags', flags_dict, {'uint8'}}, {flag1=true}, string.char(0x01)}
tests[#tests+1] = {{'flags', flags_dict, 'uint8'}, {flag1=true, flag3=true}, string.char(0x05)}
tests[#tests+1] = {{'flags', flags_dict, 'uint16', 'le'}, {flag2=true, flag12=true}, string.char(0x03, 0x00)}

end

if pcall(require, 'struct') then

tests[#tests+1] = {{'float', 'le'}, 42.37, string.char(0xe1, 0x7a, 0x29, 0x42)}
tests[#tests+1] = {{'float', 'be'}, 42.37, string.char(0x42, 0x29, 0x7a, 0xe1)}
tests[#tests+1] = {{'double', 'le'}, 42.37, string.char(0x8F, 0xC2, 0xF5, 0x28, 0x5C, 0x2F, 0x45, 0x40)}
tests[#tests+1] = {{'double', 'be'}, 42.37, string.char(0x40, 0x45, 0x2F, 0x5C, 0x28, 0xF5, 0xC2, 0x8F)}

end

for _,test in ipairs(tests) do
	assert(serial.serialize[test[1][1]](test[2], unpack(test[1], 2))==test[3], "could not serialize value "..tostring(test[2]).." with type "..test[1][1]--[[..(#test[1]>1 and " ("..table.concat(test[1], ", ", 2, #test[1])..")" or "")]])
	assert(serial.read[test[1][1]](serial.buffer(test[3]), unpack(test[1], 2))~=nil, "could not deserialize value "..tostring(test[2]).." with type "..test[1][1]--[[..(#test[1]>1 and " ("..table.concat(test[1], ", ", 2, #test[1])..")" or "")]])
end

print("All tests passed successfully.")

--[[
Copyright (c) 2009 Jérôme Vuarand

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
