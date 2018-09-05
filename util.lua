-- range iterator
local function rangeit(max, val)
	if val<max then
		return val+1
	else
		return nil
	end
end
function range(min, max)
	return rangeit, max, min-1
end

-- string iterator
local function strit(obj)
	if obj.pos<obj.max then
		obj.pos=obj.pos+1
		return obj.str:sub(obj.pos, obj.pos)
	else
		return nil
	end
end
function chars(str, min, max)
	local obj={}
	obj.str=str
	obj.pos=min or 0
	obj.max=max or #str
	return strit, obj
end

function strlit(a)
	a=a
		:gsub('\\', '\\\\')
		:gsub('\'', '\\\'')
		:gsub('\n', '\\n')
		:gsub('\t', '\\t')
		:gsub('\v', '\\v')
		:gsub('\a', '\\a')
		:gsub('\r', '\\r')
	return '\''..a..'\''
end

function dump(a, n, sp)
	n=n or 'a'
	sp=sp or ''
	if type(a)=='table' then
		if not next(a) then
			io.write(sp..n..'={} (empty)\n')
		end
		local seen={}
		local sequence=true
		for i, v in ipairs(a) do
			seen[i]=true
		end
		for k, v in pairs(a) do
			if not seen[k] then
				sequence=false
				break
			end
		end
		if sequence then
			io.write(sp..n..'=['..#a..'] (sequence)\n')
			for i, v in ipairs(a) do
				dump(v, n..'['..i..']', sp..'\t')
			end
		else
			io.write(sp..n..':\n')
			for k, v in pairs(a) do
				local name=tostring(k)
				if type(k)=='string' then
					name=strlit(name)
				end
				dump(v, n..'['..name..']', sp..'\t')
			end
		end
	elseif type(a)=='string' then
		io.write(sp..n..'='..strlit(a)..'\n')
	else
		io.write(sp..n..'='..tostring(a)..' ('..type(a)..')\n')
	end
end

function reverse(tab)
	local rev={}
	for k, v in pairs(tab) do
		rev[v]=k
	end
	return rev
end
