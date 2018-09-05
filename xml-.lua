#!/usr/bin/env lua
local xml=require 'xml'
require 'util'

local function dumptree(tree)
	for node, level in tree:traverse() do
		local ind=('\t'):rep(level-1)
		io.write(ind..node.type..'\n')
		io.write(ind..' level: '..level..'\n')
		if node.type=='#text' then
			io.write(ind..' text: '..strlit(node:gettext())..'\n')
		else
			io.write(ind..' properties:\n')
			for k, v in node:getproperties() do
				io.write(ind..'  '..k..'='..v..'\n')
			end
			io.write(ind..' classes:\n')
			for c in node:getclasses() do
				io.write(ind..'  '..c..'\n')
			end
		end
	end
end

local fd=io.open('test.html')
local code=fd:read('a')
fd:close()

local html, debug=xml.parse(code, true)
dumptree(html)
io.write('\n')

io.write(html:dump(true, true))
io.write('\n')
