local parser = require'pegparser.parser'
local first = require'pegparser.first'
local pretty = require'pegparser.pretty'

local empty = first.empty
local any = first.any

-- testing FIRST and FOLLOW

local function assertequal_aux (v, pre, comp)
	for k, _ in pairs (pre) do
		assert(comp[k], '"' .. v .. '": missing "' .. k .. '" in computed set.')
	end
	for k, _ in pairs (comp) do
		assert(pre[k], '"' .. v .. '": missing "' .. k .. '" in predefined set.')
	end
end

local function assertequal (pre, comp)
	local auxk = nil
	comp['SKIP'] = nil
	for k, v in pairs (pre) do
		assertequal_aux(k, v, comp[k])
		auxk = next(comp, auxk)
	end
	local x = next(comp, auxk)
	assert(x == nil, x)
end

local function makeset (l)
	local t = {}
	for _, v in ipairs(l) do
		t[v] = true	
	end
	return t
end
--[==[

local g = [[
	S <- (A / B)* 'c'
	A <- 'a'
  B <- 'b' 
]]

local prefst = {
  S = makeset{'a', 'b', 'c'},
	A = makeset{'a'},
	B = makeset{'b'}
}
local preflw = {
	S = makeset{'$'},
	A = makeset{'a',  'b', 'c'},
	B = makeset{'a', 'b', 'c'}
}

local peg = parser.match(g)
local fst = first.calcFst(peg)
local flw = first.calcFlw(peg)

assertequal(prefst, fst)
assertequal(preflw, flw)


local g = [[
	S <- ('o' A / 'u' B)* (C / D)* 'c' E F G
	A <- 'a'?
  B <- 'b'? 'x' 
  C <- 'k'+ 'z'  
	D <- 'd'
	E <- !'e' 'g'
  F <- &'f' 'g'  
  G <- &'e' !'f'  
]]


local prefst = {
  S = makeset{'o', 'u', 'k', 'd', 'c'},
	A = makeset{empty, 'a'},
	B = makeset{'b', 'x'},
	C = makeset{'k'},
	D = makeset{'d'},
	E = makeset{'g'},
	F = makeset{'g'},
	G = makeset{empty}
}

local preflw = {
  S = makeset{'$'},
	A = makeset{'o', 'u', 'k', 'd', 'c'},
	B = makeset{'o', 'u', 'k', 'd', 'c'},
	C = makeset{'k', 'd', 'c'},
	D = makeset{'k', 'd', 'c'},
	E = makeset{'g'},
	F = makeset{'$'},
	G = makeset{'$'}
}


local peg = parser.match(g)
local fst = first.calcFst(peg)
local flw = first.calcFlw(peg)

assertequal(prefst, fst)
assertequal(preflw, flw)


local g = [[
	S <- A^bola / B
	A <- 'a' %{Erro}
  B <- 'b'? 'x'? ('y'+)^Erro2 
]]

local prefst = {
  S = makeset{'a', 'b', 'x', 'y', empty},
	A = makeset{'a'},
	B = makeset{'b', 'x', 'y', empty},
}

local preflw = {
  S = makeset{'$'},
	A = makeset{'$'},
	B = makeset{'$'},
}


local peg = parser.match(g)
local fst = first.calcFst(peg)
local flw = first.calcFlw(peg)

assertequal(prefst, fst)
assertequal(preflw, flw)


local g = [[
	S <- A S B / ([a-cd] / C)* 
	A <- .   
  B <- ('x' / D)*
	C <- 'f'? 'y'+
	D <- 'd' / C
]]

local peg = parser.match(g)

local prefst = {
  S = makeset{any, 'a', 'b', 'c', 'd', 'f', 'y', empty},
	A = makeset{any},
	B = makeset{'x', 'd', 'f', 'y', empty},
	C = makeset{'f', 'y'},
	D = makeset{'d', 'f', 'y'},
}

local preflw = {
  S = makeset{'$', 'x', 'd', 'f', 'y'},
	A = makeset{any, 'a', 'b', 'c', 'd', 'f', 'y', '$', 'x'},
	B = makeset{'$', 'x', 'd', 'f', 'y'},
	C = makeset{'a', 'b', 'c', 'd', 'f', 'y', '$', 'x'},
	D = makeset{'$', 'x', 'd', 'f', 'y'},
}


local peg = parser.match(g)
local fst = first.calcFst(peg)
local flw = first.calcFlw(peg)

--print("FIRST")
--first.printfirst(tree, r)
--print("FOLLOW")
--first.printfollow(r)

assertequal(prefst, fst)
assertequal(preflw, flw)

]==]
print("+")

local g = [[
	S <- A
	A <- 'a'   
  B <- 'a'
	C <- A
	D <- B
]]

local peg = parser.match(g)
local fst = first.calcFst(peg)
local flw = first.calcFlw(peg)

print(first.disjoint(fst['A'], fst['B']))
print(first.disjoint(fst['C'], fst['D']))
print(first.disjoint(fst['C'], fst['S']))

for k,v in pairs(fst['D']) do
	print(k, v)
end


print("Ok")


