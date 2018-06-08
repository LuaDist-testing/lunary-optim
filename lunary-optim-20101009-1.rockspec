-- This file was automatically generated for the LuaDist project.

package = 'lunary-optim'
version = '20101009-1'
-- LuaDist source
source = {
  tag = "20101009-1",
  url = "git://github.com/LuaDist-testing/lunary-optim.git"
}
-- Original source
-- source = {
-- 	url = 'http://hg.piratery.net/lunary/archive/28e555ccabd32f80ef25d788ff66177eefeed891.tar.gz',
-- 	dir = 'lunary-28e555ccabd32f80ef25d788ff66177eefeed891',
-- }
description = {
	summary = "Optimizations for Lunary.",
	detailed = [[Lunary is a framework to read and write structured binary data from and to files or network connections. This rock provides faster implementation of some of the built-in datatypes of Lunary.]],
	homepage = 'http://piratery.net/lunary/',
	license = 'MIT',
}
dependencies = {
	'lua ~> 5.1',
	'lunary-core 20101009-1',
}
build = {
	type = 'builtin',
	modules = {
		['serial.optim'] = {
			sources = { 'serial/optim.c' },
			defines = {
				'LUAMOD_API=LUALIB_API',
				'luaopen_module=luaopen_serial_optim',
			},
		},
	},
}

-- vi: ft=lua