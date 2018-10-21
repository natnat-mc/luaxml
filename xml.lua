local xml={}

--[[ class: xml.node
	Holds an XML node.
	type: string
	properties: table[string]=string?
	children: xml.node[]
	text: string?
	parent: xml.node?
]]
xml.node={}
xml.node.__index=xml.node

--[[ typedef: nodematcher
	type: string?
	classes: string[]?
	id: string?
	parent: nodematcher?
]]

--[[ string node:gettext()
	Returns the text contained by this node.
	If this node is a text node, then this method returns its `text` property.
]]
function xml.node:gettext()
	if self.type=='#text' then
		return self.text
	end
	local text=''
	for _, child in ipairs(self.children) do
		text=text..child:gettext()
	end
	return text
end

--[[ void node:settext(string text)
	Sets the text of this node.
	If this node is a text node, then this method sets its `text` property.
	If this node doesn't have children, append a text node to it.
	If this node only contains a single text node, then set its `text` property.
	If all the above fails, then this method will throw an error.
]]
function xml.node:settext(text)
	if self.type=='#text' then
		self.text=text
		return
	elseif #self.children==0 then
		self:appendchild(xml.createtextnode(text))
		return
	elseif #self.children==1 and self.children[1].type=='#text' then
		self.children[1].text=text
		return
	else
		error('unable to set text of node', 2)
	end
end

--[[ void node:setproperty(string key, string value)
	Sets a given property of a node.
]]
function xml.node:setproperty(key, value)
	if type(key)~='string' or type(value)~='string' then
		error('illegal types for arguments', 2)
	end
	local props=self.properties or {}
	props[key:lower()]=value
	self.properties=props
end

--[[ string? node:getproperty(key)
	Returns the given property of a node, or nil.
]]
function xml.node:getproperty(key)
	return self.properties and self.properties[key:lower()]
end

--[[ iterator<string, string> node:getproperties()
	Returns an iterator listing all the properties of this node.
]]
function xml.node:getproperties()
	return pairs(self.properties or {})
end

--[[ void node:addclass(string class)
	Adds a class to a node if it is absent.
]]
function xml.node:addclass(class)
	if type(class)~='string' then
		error('illegal argument type', 2)
	end
	if not self:hasclass(class) then
		local clist=self:getproperty('class')
		clist=clist and (clist..' ') or ''
		self:setproperty('class', clist..class)
	end
end

--[[ void node:removeclass(string class)
	Removes a class from a node if it is present.
]]
function xml.node:removeclass(class)
	if type(class)~='string' then
		error('illegal argument type', 2)
	end
	local clist=self:getproperty('class')
	if not clist then
		return
	end
	local carr={}
	for c in clist:gmatch('%S+') do
		if c~=class then
			table.insert(carr, c)
		end
	end
	self:setproperty('class', table.concat(carr, ' '))
end

--[[ boolean node:hasclass(string class)
	Checks whether a node has a given class.
]]
function xml.node:hasclass(class)
	if type(class)~='string' then
		error('illegal argument type', 2)
	end
	local clist=self:getproperty('class')
	if not clist then
		return false
	end
	for c in clist:gmatch('%S+') do
		if c==class then
			return true
		end
	end
	return false
end

--[[ iterator<string> node:getclasses()
	Returns an iterator listing all the classes of this node.
]]
function xml.node:getclasses()
	return (self:getproperty('class') or ''):gmatch('%S+')
end

--[[ boolean node:matches(nodematcher|function matcher)
	Checks whether or not this node matches the given criteria.
]]
function xml.node:matches(matcher)
	if type(matcher)=='function' then
		return not not matcher(self)
	end
	if type(matcher)~='table' then
		error('invalid criteria', 2)
	end
	if matcher.type and matcher.type~=self.type then
		return false
	end
	if matcher.id and matcher.id~=self:getproperty('id') then
		return false
	end
	if matcher.classes then
		for _, class in ipairs(matcher.classes) do
			if not self:hasclass(class) then
				return false
			end
		end
	end
	if matcher.parent then
		if not self.parent then
			return false
		end
		return self.parent:matches(matcher.parent)
	end
	return true
end

--[[ xml.node, xml.node? node:appendchild(xml.node child)
	Adds a child node, optionally removing it from its parent.
	Returns the added node and its previous parent, if any.
]]
function xml.node:appendchild(child)
	local old=child.parent
	if child.parent then
		child.parent:removechild(child)
	end
	child.parent=self
	table.insert(self.children, child)
	return child, old
end

--[[ void node:removechild(xml.node child)
	Removes a child node.
]]
function xml.node:removechild(child)
	for i, c in ipairs(self.children) do
		if c==child then
			table.remove(self.children, i)
			child.parent=nil
			return
		end
	end
end

--[[ iterator<xml.node> node:traverse()
	Returns an iterator which will traverse the graph using a depth first algorithm.
	Uses coroutines and recursion internally.
]]
function xml.node:traverse()
	return coroutine.wrap(function() return xml.traverse(self) end)
end

--[[ xml.node? node:queryselector(string|nodematcher[] selector)
	Returns the first node found to match the given selector.
]]
function xml.node:queryselector(selector)
	if type(selector)=='string' then
		selector=xml.getselector(selector)
	end
	if type(selector)~='table' then
		error('invalid selector', 2)
	end
	local function imp(list, idx, node, prev)
		if idx>#list then
			return node
		end
		local matcher=list[idx]
		for child in node:traverse() do
			if child:matches(matcher) and child~=prev then
				local found=imp(list, idx+1, child, child)
				if found then
					return found
				end
			end
		end
	end
	return imp(selector, 1, self)
end

--[[ xml.node[] node:queryselectorall(string|nodematcher[] selector)
	Returns all nodes matching the given selector.
]]
function xml.node:queryselectorall(selector)
	if type(selector)=='string' then
		selector=xml.getselector(selector)
	end
	if type(selector)~='table' then
		error('invalid selector', 2)
	end
	local found, done={}, {}
	local function imp(list, idx, node, prev)
		if idx>#list then
			if not done[node] then
				table.insert(found, node)
				done[node]=true
			end
			return true
		end
		local matcher=list[idx]
		for child in node:traverse() do
			if child:matches(matcher) and child~=prev then
				imp(list, idx+1, child, child)
			end
		end
	end
	imp(selector, 1, self)
	return found
end

--[[ string node:dump(boolean html, boolean pretty)
	Dumps an XML document or an HTML document starting from this node.
]]
function xml.node:dump(html, pretty)
	if self.type=='#text' then
		if pretty and self.parent and #self.parent.children>1 then
			return self.text..'\n'
		end
		return self.text
	end
	local code={'<'}
	table.insert(code, self.type)
	for k, v in self:getproperties() do
		table.insert(code, ' ')
		table.insert(code, k)
		table.insert(code, '=\"')
		table.insert(code, (v:gsub('\\', '\\\\'):gsub('\"', '\\\"')))
		table.insert(code, '\"')
	end
	if html and xml.htmlcompact[self.type] then
		table.insert(code, ' />')
		if pretty then
			table.insert(code, '\n')
		end
		return table.concat(code)
	end
	table.insert(code, '>')
	if pretty and not (#self.children==1 and self.children[1].type=='#text') then
		table.insert(code, '\n')
	end
	for i, v in ipairs(self.children) do
		local dump=v:dump(html, pretty)
		table.insert(code, dump)
	end
	table.insert(code, '</')
	table.insert(code, self.type)
	table.insert(code, '>')
	if self.type=='html' and not self.parent and html then
		return '<!DOCTYPE html>\n'..table.concat(code)
	end
	if pretty then
		table.insert(code, '\n')
	end
	return table.concat(code)
end

--[[ xml.node xml.createtextnode(string text)
	Creates a text node holding the given text.
]]
function xml.createtextnode(text)
	if type(text)~='string' then
		error('attempting to creating a text node with a '..type(text), 2)
	end
	local node=xml.createnode('#text')
	node.text=text
	return node
end

--[[ xml.node xml.createnode(string type)
	Creates a node of the given type.
]]
function xml.createnode(t)
	if type(t)~='string' or (t~='#text' and not t:match('^[%l%u%d:]+$')) then
		error('illegal type for node', 2)
	end
	local node={}
	node.type=t
	node.children={}
	setmetatable(node, xml.node)
	return node
end

--[[ nodematcher[] xml.getselector(string selector)
	Returns an array of `nodematcher` objects for use with selectors.
]]
function xml.getselector(selector)
	local list={}
	for item in selector:gmatch('%S+') do
		local matcher={}
		matcher.type=item:match('^[%u%l%d-_]+')
		matcher.id=item:match('#([%u%l%d-_]+)')
		local classes={}
		for class in item:gmatch('%.([%u%l%d-_]+)') do
			table.insert(classes, class)
		end
		if #classes~=0 then
			matcher.classes=classes
		end
		table.insert(list, matcher)
	end
	return list
end

--[[ void xml.traverse(xml.node root)
	Traverses a graph and yields all nodes exactly once.
]]
function xml.traverse(root, level)
	level=level or 1
	coroutine.yield(root, level)
	for i, child in ipairs(root.children) do
		xml.traverse(child, level+1)
	end
end

--[[ map<string, boolean> xml.htmlcompact
	A lookup table of all HTML elements which should do not have an ending tag.
]]
xml.htmlcompact={}
for i, v in ipairs {'area', 'base', 'br', 'col', 'command', 'embed', 'hr', 'img', 'input', 'keygen', 'link', 'meta', 'param', 'source', 'track', 'wbr'} do
	xml.htmlcompact[v]=true
end

--[[ xml.node xml.parse(string code, boolean html)
	Parses an XML or HTML document, and throws on error.
]]
function xml.parse(code, html)
	-- avoid parser crashes when in HTML mode
	if html then
		-- remove any DOCTYPE tags
		code=code:gsub('<!DOCTYPE.->', '')
		-- remove any comments
		code=code:gsub('<!%-%-.-%-%->', '')
	end
	-- int skip(string str, int idx)
	-- 	Skips whitespace.
	local function skip(str, idx)
		return (str:find('%S', idx))
	end
	-- int tostart(string str, int idx)
	-- 	Returns the offset of the first tag
	local function tostart(str, idx)
		return (str:find('<', idx))
	end
	-- int toend(string str, int idx)
	-- 	Returns the offset of the next whitespace or tag end
	local function toend(str, idx)
		return (str:find('[%s>]', idx))
	end
	-- int topropend(string str, int idx)
	-- 	Returns the offset of the end of the property
	local function topropend(str, idx)
		return (str:find('[%s>=]', idx))
	end
	-- string, int readstr(string str, int idx)
	-- 	Reads a string delimited or not by quotes, with proper escape sequences.
	local function readstr(str, idx)
		-- determine the quote type that is used
		local chr=str:sub(idx, idx)
		if chr~='\'' and chr~='\"' then
			local ed=toend(str, idx)
			return str:sub(idx, ed-1), ed
		end
		-- read up to the end quote
		local ed=str:find(chr, idx+1)
		return str:sub(idx+1, ed-1), toend(str, ed)
	end
	local debugbuf={}
	local function print(...)
		local n=select('#', ...)
		local str=''
		for i=1, n do
			if i~=1 then
				str=str..'\t'
			end
			str=str..tostring(select(i, ...))
		end
		table.insert(debugbuf, str)
	end
	-- int|xml.node imp(string str, int idx, xml.node? parent)
	-- 	Parses a single level from the XML document and returns the next valid index or the root node.
	local function imp(str, idx, parent)
		print('imp(str, '..idx..', '..tostring(parent)..')')
		idx=skip(str, idx)
		print('skipped to '..idx)
		local node
		local stidx=tostart(str, idx)
		print('next tag is at '..stidx)
		if stidx~=idx then
			while str:sub(stidx-1, stidx-1):match('%s') do
				stidx=stidx-1
			end
			parent:appendchild(xml.createtextnode(str:sub(idx, stidx-1)))
			print('added text node to '..parent.type)
			return stidx
		end
		local edidx=toend(str, stidx)
		local name=str:sub(stidx+1, edidx-1)
		if name:sub(1, 1)=='/' then
			error('malformed XML: expecting tag start, found tag end', 3)
		end
		local node=parent:appendchild(xml.createnode(name))
		print('found tag:', name)
		idx=edidx
		print('just before string.sub('..idx..', '..idx..')')
		while str:sub(idx, idx)~='>' do
			idx=skip(str, idx)
			local nameed=topropend(str, idx)
			name=str:sub(idx, nameed-1)
			if name=='/' and str:sub(nameed, nameed)=='>' then
				print('tag is autoclosed, end of tag', node.type)
				return nameed+1
			end
			print('found property name:', name)
			local value=name
			if str:sub(nameed, nameed)=='=' then
				value,idx=readstr(str, nameed+1)
				idx=skip(str, idx)
			else
				idx=nameed
			end
			node:setproperty(name, value)
		end
		print('found the end of the start tag')
		idx=skip(str, idx+1)
		while str:sub(idx, idx+1)~='</' do
			idx=imp(str, idx, node)
			idx=skip(str, idx)
		end
		print('found end of children')
		idx=idx+2
		--FIXME throw an error only if it is a legitimate error, not for say, "</"+"scr"+"ipt>"
		--FIXME also, it should check for the ">" charcter instead of assuming it is there and ignoring it
		local taged=str:sub(idx, idx+#node.type-1)
		if taged~=node.type then
			error('malformed XML: wrong tag end found, expected '..node.type..', got '..taged, 3)
		end
		idx=idx+#node.type+1
		print('end of tag', node.type)
		return idx
	end
	-- read the document as-is
	local root=xml.createnode('root')
	imp(code, 1, root)
	for i, v in ipairs(root.children) do
		if v.type~='#text' then
			root=v
			break
		end
	end
	root.parent=nil
	-- fix some stuff if in HTML mode
	if html then
		-- fix the structure
		if root.type=='body' then
			local newroot=xml.createnode('html')
			newroot:appendchild(xml.createnode('head'))
			newroot:appendchild(root)
			root=newroot
		elseif root.type~='html' then
			local html=xml.createnode('html')
			html:appendchild(xml.createnode('head'))
			local body=html:appendchild(xml.createnode('body'))
			body:appendchild(root)
			root=html
		end
	end
	return root, table.concat(debugbuf, '\n')
end

return xml
