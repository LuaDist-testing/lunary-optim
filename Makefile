ifeq ($(OS),Windows_NT)
DLLEXT=dll
else
DLLEXT=so
endif

PREFIX?=/usr/local
INSTALL_LUA=$(PREFIX)/share/lua/5.1
INSTALL_BIN=$(PREFIX)/lib/lua/5.1
CPPFLAGS=-Wall -O2 "-DLUAMOD_API=__attribute__((visibility (\"default\")))"
CFLAGS=-fPIC
LDFLAGS=-fvisibility=hidden

build:serial/optim.$(DLLEXT)

clean:
	rm -f serial/optim.$(DLLEXT)

pureinstall:
	install -d $(INSTALL_LUA)
	install -d $(INSTALL_LUA)/serial
	install -d $(INSTALL_BIN)/serial
	install *.lua $(INSTALL_LUA)
	install serial/*.lua $(INSTALL_LUA)/serial

install:build pureinstall
	install serial/*.$(DLLEXT) $(INSTALL_BIN)/serial

uninstall:
	rm -rf $(INSTALL_BIN)/serial
	rm -rf $(INSTALL_LUA)/serial
	rm -f $(INSTALL_LUA)/serial.lua

serial/optim.so: CPPFLAGS+=-Dluaopen_module=luaopen_serial_optim

%.$(DLLEXT): %.c
	$(LINK.c) -shared $^ $(LOADLIBES) $(LDLIBS) -o $@

test:build
	@lua serial.lua

.PHONY:build clean pureinstall install test

# Copyright (c) 2009 Jérôme Vuarand
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

