local m = require 'pegparser.parser'
local coder = require 'pegparser.coder'
local util = require'pegparser.util'

-- Added 40 labels
-- Does not need to remove labels manually
-- Disable rule typedef_name, because its correct matching depends on semantic actions

local g = [[
translation_unit <-  SKIP external_decl+^Err_001 !.
external_decl   <-  function_def  /  decl
function_def    <-  declarator decl* compound_stat  /  decl_spec function_def
decl_spec       <-  storage_class_spec  /  type_spec  /  type_qualifier
decl            <-  decl_spec init_declarator_list? ';'  /  decl_spec decl
storage_class_spec <-  'auto'  /  'register'  /  'static'  /  'extern'  /  'typedef'
type_spec       <-  'void'  /  'char'  /  'short'  /  'int'  /  'long'  /  'float'  /  'double'  /  'signed'  /  'unsigned'  /  typedef_name  /  'enum' ID? '{' enumerator (',' enumerator)* '}'  /  'enum' ID  /  struct_or_union ID? '{' struct_decl+ '}'  /  struct_or_union ID
type_qualifier  <-  'const'  /  'volatile'
struct_or_union <-  'struct'  /  'union'
init_declarator_list <-  init_declarator (',' init_declarator)*
init_declarator <-  declarator '=' initializer  /  declarator
struct_decl     <-  spec_qualifier struct_declarator (',' struct_declarator)* ';'  /  spec_qualifier struct_decl
spec_qualifier_list <-  (type_spec  /  type_qualifier)+
spec_qualifier  <-  type_spec  /  type_qualifier
struct_declarator <-  declarator? ':' const_exp  /  declarator
enumerator      <-  ID '=' const_exp  /  ID
declarator      <-  pointer? direct_declarator
direct_declarator <-  (ID  /  '(' declarator ')') ('[' const_exp? ']'  /  '(' param_type_list ')'  /  '(' id_list? ')')*
pointer         <-  '*' type_qualifier* pointer  /  '*' type_qualifier*
param_type_list <-  param_decl (',' param_decl)* (',' '...')?
param_decl      <-  decl_spec+ (declarator  /  abstract_declarator)?
id_list         <-  ID (',' ID)*
initializer     <-  '{' initializer (',' initializer)* ','? '}'  /  assignment_exp
type_name       <-  spec_qualifier_list abstract_declarator?
abstract_declarator <-  pointer  /  pointer? direct_abstract_declarator
direct_abstract_declarator <-  '(' abstract_declarator ')' ('[' const_exp? ']'  /  '(' param_type_list? ')')*
typedef_name    <-  ID
stat            <-  ID ':' stat  /  'case' const_exp^Err_002 ':'^Err_003 stat^Err_004  /  'default' ':'^Err_005 stat^Err_006  /  exp? ';'  /  compound_stat  /  'if' '(' exp ')' stat 'else' stat^Err_007  /  'if' '(' exp ')' stat  /  'switch' '('^Err_008 exp^Err_009 ')'^Err_010 stat^Err_011  /  'while' '(' exp ')' stat  /  'do' stat^Err_012 'while'^Err_013 '('^Err_014 exp^Err_015 ')'^Err_016 ';'^Err_017  /  'for' '('^Err_018 exp? ';'^Err_019 exp? ';'^Err_020 exp? ')'^Err_021 stat^Err_022  /  'goto' ID^Err_023 ';'^Err_024  /  'continue' ';'^Err_025  /  'break' ';'^Err_026  /  'return' exp? ';'^Err_027
compound_stat   <-  '{' decl* stat* '}'
exp             <-  assignment_exp (',' assignment_exp)*
assignment_exp  <-  unary_exp assignment_operator assignment_exp  /  conditional_exp
assignment_operator <-  '=' !'='  /  '*='  /  '/='  /  '%='  /  '+='  /  '-='  /  '<<='  /  '>>='  /  '&='  /  '^='  /  '|='
conditional_exp <-  logical_or_exp '?' exp^Err_028 ':'^Err_029 conditional_exp^Err_030  /  logical_or_exp
const_exp       <-  conditional_exp
logical_or_exp  <-  logical_and_exp ('||' logical_and_exp^Err_031)*
logical_and_exp <-  inclusive_or_exp ('&&' inclusive_or_exp^Err_032)*
inclusive_or_exp <-  exclusive_or_exp ('|' !'|' exclusive_or_exp^Err_033)*
exclusive_or_exp <-  and_exp ('^' and_exp^Err_034)*
and_exp         <-  equality_exp ('&' !'&' equality_exp)*
equality_exp    <-  relational_exp (('=='  /  '!=') relational_exp^Err_035)*
relational_exp  <-  shift_exp (('<='  /  '>='  /  '<'  /  '>') shift_exp^Err_036)*
shift_exp       <-  additive_exp (('<<'  /  '>>') additive_exp^Err_037)*
additive_exp    <-  multiplicative_exp (('+'  /  '-') multiplicative_exp)*
multiplicative_exp <-  cast_exp (('*'  /  '/'  /  '%') cast_exp)*
cast_exp        <-  '(' type_name ')' cast_exp  /  unary_exp
unary_exp       <-  '++' unary_exp  /  '--' unary_exp  /  unary_operator cast_exp  /  'sizeof' (type_name  /  unary_exp)^Err_038  /  postfix_exp
postfix_exp     <-  primary_exp ('[' exp ']'  /  '(' (assignment_exp (',' assignment_exp)*)? ')'  /  '.' ID^Err_039  /  '->' ID^Err_040  /  '++'  /  '--')*
primary_exp     <-  ID  /  STRING  /  constant  /  '(' exp ')'
constant        <-  INT_CONST  /  CHAR_CONST  /  FLOAT_CONST  /  ENUMERATION_CONST
unary_operator  <-  '&'  /  '*'  /  '+'  /  '-'  /  '~'  /  '!'
COMMENT         <-  '/*' (!'*/' .)* '*/'
INT_CONST       <-  ('0' [xX] XDIGIT+  /  !'0' DIGIT DIGIT*  /  '0' [0-8]*) ([uU] [lL]  /  [lL] [uU]  /  'l'  /  'L'  /  'u'  /  'U')?
FLOAT_CONST     <-  '0x' (('.'  /  XDIGIT+  /  XDIGIT+  /  '.') ([eE] [-+]? XDIGIT+)? [lLfF]?  /  XDIGIT+ [eE] [-+]? XDIGIT+ [lLfF]?)  /  ('.'  /  DIGIT+  /  DIGIT+  /  '.') ([eE] [-+]? DIGIT+)? [lLfF]?  /  DIGIT+ [eE] [-+]? DIGIT+ [lLfF]?
XDIGIT          <-  [0-9a-fA-F]
DIGIT           <-  [0-9]
CHAR_CONST      <-  "'" (%nl  /  !"'" .) "'"
STRING          <-  '"' (%nl  /  !'"' .)* '"'
ESC_CHAR        <-  '\\' ('n'  /  't'  /  'v'  /  'b'  /  'r'  /  'f'  /  'a'  /  '\\'  /  '?'  /  "'"  /  '"'  /  [01234567] [01234567]? [01234567]?  /  'x' XDIGIT)
ENUMERATION_CONST <-  ID
ID              <-  !KEYWORDS [a-zA-Z_] [a-zA-Z_0-9]*
KEYWORDS        <-  ('auto'  /  'double'  /  'int'  /  'struct'  /  'break'  /  'else'  /  'long'  /  'switch'  /  'case'  /  'enum'  /  'register'  /  'typedef'  /  'char'  /  'extern'  /  'return'  /  'union'  /  'const'  /  'float'  /  'short'  /  'unsigned'  /  'continue'  /  'for'  /  'signed'  /  'void'  /  'default'  /  'goto'  /  'sizeof'  /  'volatile'  /  'do'  /  'if'  /  'static'  /  'while') ![a-zA-Z_0-9]
SPACE           <-  [ 	

]  /  COMMENT
SKIP            <-  ([ 	

]  /  COMMENT)*
Token           <-  '~'  /  '}'  /  '||'  /  '|='  /  '|'  /  '{'  /  XDIGIT  /  STRING  /  KEYWORDS  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ESC_CHAR  /  ENUMERATION_CONST  /  DIGIT  /  COMMENT  /  CHAR_CONST  /  '^='  /  '^'  /  ']'  /  '['  /  '>>='  /  '>>'  /  '>='  /  '>'  /  '=='  /  '='  /  '<='  /  '<<='  /  '<<'  /  '<'  /  ';'  /  ':'  /  '/='  /  '/'  /  '...'  /  '->'  /  '-='  /  '--'  /  '-'  /  ','  /  '+='  /  '++'  /  '+'  /  '*='  /  '*'  /  ')'  /  '('  /  '&='  /  '&&'  /  '&'  /  '%='  /  '%'  /  '!='  /  '!'
EatToken        <-  (Token  /  (!SPACE .)+) SKIP
Err_001         <-  (!(!.) EatToken)*
Err_002         <-  (!':' EatToken)*
Err_003         <-  (!('~'  /  '{'  /  'while'  /  'switch'  /  'sizeof'  /  'return'  /  'if'  /  'goto'  /  'for'  /  'do'  /  'default'  /  'continue'  /  'case'  /  'break'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  ';'  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_004         <-  (!('~'  /  '}'  /  '{'  /  'while'  /  'switch'  /  'sizeof'  /  'return'  /  'if'  /  'goto'  /  'for'  /  'else'  /  'do'  /  'default'  /  'continue'  /  'case'  /  'break'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  ';'  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_005         <-  (!('~'  /  '{'  /  'while'  /  'switch'  /  'sizeof'  /  'return'  /  'if'  /  'goto'  /  'for'  /  'do'  /  'default'  /  'continue'  /  'case'  /  'break'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  ';'  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_006         <-  (!('~'  /  '}'  /  '{'  /  'while'  /  'switch'  /  'sizeof'  /  'return'  /  'if'  /  'goto'  /  'for'  /  'else'  /  'do'  /  'default'  /  'continue'  /  'case'  /  'break'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  ';'  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_007         <-  (!('~'  /  '}'  /  '{'  /  'while'  /  'switch'  /  'sizeof'  /  'return'  /  'if'  /  'goto'  /  'for'  /  'else'  /  'do'  /  'default'  /  'continue'  /  'case'  /  'break'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  ';'  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_008         <-  (!('~'  /  'sizeof'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_009         <-  (!')' EatToken)*
Err_010         <-  (!('~'  /  '{'  /  'while'  /  'switch'  /  'sizeof'  /  'return'  /  'if'  /  'goto'  /  'for'  /  'do'  /  'default'  /  'continue'  /  'case'  /  'break'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  ';'  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_011         <-  (!('~'  /  '}'  /  '{'  /  'while'  /  'switch'  /  'sizeof'  /  'return'  /  'if'  /  'goto'  /  'for'  /  'else'  /  'do'  /  'default'  /  'continue'  /  'case'  /  'break'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  ';'  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_012         <-  (!'while' EatToken)*
Err_013         <-  (!'(' EatToken)*
Err_014         <-  (!('~'  /  'sizeof'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_015         <-  (!')' EatToken)*
Err_016         <-  (!';' EatToken)*
Err_017         <-  (!('~'  /  '}'  /  '{'  /  'while'  /  'switch'  /  'sizeof'  /  'return'  /  'if'  /  'goto'  /  'for'  /  'else'  /  'do'  /  'default'  /  'continue'  /  'case'  /  'break'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  ';'  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_018         <-  (!('~'  /  'sizeof'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  ';'  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_019         <-  (!('~'  /  'sizeof'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  ';'  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_020         <-  (!('~'  /  'sizeof'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  ')'  /  '('  /  '&'  /  '!') EatToken)*
Err_021         <-  (!('~'  /  '{'  /  'while'  /  'switch'  /  'sizeof'  /  'return'  /  'if'  /  'goto'  /  'for'  /  'do'  /  'default'  /  'continue'  /  'case'  /  'break'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  ';'  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_022         <-  (!('~'  /  '}'  /  '{'  /  'while'  /  'switch'  /  'sizeof'  /  'return'  /  'if'  /  'goto'  /  'for'  /  'else'  /  'do'  /  'default'  /  'continue'  /  'case'  /  'break'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  ';'  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_023         <-  (!';' EatToken)*
Err_024         <-  (!('~'  /  '}'  /  '{'  /  'while'  /  'switch'  /  'sizeof'  /  'return'  /  'if'  /  'goto'  /  'for'  /  'else'  /  'do'  /  'default'  /  'continue'  /  'case'  /  'break'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  ';'  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_025         <-  (!('~'  /  '}'  /  '{'  /  'while'  /  'switch'  /  'sizeof'  /  'return'  /  'if'  /  'goto'  /  'for'  /  'else'  /  'do'  /  'default'  /  'continue'  /  'case'  /  'break'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  ';'  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_026         <-  (!('~'  /  '}'  /  '{'  /  'while'  /  'switch'  /  'sizeof'  /  'return'  /  'if'  /  'goto'  /  'for'  /  'else'  /  'do'  /  'default'  /  'continue'  /  'case'  /  'break'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  ';'  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_027         <-  (!('~'  /  '}'  /  '{'  /  'while'  /  'switch'  /  'sizeof'  /  'return'  /  'if'  /  'goto'  /  'for'  /  'else'  /  'do'  /  'default'  /  'continue'  /  'case'  /  'break'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  ';'  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_028         <-  (!':' EatToken)*
Err_029         <-  (!('~'  /  'sizeof'  /  STRING  /  INT_CONST  /  ID  /  FLOAT_CONST  /  ENUMERATION_CONST  /  CHAR_CONST  /  '--'  /  '-'  /  '++'  /  '+'  /  '*'  /  '('  /  '&'  /  '!') EatToken)*
Err_030         <-  (!('}'  /  ']'  /  ';'  /  ':'  /  ','  /  ')') EatToken)*
Err_031         <-  (!('}'  /  ']'  /  '?'  /  ';'  /  ':'  /  ','  /  ')') EatToken)*
Err_032         <-  (!('}'  /  '||'  /  ']'  /  '?'  /  ';'  /  ':'  /  ','  /  ')') EatToken)*
Err_033         <-  (!('}'  /  '||'  /  ']'  /  '?'  /  ';'  /  ':'  /  ','  /  ')'  /  '&&') EatToken)*
Err_034         <-  (!('}'  /  '||'  /  '|'  /  ']'  /  '?'  /  ';'  /  ':'  /  ','  /  ')'  /  '&&') EatToken)*
Err_035         <-  (!('}'  /  '||'  /  '|'  /  '^'  /  ']'  /  '?'  /  ';'  /  ':'  /  ','  /  ')'  /  '&&'  /  '&') EatToken)*
Err_036         <-  (!('}'  /  '||'  /  '|'  /  '^'  /  ']'  /  '?'  /  '=='  /  ';'  /  ':'  /  ','  /  ')'  /  '&&'  /  '&'  /  '!=') EatToken)*
Err_037         <-  (!('}'  /  '||'  /  '|'  /  '^'  /  ']'  /  '?'  /  '>='  /  '>'  /  '=='  /  '<='  /  '<'  /  ';'  /  ':'  /  ','  /  ')'  /  '&&'  /  '&'  /  '!=') EatToken)*
Err_038         <-  (!('}'  /  '||'  /  '|='  /  '|'  /  '^='  /  '^'  /  ']'  /  '?'  /  '>>='  /  '>>'  /  '>='  /  '>'  /  '=='  /  '='  /  '<='  /  '<<='  /  '<<'  /  '<'  /  ';'  /  ':'  /  '/='  /  '/'  /  '-='  /  '-'  /  ','  /  '+='  /  '+'  /  '*='  /  '*'  /  ')'  /  '&='  /  '&&'  /  '&'  /  '%='  /  '%'  /  '!=') EatToken)*
Err_039         <-  (!('}'  /  '||'  /  '|='  /  '|'  /  '^='  /  '^'  /  ']'  /  '?'  /  '>>='  /  '>>'  /  '>='  /  '>'  /  '=='  /  '='  /  '<='  /  '<<='  /  '<<'  /  '<'  /  ';'  /  ':'  /  '/='  /  '/'  /  '-='  /  '-'  /  ','  /  '+='  /  '+'  /  '*='  /  '*'  /  ')'  /  '&='  /  '&&'  /  '&'  /  '%='  /  '%'  /  '!=') EatToken)*
Err_040         <-  (!('}'  /  '||'  /  '|='  /  '|'  /  '^='  /  '^'  /  ']'  /  '?'  /  '>>='  /  '>>'  /  '>='  /  '>'  /  '=='  /  '='  /  '<='  /  '<<='  /  '<<'  /  '<'  /  ';'  /  ':'  /  '/='  /  '/'  /  '-='  /  '-'  /  ','  /  '+='  /  '+'  /  '*='  /  '*'  /  ')'  /  '&='  /  '&&'  /  '&'  /  '%='  /  '%'  /  '!=') EatToken)*	
]] 


local g = m.match(g)
local p = coder.makeg(g, 'ast')

local dir = util.getPath(arg[0])

util.testYes(dir .. '/test/yes/', 'c', p)

util.setVerbose(true)
util.testNoRec(dir .. '/test/no/', 'c', p)
