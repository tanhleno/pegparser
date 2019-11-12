local parser = require'pegparser.parser'
local first = require'pegparser.first'

local disjoint = first.disjoint
local calck = first.calck
local calcfirst = first.calcfirst
local union = first.union
local getName = first.getName
local isLastAlternativeAux

local changeUnique = false
local fst, flw

local function matchUnique (g, p)
	if p.tag == 'char' then
		return g.unique[p.p1]
	elseif p.tag == 'var' and parser.isLexRule(p.p1) then
		return g.unique[p.p1]
	elseif p.unique and not parser.matchEmpty(p) then
		return true
	elseif p.tag == 'con' then
		return matchUnique(g, p.p1) or matchUnique(g, p.p2)
	elseif p.tag == 'ord' then
		return matchUnique(g, p.p1) and matchUnique(g, p.p2)
	elseif p.tag == 'plus' then
		return matchUnique(g, p.p1)
	else
		return false
	end
end


local function matchUPath (p)
	if p.tag == 'char' or p.tag == 'var' then
		return p.unique
	elseif p.tag == 'con' then
		return p.unique
	elseif p.tag == 'ord' then
		return p.unique
	elseif p.tag == 'plus' then
		return p.unique
	else
		return false
	end
end


local function matchUniqueEq (p)
	if (p.tag == 'char' or p.tag == 'var') and not parser.matchEmpty(p) then
		return p.uniqueEq
	elseif p.tag == 'con' then
		return matchUniqueEq(p.p2)
	elseif p.tag == 'ord' then
		return matchUniqueEq(p.p1) and matchUniqueEq(p.p2)
	elseif p.tag == 'plus' then
		return matchUniqueEq(p.p1)
	else
		return false
	end
end


local function updateCountTk (p, t)
	local v = p.p1
	if not t[v] then
		t[v] = 1
	else
		t[v] = t[v] + 1
	end
end


local function countTk (p, t)
	if p.tag == 'char' then
		updateCountTk(p, t)
	elseif p.tag == 'var' and parser.isLexRule(p.p1) then
		updateCountTk(p, t)
	elseif p.tag == 'con' or p.tag == 'ord' then
		countTk(p.p1, t)
		countTk(p.p2, t)
	elseif p.tag == 'star' or p.tag == 'opt' or p.tag == 'plus' then
		countTk(p.p1, t)
	elseif p.tag == 'and' or p.tag == 'not' then
		--does not count tokens inside a predicate
		return
	end
end


local function printUnique (t)
	local l = {}
	for k, v in pairs(t) do
		table.insert(l, k)
	end
	table.sort(l)
	io.write("Unique tokens (# " .. #l .. "): ")
	io.write(table.concat(l, ', '))
	io.write('\n')
end


local function uniqueTk (g)
	local t = {}
	for i, v in ipairs(g.plist) do
		if not parser.isLexRule(v) then
			countTk(g.prules[v], t)
		end
	end

	print("Uunique")
	local cont = {}
	local unique = {}
	for k, v in pairs(t) do
		print(k, " = ", v)
		unique[k] = (v == 1) or nil
		if not cont[v] then
			cont[v] = 1
		else
			cont[v] = cont[v] + 1
		end
	end
	
	for i = 1, 10 do
		print("Token ", i, " = ", cont[i])
	end

	unique['SKIP'] = nil 
	printUnique(unique)
	return unique
end


local function getSymbolsFirst (g, p)
	if p.tag == 'char' or (p.tag == 'var' and parser.isLexRule(p.p1)) then
		return { [p] = true }
	elseif p.tag == 'var' then
		return getSymbolsFirst(g, g.prules[p.p1])
	elseif p.tag == 'con' then
		local t = getSymbolsFirst(g, p.p1)
		if parser.matchEmpty(p.p1) then
			t = union(t, getSymbolsFirst(g, p.p2))
		end
		return t
	elseif p.tag == 'ord' then
		return union(getSymbolsFirst(g, p.p1), getSymbolsFirst(g, p.p2))
	elseif p.tag == 'star' or p.tag == 'opt' or p.tag == 'plus' then
		return getSymbolsFirst(g, p.p1)
	else
		return {} 
	end
end


local function notDisjointPref (g, p, s)
	local inter = {}
	local sub = {}
	local pref = g.symPref[getName(p)][p]
	
	for k, v in pairs(g.symPref[s]) do
		if k ~= p then
			if not disjoint(pref, v) then
				inter[k] = true
			end
			if first.issubset(v, pref) then
				sub[k] = true
			end
		end
	end

	return inter, sub
end


local function isDisjointLast (g, p, s)
	local pref = g.symPref[getName(p)][p]
	local setDisj = {}
	for k, v in pairs(g.symPref[s]) do
		if k ~= p then
			if not disjoint(pref, v) then
				setDisj[k] = true
			end
		end
	end

	return isLastAlternative(g, p, setDisj)
end


local function isLastAlternativeAux (p, last, disj)
	if p.tag == 'char' or p.tag == 'var' then
		if disj[p] then
			return p
		else
			return last
		end
	elseif p.tag == 'ord' then
		last = isLastAlternativeAux(p.p1, last, disj)
		return isLastAlternativeAux(p.p2, last, disj)
	elseif p.tag == 'con' then
		last = isLastAlternativeAux(p.p1, last, disj)
		return isLastAlternativeAux(p.p2, last, disj)
	elseif p.tag == 'star' or p.tag == 'plus' or p.tag == 'opt' then
		return isLastAlternativeAux(p.p1, last, disj)
	else
		return last
	end
end


function isLastAlternative (g, p, t)
	--print("lastAlt", p, p.p1, g.symRule[p])
	for k, v in pairs(t) do
		if k ~= p and g.symRule[p] ~= g.symRule[k] then
			--print(g.symRule[p], g.symRule[k])
			return false
		end
	end

	local aux = t[p]
	t[p] = true
	local res = isLastAlternativeAux(g.prules[g.symRule[p]], nil, t)
	t[p] = aux
	--print("lastAlt2", p.p1, res, res == p)
	return res == p
end


local function isPrefixUniqueEq (g, p, inter, sub)
	--[==[local flw = g.symFlw[s][p]
	local flwEq = {}
	local nFlwEq = 0

	for k, _ in pairs(prefEq) do
		if not first.issubset(g.symFlw[s][k], flw) then
			return false
		end
	end]==]

	for k, _ in pairs(inter) do
		if not sub[k] then
			local t = { [k] = true }
			if not isLastAlternative(g, p, t) then
				return
			end
		end 
	end
	
	p.uniqueEq = true	
end


local function isPrefixUniqueLex (g, p)
	local inter, sub = notDisjointPref(g, p, getName(p))

	-- prefix is unique
	if next(inter) == nil then
		return true
	end

	-- prefix is not unique, but appears last
	if isLastAlternative(g, p, inter) then
		return true
	end

	isPrefixUniqueEq(g, p, inter, sub)
	
	return false
end


local function isPrefixUnique (g, p)
	local s = getName(p)

	if p.tag == 'char' or (p.tag == 'var' and parser.isLexRule(p.p1)) then
		return isPrefixUniqueLex(g, p)
	else
		return false
	end


	--local pref = g.symPref[s][p]
	--local flw = g.symFlw[s][p]
	--print(s, " pref := ", table.concat(first.sortset(pref), ", "), " flw := ", table.concat(first.sortset(flw), ", "))

	--return true
end


local function uniquePrefixAux (g, p)
	if p.tag == 'char' or p.tag == 'var' then
		--assert(not p.unique or (p.unique == true and isPrefixUnique(g, p) == true))
		p.unique = p.unique or isPrefixUnique(g, p) 
	elseif p.tag == 'con' then
		uniquePrefixAux(g, p.p1)
		uniquePrefixAux(g, p.p2)
	elseif p.tag == 'ord' then
		uniquePrefixAux(g, p.p1)
		uniquePrefixAux(g, p.p2)
	elseif p.tag == 'star' or p.tag == 'plus' or p.tag == 'opt' then
		--uniquePrefixAux(g, p.p1, pflw, true)
		uniquePrefixAux(g, p.p1)
	end
end


local function uniquePrefix (g)
	for i, v in ipairs(g.plist) do
		if not parser.isLexRule(v) then
			uniquePrefixAux(g, g.prules[v])
		end
	end
end


local function addUsage(g, p)
	if not g.varUsage[p.p1] then
		g.varUsage[p.p1] = {}
	end
	table.insert(g.varUsage[p.p1], p)
end


local function countUsage(g, p)
	local tag = p.tag
	if tag == 'empty' or tag == 'char' or tag == 'set' or
     tag == 'any' or tag == 'throw' or tag == 'def' then
		return
	elseif tag == 'var' and parser.isLexRule(p.p1) then
		return
	elseif tag == 'var' then
		addUsage(g, p)
	elseif tag == 'not' or tag == 'and' or tag == 'star' or
         tag == 'opt' or tag == 'plus' then
		countUsage(g, p.p1)
	elseif tag == 'con' or tag == 'ord' then
		countUsage(g, p.p1)
		countUsage(g, p.p2)
	else
		print(p)
		error("Unknown tag", p.tag)
	end

end

local function varUsage (g)
	g.varUsage = {}
	for i, v in ipairs(g.plist) do
		if not g.varUsage[v] then
			g.varUsage[v] = {}
		end
		countUsage(g, g.prules[v])
	end
end

local function printVarUsage (g)
	for i, v in ipairs(g.plist) do
		if not parser.isLexRule(v) then
			print("Usage", v, #g.varUsage[v])
		end
	end
end


local function uniqueUsage (g, p)
	for k, v in pairs(g.varUsage[p.p1]) do
		if not v.unique then
			return false
		end
	end
	print("Unique usage", p.p1)
	return true
end


local function setUnique (p, v)
	if not v then
		return
	end
	if not p.unique then
		changeUnique = true
	end
	p.unique = true
end


local function uniquePath (g, p, uPath, flw)
	if p.tag == 'char' then
		setUnique(p, uPath or g.uniqueTk[p.p1])
	elseif p.tag == 'var' and parser.isLexRule(p.p1) then
		setUnique(p, uPath or g.uniqueTk[p.p1])
	elseif p.tag == 'var' and uPath then
		print("unique var ", p.p1)
		setUnique(p, true)
		g.uniqueVar[p.p1] = uniqueUsage(g, p)
	elseif p.tag == 'var' then
		--print("p.p1", p.p1, #g.varUsage[p.p1])
		--if matchUnique(g, g.prules[p.p1]) and #g.varUsage[p.p1] == 1 then
		if matchUPath(g.prules[p.p1]) and #g.varUsage[p.p1] == 1 then
		--if matchUnique(g, g.prules[p.p1]) then
			print("unique var2 ", p.p1)
			setUnique(p, true)
		end
	elseif p.tag == 'con' then
		uniquePath(g, p.p1, uPath, calck(g, p.p2, flw))
		uPath = uPath or p.p1.unique
		if not uPath then
			if p.p1.tag == 'var' and not parser.isLexRule(p.p1.p1) and matchUPath(g.prules[p.p1.p1]) and isDisjointLast(g, p.p1, getName(p.p1)) then
				uPath = true
			elseif (p.p1.tag == 'char' or (p.p1.tag == 'var' and parser.isLexRule(p.p1.p1))) and isDisjointLast(g, p.p1, getName(p.p1)) then
				uPath = true
			end
		end
		uniquePath(g, p.p2, uPath, flw)
		setUnique(p, uPath or p.p2.unique)
	elseif p.tag == 'ord' then
    local flagDisjoint = disjoint(calcfirst(g, p.p1), calck(g, p.p2, flw))
		uniquePath(g, p.p1, flagDisjoint and uPath, flw)
		uniquePath(g, p.p2, uPath, flw)
		setUnique(p, uPath or (p.p1.unique and p.p2.unique))
	elseif p.tag == 'star' or p.tag == 'opt' or p.tag == 'plus' then
		local flagDisjoint = disjoint(calcfirst(g, p.p1), flw)
		if p.tag == 'star' or p.tag == 'plus' then
			flw = union(calcfirst(g, p.p1), flw)
		end
		uniquePath(g, p.p1, flagDisjoint and uPath, flw)
		if p.tag == 'plus' then
			setUnique(p, uPath or p.p1.unique)
		else
			setUnique(p, uPath)
		end
	end
end


local function insideLoop (g, p, loop, seq)
	 if p.tag == 'var' and not parser.isLexRule(p.p1) and loop and not seq then
		if not g.loopVar[p.p1] then
			g.loopVar[p.p1] = true
			insideLoop(g, g.prules[p.p1], loop, seq)
		end
	elseif p.tag == 'con' then
		insideLoop(g, p.p1, loop, seq)
		insideLoop(g, p.p2, loop, seq or not parser.matchEmpty(p.p1))
	elseif p.tag == 'ord' then
		insideLoop(g, p.p1, loop, seq)
		insideLoop(g, p.p2, loop, seq)
	elseif p.tag == 'star' or p.tag == 'opt' or p.tag == 'plus' then
		insideLoop(g, p.p1, true, false)
	elseif p.tag == 'and' or p.tag == 'not' then
		insideLoop(g, p.p1, loop, seq)
	end

end


local function calcUniquePath (g)
	g.loopVar = {}
	for i, v in ipairs(g.plist) do
		insideLoop(g, g.prules[v], false, false)
	end
	--[==[io.write("insideLoop: ")
	for i, v in ipairs(g.plist) do
		if g.loopVar[v] then
			io.write(v .. ', ')
		end
	end
	io.write('\n')
	]==]


	fst = first.calcFst(g)
	flw = first.calcFlw(g)	

	g.notDisjointFirst = first.notDisjointFirst(g)

	g.uniqueTk = uniqueTk(g)
	g.uniqueVar = {}
	g.uniqueVar[g.plist[1]] = true
	varUsage(g)
	first.calcTail(g)
	first.calcPrefix(g)
	first.calcLocalFollow(g)
	changeUnique = true
	while changeUnique do
		changeUnique = false
		uniquePrefix(g)
		for i, v in ipairs(g.plist) do		
			if not parser.isLexRule(v) then
				uniquePath(g, g.prules[v], g.uniqueVar[v], flw[v])
			end
		end
	end
	

	io.write("Unique vars: ")
	for i, v in ipairs(g.plist) do
		if g.uniqueVar[v] then
			io.write(v .. ', ')
		end
	end
	io.write('\n')

	io.write("matchUPath: ")
	for i, v in ipairs(g.plist) do
		if matchUPath(g.prules[v]) then
			io.write(v .. ', ')
		end
	end
	io.write('\n')

end


return {
	uniqueTk = uniqueTk,
	calcUniquePath = calcUniquePath,
	matchUnique = matchUnique,
	matchUPath = matchUPath,
	matchUniqueEq = matchUniqueEq,
}
