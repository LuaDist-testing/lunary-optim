local _M = {}

local string = require 'string'
local io = require 'io'
local os = require 'os'
local lfs = require 'lfs'

function _M.dumppair(table, file, level, k, v)
	local success,err
	success,err = file:write(("\t"):rep(level))
	if not success then return nil,err end
	local assignment = " = "
	if type(k)=='string' then
		if k:match("^[_a-zA-Z][_a-zA-Z0-9]*$") then
			success,err = file:write(k)
			if not success then return nil,err end
		else
			success,err = file:write(string.format('[%q]', k))
			if not success then return nil,err end
		end
	elseif type(k)=='number' then
		success,err = file:write('['..k..']')
		if not success then return nil,err end
	elseif type(k)=='nil' then
		-- we are in the array part
		assignment = ""
	else
		error("unsupported key type '"..type(k).."'")
	end
	success,err = file:write(assignment)
	if not success then return nil,err end
	if type(v)=='string' then
		if #v > 256 then
			local t = {}
			local chunksize = 32
			for i=1,#v,chunksize do
				t[#t+1] = v:sub(i,i+chunksize-1)
			end
			success,err = file:write("table.concat{\n")
			if not success then return nil,err end
			success,err = _M.dumptable(t, file, level+1)
			if not success then return nil,err end
			success,err = file:write(("\t"):rep(level).."}")
			if not success then return nil,err end
		else
			success,err = file:write((string.format('%q', v):gsub("\t", "\\t"):gsub("\\\n", "\\n"):gsub('[\001-\031]', function(c) return '\\'..string.byte(c) end)))
			if not success then return nil,err end
		end
	elseif type(v)=='number' then
		success,err = file:write(v)
		if not success then return nil,err end
	elseif type(v)=='boolean' then
		if v then
			success,err = file:write('true')
			if not success then return nil,err end
		else
			success,err = file:write('false')
			if not success then return nil,err end
		end
	elseif type(v)=='table' then
		success,err = file:write("{\n")
		if not success then return nil,err end
		success,err = _M.dumptable(v, file, level+1)
		if not success then return nil,err end
		success,err = file:write(("\t"):rep(level).."}")
		if not success then return nil,err end
	else
		error("unsupported value type '"..type(v).."'")
	end
	success,err = file:write(",\n")
	if not success then return nil,err end
	return true
end

function _M.dumptable(table, file, level)
	assert(type(table)=='table', "dumptable can only dump tables")
	local done = {}
	for k,v in ipairs(table) do
		local success,err = _M.dumppair(table, file, level, nil, v)
		if not success then return nil,err end
		done[k] = true
	end
	for k,v in pairs(table) do
		if not done[k] then
			local success,err = _M.dumppair(table, file, level, k, v)
			if not success then return nil,err end
			done[k] = true
		end
	end
	return true
end

function _M.dumptabletofile(table, filename, oldsuffix)
	if oldsuffix and lfs.attributes(filename, 'mode') then
		local i,suffix = 0,oldsuffix
		while io.open(filename..suffix, "rb") do
			i = i+1
			suffix = oldsuffix..i
		end
		assert(os.rename(filename, filename..suffix))
	end
	local err,file,success
	file,err = io.open(filename, "wb")
	if not file then return nil,err end
	success,err = file:write"return {\n"
	if not success then return nil,err end
	success,err = _M.dumptable(table, file, 1)
	if not success then return nil,err end
	success,err = file:write"}\n"
	if not success then return nil,err end
	success,err = file:close()
	if not success then return nil,err end
	return true
end

return _M
