local m = require 'init'
local errinfo = require 'syntax_errors'
local pretty = require 'pretty'
local coder = require 'coder'
local first = require 'first'
local recovery = require 'recovery'
local lfs = require'lfs'
local re = require'relabel'

-- Does not need to remove labels manually

g = [[
program         <-  SKIP (toplevelfunc  /  toplevelvar  /  toplevelrecord  /  import  /  foreign)* !.
toplevelfunc    <-  localopt 'function' NAME '(' paramlist ')' rettypeopt block 'end'
toplevelvar     <-  localopt decl '=' exp
toplevelrecord  <-  'record' NAME recordfields 'end'
localopt        <-  'local'?
import          <-  'local' NAME '=' 'import' ('(' STRINGLIT ')'  /  STRINGLIT)
foreign         <-  'local' NAME '=' 'foreign' ('(' STRINGLIT ')'  /  STRINGLIT)
rettypeopt      <-  (':' rettype^Err_001)?
paramlist       <-  (param (',' param^Err_002)*)?
param           <-  NAME ':'^Err_003 type^Err_004
decl            <-  NAME (':' type^Err_005)?
decllist        <-  decl (',' decl^Err_006)*
simpletype      <-  'nil'  /  'boolean'  /  'integer'  /  'float'  /  'string'  /  'value'  /  NAME  /  '{' type '}'
typelist        <-  '(' (type (',' type)*)? ')'
rettype         <-  typelist '->' rettype  /  simpletype '->' rettype  /  typelist  /  simpletype
type            <-  typelist '->' rettype  /  simpletype '->' rettype  /  simpletype
recordfields    <-  recordfield+
recordfield     <-  NAME ':'^Err_007 type^Err_008 ';'?
block           <-  statement* returnstat?
statement       <-  ';'  /  'do' block 'end'^Err_009  /  'while' exp^Err_010 'do'^Err_011 block 'end'^Err_012  /  'repeat' block 'until'^Err_013 exp^Err_014  /  'if' exp^Err_015 'then'^Err_016 block elseifstats elseopt 'end'^Err_017  /  'for' decl^Err_018 '='^Err_019 exp^Err_020 ','^Err_021 exp^Err_022 (',' exp^Err_023)? 'do'^Err_024 block 'end'^Err_025  /  'local' decllist^Err_026 '='^Err_027 explist^Err_028  /  varlist '=' explist  /  suffixedexp
elseifstats     <-  elseifstat*
elseifstat      <-  'elseif' exp^Err_029 'then'^Err_030 block
elseopt         <-  ('else' block)?
returnstat      <-  'return' explist? ';'?
exp             <-  e1
e1              <-  e2 ('or' e2^Err_031)*
e2              <-  e3 ('and' e3^Err_032)*
e3              <-  e4 (('=='  /  '~='  /  '<='  /  '>='  /  '<'  /  '>') e4^Err_033)*
e4              <-  e5 ('|' e5^Err_034)*
e5              <-  e6 ('~' !'=' e6^Err_035)*
e6              <-  e7 ('&' e7^Err_036)*
e7              <-  e8 (('<<'  /  '>>') e8^Err_037)*
e8              <-  e9 ('..' e8^Err_038)?
e9              <-  e10 (('+'  /  '-') e10^Err_039)*
e10             <-  e11 (('*'  /  '%%'  /  '/'  /  '//') e11^Err_040)*
e11             <-  ('not'  /  '#'  /  '-'  /  '~')* e12
e12             <-  castexp ('^' e11^Err_041)?
suffixedexp     <-  prefixexp expsuffix+
expsuffix       <-  funcargs  /  ':' NAME funcargs  /  '[' exp ']'  /  '.' !'.' NAME
prefixexp       <-  NAME  /  '(' exp ')'
castexp         <-  simpleexp 'as' type  /  simpleexp
simpleexp       <-  'nil'  /  'false'  /  'true'  /  NUMBER  /  STRINGLIT  /  initlist  /  suffixedexp  /  prefixexp
var             <-  suffixedexp  /  NAME !expsuffix
varlist         <-  var (',' var)*
funcargs        <-  '(' explist? ')'^Err_042  /  initlist  /  STRINGLIT
explist         <-  exp (',' exp)*
initlist        <-  '{' fieldlist? '}'^Err_043
fieldlist       <-  field (fieldsep field)* fieldsep?
field           <-  (NAME '=')? exp
fieldsep        <-  ';'  /  ','
STRINGLIT       <-  '"' (!'"' .)* '"'  /  "'" (!"'" .)* "'"
RESERVED        <-  ('and'  /  'as'  /  'boolean'  /  'break'  /  'do'  /  'else'  /  'elseif'  /  'end'  /  'float'  /  'foreign'  /  'for'  /  'false'  /  'function'  /  'goto'  /  'if'  /  'import'  /  'integer'  /  'in'  /  'local'  /  'nil'  /  'not'  /  'or'  /  'record'  /  'repeat'  /  'return'  /  'string'  /  'then'  /  'true'  /  'until'  /  'value'  /  'while') ![a-zA-Z_0-9]
NAME            <-  !RESERVED [a-zA-Z_] [a-zA-Z_0-9]*
NUMBER          <-  [0-9]+ ('.' !'.' [0-9]*)?
COMMENT         <-  '--' (!%nl .)*
]]


local g = m.match(g)
print("Original Grammar")
print(pretty.printg(g), '\n')

print("Regular Annotation (SBLP paper)")
local glabRegular = recovery.addlab(g, true, false)
print(pretty.printg(glabRegular, true), '\n')

print("Conservative Annotation (Hard)")
local glabHard = recovery.addlab(g, true, true)
print(pretty.printg(glabHard, true), '\n')

print("Conservative Annotation (Soft)")
local glabSoft = recovery.addlab(g, true, 'soft')
print(pretty.printg(glabSoft, true), '\n')

local p = coder.makeg(g)

local dir = lfs.currentdir() .. '/test/titan/test/yes/'	
for file in lfs.dir(dir) do
	if string.sub(file, 1, 1) ~= '.' and string.sub(file, #file - #'titan' + 1) == 'titan' then
		print("Yes: ", file)
		local f = io.open(dir .. file)
		local s = f:read('a')
		f:close()
		local r, lab, pos = p:match(s)
		local line, col = '', ''
		if not r then
			line, col = re.calcline(s, pos)
		end
		assert(r ~= nil, file .. ': Label: ' .. tostring(lab) .. '  Line: ' .. line .. ' Col: ' .. col)
	end
end

local dir = lfs.currentdir() .. '/test/titan/test/no/'	
for file in lfs.dir(dir) do
	if string.sub(file, 1, 1) ~= '.' and string.sub(file, #file - #'titan' + 1) == 'titan' then
		print("No: ", file)
		local f = io.open(dir .. file)
		local s = f:read('a')
		f:close()
		local r, lab, pos = p:match(s)
		io.write('r = ' .. tostring(r) .. ' lab = ' .. tostring(lab))
		local line, col = '', ''
		if not r then
			line, col = re.calcline(s, pos)
			io.write(' line: ' .. line .. ' col: ' .. col)
		end
		io.write('\n')
		assert(r == nil, file .. ': Label: ' .. tostring(lab) .. '  Line: ' .. line .. ' Col: ' .. col)
	end
end
