#include <lua.h>
#include <lauxlib.h>
#include "../compat.h"

typedef unsigned char byte;
#define BUFFERSIZE 256

static char hexchars[] = {
	'0', '1', '2', '3', '4', '5', '6', '7',
	'8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
};
static byte hexchar2bin(lua_State* L, const char hex)
{
	if (hex>='0' && hex<='9')
		return hex-'0';
	else if (hex>='A' && hex<='F')
		return hex-'A'+10;
	else if (hex>='a' && hex<='z')
		return hex-'a'+10;
	else
		return luaL_argerror(L, 1, "invalid hex character");
/*
	switch (hex)
	{
		case '0': return 0x0;
		case '1': return 0x1;
		case '2': return 0x2;
		case '3': return 0x3;
		case '4': return 0x4;
		case '5': return 0x5;
		case '6': return 0x6;
		case '7': return 0x7;
		case '8': return 0x8;
		case '9': return 0x9;
		case 'A': case 'a': return 0xa;
		case 'B': case 'b': return 0xb;
		case 'C': case 'c': return 0xc;
		case 'D': case 'd': return 0xd;
		case 'E': case 'e': return 0xe;
		case 'F': case 'f': return 0xf;
		default:
			return luaL_argerror(L, 1, "invalid hexadecimal character");
	}
*/
}

static int bin2hex(lua_State* L)
{
	const byte* bin;
	size_t size, i;
	char buffer[BUFFERSIZE];
	char* hex;
	bin = (const byte*)luaL_checklstring(L, 1, &size);
	/* 1 bytes for 2 chars */
	if (size*2 <= BUFFERSIZE)
		hex = buffer;
	else
		hex = (char*)lua_newuserdata(L, size*2);
	for (i=0; i<size; ++i)
	{
		byte a;
		a = bin[i*1+0];
		hex[i*2+0] = hexchars[(a>>4)&0xf];
		hex[i*2+1] = hexchars[a&0xf];
	}
	lua_pushlstring(L, hex, size*2);
	return 1;
}

static int hex2bin(lua_State* L)
{
	const char* hex;
	size_t size, i;
	byte buffer[BUFFERSIZE];
	byte* bin;
	hex = (const char*)luaL_checklstring(L, 1, &size);
	/* 1 bytes for 2 chars */
	if (size/2 <= BUFFERSIZE)
		bin = buffer;
	else
		bin = (byte*)lua_newuserdata(L, size/2);
	for (i=0; i<size/2; ++i)
	{
		byte a, b;
		a = hexchar2bin(L, hex[i*2+0]);
		b = hexchar2bin(L, hex[i*2+1]);
		bin[i*1+0] = a << 4 | b;
	}
	lua_pushlstring(L, (char*)bin, size/2);
	return 1;
}

static char base32chars[] = {
	'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
	'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
	'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X',
	'Y', 'Z', '2', '3', '4', '5', '6', '7',
};
static byte base32char2bin(lua_State* L, const char base32)
{
	if (base32>='A' && base32<='Z')
		return base32-'A';
	else if (base32>='2' && base32<='7')
		return base32-'2'+26;
	else if (base32>='a' && base32<='z')
		return base32-'a';
	else
		return luaL_argerror(L, 1, "invalid base32 character");
/*
	switch (base32)
	{
		case 'A': case 'a': return 0;
		case 'B': case 'b': return 1;
		case 'C': case 'c': return 2;
		case 'D': case 'd': return 3;
		case 'E': case 'e': return 4;
		case 'F': case 'f': return 5;
		case 'G': case 'g': return 6;
		case 'H': case 'h': return 7;
		case 'I': case 'i': return 8;
		case 'J': case 'j': return 9;
		case 'K': case 'k': return 10;
		case 'L': case 'l': return 11;
		case 'M': case 'm': return 12;
		case 'N': case 'n': return 13;
		case 'O': case 'o': return 14;
		case 'P': case 'p': return 15;
		case 'Q': case 'q': return 16;
		case 'R': case 'r': return 17;
		case 'S': case 's': return 18;
		case 'T': case 't': return 19;
		case 'U': case 'u': return 20;
		case 'V': case 'v': return 21;
		case 'W': case 'w': return 22;
		case 'X': case 'x': return 23;
		case 'Y': case 'y': return 24;
		case 'Z': case 'z': return 25;
		case '2': return 26;
		case '3': return 27;
		case '4': return 28;
		case '5': return 29;
		case '6': return 30;
		case '7': return 31;
		default:
			return luaL_argerror(L, 1, "invalid base32 character");
	}
*/
}

static int bin2base32(lua_State* L)
{
	const byte* bin;
	size_t size, i;
	char buffer[BUFFERSIZE];
	char* base32;
	bin = (const byte*)luaL_checklstring(L, 1, &size);
	/* 5 bytes for 8 chars */
	if (size % 5 != 0)
		return luaL_argerror(L, 1, "string length must be a multiple of 5");
	if (size*8/5 <= BUFFERSIZE)
		base32 = buffer;
	else
		base32 = (char*)lua_newuserdata(L, size*8/5);
	for (i=0; i<size/5; ++i)
	{
		byte a, b, c, d, e;
		a = bin[i*5+0];
		b = bin[i*5+1];
		c = bin[i*5+2];
		d = bin[i*5+3];
		e = bin[i*5+4];
		base32[i*8+0] = base32chars[( a >> 3 )&0x1f];	       /* 5 bits from a */
		base32[i*8+1] = base32chars[( a << 2 | b >> 6 )&0x1f]; /* 3 bits from a and 2 bits from b */
		base32[i*8+2] = base32chars[( b >> 1 )&0x1f];          /* 5 bits from b */
		base32[i*8+3] = base32chars[( b << 4 | c >> 4 )&0x1f]; /* 1 bit from b and 4 bits from c */
		base32[i*8+4] = base32chars[( c << 1 | d >> 7 )&0x1f]; /* 4 bits from c and 1 bit from d */
		base32[i*8+5] = base32chars[( d >> 2 )&0x1f];          /* 5 bits from d */
		base32[i*8+6] = base32chars[( d << 3 | e >> 5 )&0x1f]; /* 2 bits from d and 3 bits from e */
		base32[i*8+7] = base32chars[( e << 0 )&0x1f];          /* 5 bits from e */
	}
	lua_pushlstring(L, base32, size*8/5);
	return 1;
}

static int base322bin(lua_State* L)
{
	const char* base32;
	size_t size, i;
	byte buffer[BUFFERSIZE];
	byte* bin;
	base32 = (const char*)luaL_checklstring(L, 1, &size);
	/* 8 chars for 5 bytes */
	if (size % 8 != 0)
		return luaL_argerror(L, 1, "string length must be a multiple of 8");
	if (size*5/8 <= BUFFERSIZE)
		bin = buffer;
	else
		bin = (byte*)lua_newuserdata(L, size*5/8);
	for (i=0; i<size/8; ++i)
	{
		byte a, b, c, d, e, f, g, h;
		a = base32char2bin(L, base32[i*8+0]);
		b = base32char2bin(L, base32[i*8+1]);
		c = base32char2bin(L, base32[i*8+2]);
		d = base32char2bin(L, base32[i*8+3]);
		e = base32char2bin(L, base32[i*8+4]);
		f = base32char2bin(L, base32[i*8+5]);
		g = base32char2bin(L, base32[i*8+6]);
		h = base32char2bin(L, base32[i*8+7]);
		bin[i*5+0] = (a << 3 | b >> 2) & 0xff;
		bin[i*5+1] = (b << 6 | c << 1 | d >> 4) & 0xff;
		bin[i*5+2] = (d << 4 | e >> 1) & 0xff;
		bin[i*5+3] = (e << 7 | f << 2 | g >> 3) & 0xff;
		bin[i*5+4] = (g << 5 | h >> 0) & 0xff;
	}
	lua_pushlstring(L, (char*)bin, size*5/8);
	return 1;
}

static luaL_Reg functions[] = {
	{"bin2hex", bin2hex},
	{"hex2bin", hex2bin},
	{"bin2base32", bin2base32},
	{"base322bin", base322bin},
	{0, 0},
};

LUAMOD_API int luaopen_module(lua_State* L)
{
	lua_newtable(L);
	setfuncs(L, functions, 0);
	return 1;
}

/*
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
*/

// vi: ts=4 sts=4 sw=4 noet
