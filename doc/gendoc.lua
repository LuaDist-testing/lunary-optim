require 'markdown'

local charset = 'UTF-8'
local file_index = "index.html"
local file_manual = "manual.html"
local file_examples = "examples.html"

-- generate logo
os.execute('convert -resize 384x384 logo.ps -crop 256x128+64+0 logo.png')

------------------------------------------------------------------------------

local file

local function output(filename)
	file = io.open(filename, "wb")
end

function print(...)
	local t = {...}
	for i=1,select('#', ...) do
		t[i] = tostring(t[i])
	end
	file:write(table.concat(t, '\t')..'\n')
end

function header()
	print([[
<?xml version="1.0" encoding="]]..charset..[["?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en"
lang="en">
<head>
<title>Lunary</title>
<meta http-equiv="Content-Type" content="text/html; charset=]]..charset..[["/>
<link rel="stylesheet" href="doc.css" type="text/css"/>
</head>
<body>
]])
	print([[
<div class="chapter" id="header">
<img width="256" height="128" alt="Lunary" src="logo.png"/>
<p>A binary format I/O framework for Lua</p>
<p class="bar">
<a href="]]..file_index..[[">home</a> &middot;
<a href="]]..file_index..[[#download">download</a> &middot;
<a href="]]..file_index..[[#installation">installation</a> &middot;
<a href="]]..file_manual..[[">manual</a> &middot;
<a href="]]..file_examples..[[">examples</a>
</p>
</div>
]])
end

function footer()
	print([[
<div class="chapter" id="footer">
<small>Last update: ]]..os.date"%Y-%m-%d %H:%M:%S %Z"..[[</small>
</div>
]])
	print[[
</body>
</html>
]]
end

local chapterid = 0

function chapter(id, title, text, sections, raw)
	chapterid = chapterid+1
	local text = text:gsub("%%chapterid%%", tostring(chapterid))
	if not raw then
		text = markdown(text)
	end
	if sections then
		for _,section in ipairs(sections) do
			section = section:gsub("%%chapterid%%", tostring(chapterid))
			text = text..[[
<div class="section">
]]..markdown(section)..[[
</div>]]
		end
	end
	print([[
<div class="chapter">
<a id="]]..id..[["/><h1>]]..tostring(chapterid).." - "..title..[[</h1>
]]..text..[[
</div>
]])
end

------------------------------------------------------------------------------

output(file_index)

header()

chapter('about', "About Lunary", [[
Lunary is a framework to read and write structured binary data from and to files or network connections. The aim is to provide an easy to use interface to describe any complex binary format, and allow translation to Lua data structures. The focus is placed upon the binary side of the transformation, and further processing may be necessary to obtain the desired Lua structures. On the other hand Lunary should allow reading and writing of any binary format, and bring all the information available to the Lua side.

All built-in data types preserve all the information they read from the streams. This allows reserializing an object even if it's not manipulable by Lua (e.g. an `uint64` not fitting in a Lua `number` will be represented by a `string`, an `enum` which integer value is not named will be passed as a `number`). User application or custom formats are required to remove themselves any unnecessary information (invalid value, ordering of entries in a set or a map, etc.).

Lunary name is based on the contraction of Lua and binary, and it sounds moon-themed (it is close to the lunar adjective).

## Support

All support is done through the [Lua mailing list](http://www.lua.org/lua-l.html). If the traffic becomes too important a specialized mailing list will be created.

Feel free to ask for further developments, especially new data types. I can't guarantee that I'll develop everything you ask, but I want my code to be as useful as possible, so I'll do my best to help you. You can also send me request or bug reports (for code and documentation) directly at [jerome.vuarand@gmail.com](mailto:jerome.vuarand@gmail.com).

## Credits

This module is written and maintained by [Jérôme Vuarand](mailto:jerome.vuarand@gmail.com).

Lunary is available under a [MIT-style license](LICENSE.txt).

## To do

Here are some points that I'm going to improve in the near future:

- better document errors thrown/returned by the library
- complete the 'uint' and 'sint' datatypes (only reading is possible so far)
- add a "tagged value" datatype
- merge 'bytes' and 'sizedbuffer', 'array' and 'sizedarray'
- add a 'deflated' datatype based on zlib

]])

chapter('download', "Download", [[
Lunary sources are available in its [Mercurial repository](http://hg.piratery.net/lunary/):

    hg clone http://hg.piratery.net/lunary/

Tarballs of the latest code can be downloaded directly from there: as [gz](http://hg.piratery.net/lunary/get/tip.tar.gz), [bz2](http://hg.piratery.net/lunary/get/tip.tar.bz2) or [zip](http://hg.piratery.net/lunary/get/tip.zip).

Finally, I published some rockspecs. To get a full Lunary (with optional dependencies), simply run:

    luarocks install lunary

If you're on a platform without a C compiler, and no pre-built rocks are available, you can still get most of the Lunary functionality with its pure-Lua core:

    luarocks install lunary-core
]])

chapter('installation', "Installation", [[
Lunary consists of two Lua modules named `serial` and `serial.util`. There is a also an optional `serial.optim` binary module which replace some functions of `serial.util` with optimized alternatives to improve Lunary performance.

A simple makefile is provided. The `build` target builds the `serial.optim` binary module. The `install` target installs all the Lunary modules to the `PREFIX` installation path, which is defined in the Makefile and can be overridden with an environment variable. The `installpure` target only install pure Lua modules, it can be used on platforms where compiling or using C modules is problematic.

Finally note that Lunary has some optional dependencies. If the dependency is not available, the data types using them will not be available to Lunary users. Here are the data types with dependencies:

- the `float` and `double` data types uses [Roberto Ierusalimschy's struct library](http://www.inf.puc-rio.br/~roberto/struct/) to serialize native floating point numbers. The library is available at [http://www.inf.puc-rio.br/~roberto/struct/](http://www.inf.puc-rio.br/~roberto/struct/).
- the `flags` data type uses the [BitOp library](http://bitop.luajit.org/) for bit-wise boolean operations. The library is available at [http://bitop.luajit.org/](http://bitop.luajit.org/).

Note than many other libraries have similar functionality. I wouldn't mind adding support for some of these, just ask.]])

footer()

------------------------------------------------------------------------------

output(file_manual)

header()

local manual = [[

## %chapterid%.1 - General library description

The Lunary framework is organized as a collection of data type descriptions. Basic data types include for example 8-bit integers, C strings, enums. Each data type has a unique name, and can have parameters. Data types can be described by different means. Ultimately, each data type will be manipulated with three functions, named according to the data type, and located in the following tables: `serial.read`, `serial.serialize` and `serial.write`.

`serial.read` contains functions that can be used to read a data object, of a given data type, from a data stream. For example the function `serial.read.uint8` can be used to read an unsigned 8 bit integer number. The general function prototype is:

    function serial.read.<type name>(<stream>, [type parameters])

For a description of the stream object, see the *Streams* section below. The type parameters are dependent on the data type, and may be used to reduce the overall number of data types and group similar types. A data type can have any number of type parameters. For example, Lunary provides a single `uint32` data type, but support both big-endian and little-endian integers. The endianness is specified as the first type parameter.

`serial.serialize` functions that can be used to serialize a data object into a byte string. The general function prototype is:

    function serial.serialize.<type name>(<value>, [type parameters])

Finally `serial.write` contains functions that can be used to write a data object to a data stream. The general function prototype is:

    function serial.write.<type name>(<stream>, <value>, [type parameters])

The `serial.serialize` and `serial.write` tables are a little redundant. It is possible to create a `write` function from a `serialize` function, and vice versa. Actually, when implementing data types, it is not necessary to provide both of these functions. The other one will be automatically generated by Lunary if missing. However, when using complex data types, depending on the situation one function may be faster than the other. So when performance becomes important, it is a good idea to provide both a `write` and a `serialize` function for your new data types.

## %chapterid%.2 - Streams

The Lunary framework manipulate *stream* objects. When serializing, Lunary will push data to a stream. When deserializing, Lunary will get data from the stream. Stream objects as used by Lunary should be Lua objects (implemented with any indexable Lua type), which provide methods. The methods to implement depend on the serialization functions used, and on the data type that is serialized. For basic data types, the `serial.write` functions expect a `putbytes` method, and the `serial.read` functions expect a `getbytes` methods, defined as:

    function stream:putbytes(data)
    function stream:getbytes(nbytes)

where `data` is a Lua string containing the bytes to write to the stream, `nbytes` is number of bytes to read from the stream. `stream:putbytes` should return the number of bytes actually written, while `stream:getbytes` will return the requested bytes as a string, eventually less than requested in the case of end-of-stream. In case of error, both functions should return nil followed by an error message.

One other methods used by some data types described below is `length`:

    function stream:length()

The `length` method returns the number of bytes available in the stream. For network sockets, this makes no sense, but that information is available for file and buffer streams. That method is used by some data types which serialized length cannot be inferred from the type description or content. For example array running to the end of the file or file section need that method when reading a stream.

As a convenience, and because these are the data interfaces most often used with Lunary, wrappers for Lua files, LuaSocket TCP sockets and simple string buffers are provided. For more information, see `serial.buffer`, `serial.filestream` and `serial.tcpstream` below.

As you can guess from the stream API we just described, the Lunary library is not currently capable of reading or writing data types that are not a multiple of a byte. As a consequence, since there is no way to read anything below 8 bits at once, bit order within a byte is never specified as a type parameter, as opposed to byte order within multi byte types.

## %chapterid%.3 - Compound data types

Lunary provides several basic data types, and some more complex compound data types. These types are generally more complicated to use, this section provides details about them.

### %chapterid%.3.1 - Type description as type parameters

Most of these compound data types contain sub-elements, but are described in the Lunary source code in a generic way. To use them with a given type for their sub-elements, one or more type descriptors has to be given as their type parameters. A type descriptor is a Lua array, with the first array element being the type name, and subsequent array elements being the type parameters. For example `{'uint32', 'le'}` is a type descriptor for a little-endian 32-bits unsigned integer.

When the last type parameter of a Lunary data type is a type descriptor, the descriptor can be passed unpacked as final type parameters. For example:

    serial.read.array(stream, 16, {'uint32', 'le'})

is equivalent to:

    serial.read.array(stream, 16, 'uint32', 'le')

### %chapterid%.3.2 - Naming `struct`-based and `fstruct`-based data types, aliases

The `struct` and `fstruct` data types (as described below) are very handy to describe complex compound types. However, when such types are reused in several part of more complex data types, or in several root data types (like in several file formats), it may be handy to refer to them with names. The basic way to do it is to store the type parameters in Lua variables. For example one can write:

    local attribute = {
        {'name', 'cstring'},
        {'value', 'uint32', 'le'},
    }
    serial.read.struct(stream, attribute)

To build complex structs containing other structs, this may not be very handy. Lunary provides a way to define named data types. To do that three tables in the `serial` module are available: `serial.struct`, `serial.fstruct` and `serial.alias`. The first two are used to create named types based on structs and fstructs respectively, while the last one is used to give a name to any type. For example, the above `attribute` data type can be created like that:

    serial.struct.attribute = {
        {'name', 'cstring'},
        {'value', 'uint32', 'le'},
    }

This will automatically generate `read`, `serialize` and `write` functions for that type, which can be used as follows:

    serial.read.attribute(stream)

The `fstruct` table works similarly for fstructs (see the description of the `fstruct` data type below).

Finally the `alias` table will contain type description arrays as expected by the `array` or `sizedarray` data types, and described above. For example, if your data type often contains 32-byte long character strings, you can define an alias as follows:

    serial.alias.string32 = {'bytes', 32}

You can then read such strings with the `serial.read.string32` function, or even include that new data type in compounds types, for example:

    serial.struct.record = {
        {'artist', 'string32'},
        {'title', 'string32'},
        {'genre', 'string32'},
    }

---

## %chapterid%.4 - Function reference

### serial.buffer (data)

This function will create an input stream object based on a Lua string. It implements the `getbytes` and `putbytes` methods. It is used to deserialize an object from an in-memory byte buffer. To serialize an object in-memory, you can simply use the Lunary `serial.serialize` functions which will generate a Lua string.

### serial.filestream (file)

This function will create a stream object based on a standard Lua file object. It will indirectly map its `getbytes`, `putbytes` and `length` methods to the `read`, `write` and `seek` methods of the file object.

### serial.tcpstream (sock)

This function will create a stream object based on a LuaSocket TCP socket object. It will indirectly map its `getbytes` and `putbytes` methods to the `receive` abd `send` methods of the socket object.

### serial.util.enum (half_enum)

This function creates an enum as used by the `enum` data type. `half_enum` is a table containing one half of an enum descriptor, usually a simple mapping between names and values. It will create a new table, containing a bidirectional mapping between names and values, and values and names.

---

## %chapterid%.5 - Data type reference

Here is a description of the built-in data types provided with Lunary. Some of these types take type descriptors as parameter (as described above). They are usually denoted with a `_t` suffix in the parameter name.
]]


local types = { {
	name = 'uint8',
	params = {},
	doc = [[
An 8-bit unsigned integer.

In Lua it is stored as a regular `number`. When serializing, overflows and loss of precision are ignored.]],
}, {
	name = 'sint8',
	params = {},
	doc = [[
An 8-bit signed integer.

In Lua it is stored as a regular `number`. When serializing, overflows and loss of precision are ignored.]],
}, {
	name = 'uint16',
	params = {'endianness'},
	doc = [[
A 16-bit unsigned integer. The `endianness` type parameters specifies the order of bytes in the stream. It is a string which can be either `'le'` for little-endian (least significant byte comes first), or `'be'` for big-endian (most significant byte comes first).

In Lua it is stored as a regular `number`. When serializing, overflows and loss of precision are ignored.]],
}, {
	name = 'sint16',
	params = {'endianness'},
	doc = [[
A 16-bit signed integer. The `endianness` type parameters specifies the order of bytes in the stream. It is a string which can be either `'le'` for little-endian (least significant byte comes first), or `'be'` for big-endian (most significant byte comes first).

In Lua it is stored as a regular `number`. When serializing, overflows and loss of precision are ignored.]],
}, {
	name = 'uint32',
	params = {'endianness'},
	doc = [[
A 32-bit unsigned integer. The `endianness` type parameters specifies the order of bytes in the stream. It is a string which can be either `'le'` for little-endian (least significant byte comes first), or `'be'` for big-endian (most significant byte comes first).

In Lua it is stored as a regular `number`. When serializing, overflows and loss of precision are ignored.]],
}, {
	name = 'sint32',
	params = {'endianness'},
	doc = [[
A 32-bit signed integer. The `endianness` type parameters specifies the order of bytes in the stream. It is a string which can be either `'le'` for little-endian (least significant byte comes first), or `'be'` for big-endian (most significant byte comes first).

In Lua it is stored as a regular `number`. When serializing, overflows and loss of precision are ignored.]],
}, {
	name = 'uint64',
	params = {'endianness'},
	doc = [[
A 64-bit unsigned integer. The `endianness` type parameters specifies the order of bytes in the stream. It is a string which can be either `'le'` for little-endian (least significant byte comes first), or `'be'` for big-endian (most significant byte comes first).

In Lua it is stored as a regular `number`. When serializing, overflows and loss of precision are ignored. When reading however, if the integer overflows the capacity of a Lua `number`, it is returned as a 8-byte string. Therefore `serialize` and `write` functions accept a string as input. When the `uint64` is a `string` on the Lua side it is always in little-endian order (ie. the string is reversed before writing or after reading if `endianness` is `'be'`).]],
}, {
	name = 'sint64',
	params = {'endianness'},
	doc = [[
A 64-bit signed integer. The `endianness` type parameters specifies the order of bytes in the stream. It is a string which can be either `'le'` for little-endian (least significant byte comes first), or `'be'` for big-endian (most significant byte comes first).

In Lua it is stored as a regular `number`. When serializing, overflows and loss of precision are ignored. When reading however, if the integer overflows the capacity of a Lua `number`, it is returned as a 8-byte string. Therefore `serialize` and `write` functions accept a string as input. When the `uint64` is a `string` on the Lua side it is always in little-endian order (ie. the string is reversed before writing or after reading if `endianness` is `'be'`).]],
}, {
	name = 'enum',
	params = {'dictionary', 'int_t'},
	doc = [[
The `enum` data type is similar to the C enum types. Its first type parameter, `dictionary`, is a mapping between names and data (typically number values). It should be a Lua indexable type, like a `table`, with two key-value pairs for each mapping, one with the name as a key and the data as value, and one with the data as key and the name as value. This implies that a name has a single associated data and a given data has a single name.

The Lua side manipulates the name, and when serialized its associated data is stored in the stream. The `enum` data type is transparent, and can accept any Lua type as either name or data. A typical scenario will have `string` names and integer `number` data.

Since the names are only used as key or values of the `dictionary`, they can be any Lua value except `nil`. However, the data associated to the name must be serializable. For that reason, the second type parameter of `enum`, `int_t`, is a type description of the data. It is used to serialize the data into streams. A data can therefore be any Lua type except `nil`, provided a suitable type description for serialization.]],
}, {
	name = 'flags',
	params = {'dictionary', 'int_t'},
	doc = [[
The `flags` data type is similar to the `enum` type, with several differences though. This data type represents the combination of several names. Instead of a single name `string`, the Lua side will manipulate a set of names, represented by a `table` with names as keys, and `true` as the associated value. On the stream side however all the data associated with the names of the set are combined. To do so, the data must be integers, and they will be combined with the help of the [BitOp library](http://bitop.luajit.org/). For that reason, the `int_t` type description has to serialize Lua numbers.

When serializing, the Lua numbers associated with each name of the set are combined with the bit.bor function, to produce a single number, which will then be serialized according to the `int_t` type description.

When reading, a single number is read according to `int_t`. Then, the data of each pair of the dictionary is tested against the number with the bit.band function, and if the result is non-zero the name if the pair is inserted in the output set. For that reason, the dictionary is a little different than in the `enum` data type case. First, it must be enumerable using the standard `pairs` Lua functions. It should thus be a Lua table, unless the `pairs` global is overridden. Second, only one direction of mapping is necessary, ie. the pairs with the name as key and the data as value. This also means that several names can have the same values. If that is the case, all the matching names will be present in the output set.]],
}, {
	name = 'char',
	params = {},
	doc = [[
This is a simple 1 byte value. The data is a `string` in Lua. When serializing or writing, the string passed should have a length of 1 otherwise an error is thrown.]],
}, {
	name = 'bytes',
	params = {'count'},
	doc = [[
This is a simple constant-size byte sequence. The size is passed in the `count` type parameter. The data is a `string` in Lua. When serializing or writing, the string passed should have the proper length otherwise an error is thrown.

The `count` type parameter can have a special value, the string `'*'`. When serializing or writing, the input string is serialized as-is, in its full length. When reading though, since there is no way to know how many elements to read, the stream is read until its end. For that reason the stream must implement a `'length'` method, which returns the number of bytes remaining in the stream. Contrary to the `array` data type (see below), when using `'*'` with `bytes` the `length` method of the stream should be accurate, it should be 0 when the end of the stream is reached, and the actual number of remaining bytes otherwise.]],
}, {
	name = 'sizedbuffer',
	params = {'size_t'},
	doc = [[
This is a simple byte buffer prefixed with a size. The size is serialized by the `size_t` type description. On the Lua side the buffer is a `string`, and its size is available through the Lua `#` operator. This type is similar to a `sizedarray` with a `value_t` of `uint8`, except that the array is not unpacked in a Lua array, it stays a Lua string. This is useful to store strings with embedded zeros.]],
}, {
	name = 'array',
	params = {'size', 'value_t'},
	doc = [[
The array data type is a fixed size array of values. The size of the array is the first type parameter. As such it is not stored in the stream. The values are passed as a Lua array, which is expected to be of the right size when serializing or writing. The values are serialized according to the `value_t` type descriptor.

The `size` type parameter can have a special value, the string `'*'`. When serializing or writing, all the elements of the input array are serialized. When reading though, since there is no way to know how many elements to read, the stream is read until its end. For that reason the stream must implement a `'length'` method, which returns the number of bytes remaining in the stream. Actually the value can be inaccurate, it should be 0 or less when the end of the stream is reached, and a positive value otherwise.

For variable size array, but when some size information is stored in the stream, the `'*'` special `size` by itself is usually not the way to go. Instead, if the size is expressed in the number elements before the array, you can use the `sizedarray` data type. If the size is expressed as a number of bytes, you can use the `sizedvalue` data type in conjunction with the `array` type and a `'*'` size. Finally when the size is not stored directly before the array, you can use the `fstruct` data type and use a struct field as the `array` type parameter.]],
}, {
	name = 'sizedarray',
	params = {'size_t', 'value_t'},
	doc = [[
A `sizedarray` is an array with its size stored in the stream before it, so it can be read efficiently and at any position inside the stream. The size comes first in the stream, described by `size_t`. Then follows a sequence of elements of that size, each element being described by `value_t`.]],
}, {
	name = 'sizedvalue',
	params = {'size_t', 'value_t'},
	doc = [[
This data type has two modes, depending on the `size_t` type parameter.

If the `size_t` type parameter is a type descriptor, this data type consist of the concatenation of another value and its size. In the stream the size is stored first, according to the `size_t` type descriptor. It is followed by the value, described by `value_t`.

If the `size_t` type parameter is a number, it is interpreted as the constant size of another value. In the stream, only the other value is serialized, according to the `value_t` type descriptor. On write, the value is first completely serialized to check that its size matches `size_t`. On read, `size_t` bytes are first read, and the value is deserialized from these bytes.

This type has to be handled with care. When serializing, the value has to be serialized in its entirety before being returned or written, so that its size can be computed. This means its serialized version will exist completely in memory.

On the other hand, when reading the value, the whole serialized value is first read into a temporary memory buffer. Then, when deserializing the value itself, it is deserialized from a temporary buffer stream created on the fly, which have a length method, and so even if the stream from which the `sizedvalue` is read hasn't one. This means the value can have a pseudo-infinite data type (like the `array` type with a `'*'` size, or a `struct` ending with one), even if there are additional data after the `sizedvalue`.]],
}, {
	name = 'cstring',
	params = {},
	doc = [[
A `cstring` stores a Lua string unmodified, terminated by a null byte. Since no other size information is stored in the stream or provided as a type parameter, the serialized string cannot contain embedded null bytes. This type is useful to store text strings.]],
}, {
	name = 'float',
	params = {'endianness'},
	doc = [[
This data type stores a 32 bits floating point number, using the [struct library](http://www.inf.puc-rio.br/~roberto/struct/). The type is therefore only available if the library is available. Like integer types, the `endianness` type parameters specifies the byte order in the stream: `'le'` stands for little-endian (least significant byte comes first), and `'be'` stands for big-endian (most significant byte comes first). A Lua number is simply serialized using the struct library type format `"<f"` in little-endian mode, and `">f"` in big-endian mode.]],
}, {
	name = 'double',
	params = {'endianness'},
	doc = [[
This data type stores a 64 bits floating point number, using the [struct library](http://www.inf.puc-rio.br/~roberto/struct/). The type is therefore only available if the library is available. Like integer types, the `endianness` type parameters specifies the byte order in the stream: `'le'` stands for little-endian (least significant byte comes first), and `'be'` stands for big-endian (most significant byte comes first). A Lua number is simply serialized using the struct library type format `"<d"` in little-endian mode, and `">d"` in big-endian mode.]],
}, {
	name = 'bytes2hex',
	params = {'count'},
	doc = [[
This data type represents a sequence of 4-bits numbers concatenated in a byte string. Each byte contains two 4-bit numbers. Within the bytes bits are considered to be in the big-endian order. It means the most significant 4 bits of the byte contain the first number of the byte. Each number is converted to an hexadecimal number.]],
}, {
	name = 'bytes2base32',
	params = {'count'},
	doc = [[
This data type represents a sequence of 5-bits numbers concatenated in a byte string. Each group of height 5-bits number spans over five bytes. Each byte contains bits for two to three 5-bit numbers. Within the bytes bits are considered to be in the big-endian order. It means that when a number spans two bytes, its most significant bits are the least significant bits of the first byte, and its least significant bits are the most significant bits of the second byte.

Each 5-bit number is converted to a single character with the following mapping:

<table>
<tbody><tr><td><ul>
<li>0 is 'A'</li>
<li>1 is 'B'</li>
<li>2 is 'C'</li>
<li>3 is 'D'</li>
<li>4 is 'E'</li>
<li>5 is 'F'</li>
<li>6 is 'G'</li>
<li>7 is 'H'</li>
</ul></td><td><ul>
<li>8 is 'I'</li>
<li>9 is 'J'</li>
<li>10 is 'K'</li>
<li>11 is 'L'</li>
<li>12 is 'M'</li>
<li>13 is 'N'</li>
<li>14 is 'O'</li>
<li>15 is 'P'</li>
</ul></td><td><ul>
<li>16 is 'Q'</li>
<li>17 is 'R'</li>
<li>18 is 'S'</li>
<li>19 is 'T'</li>
<li>20 is 'U'</li>
<li>21 is 'V'</li>
<li>22 is 'W'</li>
<li>23 is 'X'</li>
</ul></td><td><ul>
<li>24 is 'Y'</li>
<li>25 is 'Z'</li>
<li>26 is '2'</li>
<li>27 is '3'</li>
<li>28 is '4'</li>
<li>29 is '5'</li>
<li>30 is '6'</li>
<li>31 is '7'</li>
</ul></td></tr></tbody>
</table>

]],
}, {
	name = 'boolean',
	params = {'int_t'},
	doc = [[
This type stores a boolean value in an integer. The integer type is described by `int_t`. The integer is 1 for `true`, 0 for `false`. When reading, if the integer is neither 1 nor 0, it is returned as is, as a Lua `number`. Therefore for symmetry it is possible to pass a `number` when serializing a `boolean`.]],
}, {
	name = 'struct',
	params = {'fields'},
	doc = [[
The `struct` data type can describe complex compound data types, like C structs. Like C structs, it is described by a sequence of named fields. The `fields` type parameter is an array, each element defining a field with a sub-array. This sub-array first element is the field name, the second element is the field type, and all subsequent elements are the type parameters. For example, here is the description of a `struct` with two fields, a `cstring` name and an `uint32` value:

    local attribute = {
        {'name', 'cstring'},
        {'value', 'uint32', 'le'},
    }
    return serial.read.struct(stream, attribute)
]],
}, {
	name = 'fstruct',
	params = {'f', '...'},
	doc = [[
The `fstruct`, a shortcut for *function-struct*, is the most complex data type provided by Lunary. When a data type is too complex to be described by any predefined data type, or a compound of them assembled with the `struct` data type, you usually have to provide low level serialization functions. This means you have to write a `read` function and either a `write` or a `serialize` function. However for many data types, there is some redundancy between the read and the write parts.

The `fstruct` data type is meant to alleviate this redundancy when possible. Like its simpler `struct` cousin, it is used to describe C-like structs. Therefore, the serialized value will always be a Lua object (created as a table). However, its main type parameter, `f`, is a function (or any callable Lua type) which is called both for serialization and deserialization. Its prototype is as follows:
	
    function f(value, declare_field)
	
For that function to describe the structure fields, it receives two special parameters that will be used to describe the type. The first parameter `value` is the object being serialized itself, usually a Lua table. It is passed both when serializing and deserializing the object, this means that its content can be queried at any moment to influence the serialized data format. The second parameter, `declare_field`, is a function which can be used to declare a field. That function will have a different effect depending on whether is currently serializing or deserializing the object. The `declare_field` prototype is as follows:

    function declare_field(name, type, ...)

The `name` parameter is the field name. The `type` parameter is the field Lunary type name. The additionnal parameters are passed to the field type as type parameters.

What is important to keep in mind, is that you can use all Lua control flow structures within the `f` function. Also since `declare_field` is called for each field of the object every time the object is serialized or deserialized, all its parameters can be dependent on the object content. Let's take a simple example. The following `fstruct` type function describe a *attribute* type which have three fields: a *name*, a *value*, and a *version*. Additionnaly, if the *version* is greater than or equal to 2, the attribute have a *comment* field:

    local attribute = function(value, declare_field)
        declare_field('version', 'uint32', 'le')
        declare_field('name', 'cstring')
        declare_field('value', 'uint32', 'le')
        if value.version >= 2 then
            declare_field('comment', 'cstring')
        end
    end
    return serial.read.fstruct(stream, attribute)

Of course order and parameters of calls to `declare_field` shouldn't be dependent on fields not yet serialized, otherwise deserialization cannot work. This is why in the example above *version* has to be declared before *comment*.

Finally the `fstruct` data type implements two syntactic sugars to be able to write better looking `f` functions. The `value` parameter is actually a proxy table, which redirects fields reads and writes to the actual object. This proxy implements a __call metamethod. When calling the `value` parameter, it is like you are calling the `declare_field` function. The second syntactic sugar is used when you pass only one parameter to the `declare_field` method. In that situation, since the field type name is necessary, `declare_field` doesn't immediately declares the type. Instead it returns a closure, which can be called with a type name to declare the field. Instead of calling `declare_field('value', 'uint32', 'le')` you can call `declare_field 'value' ('uint32', 'le')`. You can combine these two syntactic sugars. With them, you can rewrite the above attribute type as follows:

    local attribute = function(self)
        self 'version' ('uint32', 'le')
        self 'name' ('cstring')
        self 'value' ('uint32', 'le')
        if self.version >= 2 then
            self 'comment' ('cstring')
        end
    end
    return serial.read.fstruct(stream, attribute)

As you can see, we used the name `self` for both the `value` and `declare_field` parameters. This is because self is the standard name for the current object when using Lua object-orientated syntactic sugars. When declaring fields, you can read `self 'name' ('cstring')` as `"self name is a cstring"`.]],
} }

manual = markdown(manual)
manual = manual..[[
<ul>
]]
for itype,type in ipairs(types) do
	local pstr = table.concat(type.params, ", ")
	if pstr~="" then
		pstr = " ( "..pstr.." )"
	end
	manual = manual..[[
	<li><a href="#]]..type.name..[["/>]]..type.name..pstr..[[</a></li>
]]
end
manual = manual..[[
</ul>
]]

for itype,type in ipairs(types) do
	local pstr = table.concat(type.params, ", ")
	if pstr~="" then
		pstr = " ( "..pstr.." )"
	end
	manual = manual..[[
	<div class="function">
	<a id="]]..type.name..[["/><h3><code>]]..type.name..pstr..[[</code></h3>
]]..markdown(type.doc)..[[

		</div>
]]
end

chapter('manual', "Manual", manual, nil, true)

footer()

------------------------------------------------------------------------------

output(file_examples)

header()

chapter('examples', "Examples", [[
Here are some examples file descriptions using Lunary.

---

## %chapterid%.1 - PNG file format

[png.lua](examples/png.lua) contains a partial description of the PNG file format. It can parse the chunk structure, and some chunk content (like embedded texts), but not actual image data. Two helpers scripts allow converting PNG files to and from Lua, [png2lua](examples/png2lua) and [lua2png](examples/lua2png) respectively.

---

## %chapterid%.2 - RIFF file format

[riff.lua](examples/png.lua) contains a partial description of the RIFF file format. It can parse the chunk structure, and some chunk content from WAV or AVI files (like embedded texts), but not actual sound or video data. Two helpers scripts allow converting RIFF files to and from Lua, [riff2lua](examples/riff2lua) and [lua2riff](examples/lua2riff) respectively.

---

## %chapterid%.3 - ed2k .met files

Not shipped with this project, but available online is a description of met files used by popular eDonkey2000 clients like [eMule](http://www.emule-project.net/). It is more complex than the examples above, but they are more complete, in two senses. They use almost all built-in Lunary data types. They are also complete in the sense that they describe *all* fields of supported .met files. It is therefore possible to generate .met files from scratch using that library.

The [serial/met.lua](http://piratery.net/trac/ed2k-ltools/browser/met-ltools/serial/met.lua) file describes all the .met files formats. The [met2lua](http://piratery.net/trac/ed2k-ltools/browser/met-ltools/met2lua) script can convert met files to a Lua equivalent and vice-versa.

]])

footer()

------------------------------------------------------------------------------

--[[
Copyright (c) 2010 Jérôme Vuarand

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
