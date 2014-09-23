==============================================================================
  Getting started writing parsers and syntax extensions using ##DeCaP## and
  ##pa_ocaml##
------------------------------------------------------------------------------
  Rodolphe Lepigre & Christophe Raffalli
------------------------------------------------------------------------------
  Lama, UMR 5127 CNRS, Université Savoie Mont-Blanc
==============================================================================

\linesBefore(3)
//Delimited Continuation Parser// (or ##DeCaP##) is a small parser combinator
library written in ##OCaml##. Unlike most combinator libraries, its
performance is close to that of ##ocamlyacc##, as it relies heavily on
//continuation passing style// (CPS). ##DeCaP## provides a notion of //blank
function// which is used to discard parts of the input that should be ignored
(comments for example). Ambiguous grammars can be handled either by returning
the list of all possible parse trees or by raising an error in case of
ambiguity.

##DeCaP## has been used to write a full-featured ##OCaml## parser called
##pa_ocaml##, which operates at more than twice the speed of ##camlp4##, and
is only five times slower than the original ##OCaml## parser (written with
##ocamlyacc##). When used in conjunction with ##DeCaP##, ##pa_ocaml## offers
a simple and integrated way to write parsers, and even syntax extensions for
the ##OCaml## language. It is intended to be simpler to use than ##camlp4##,
and does not require the use of a lexer, which gives the user more freedom to
write syntax extensions. A quotation and anti-quotation mechanism similar to
that of ##camlp4## is provided, which greatly simplifies the writing of syntax
extensions.

This document is not intended as a full documentation of ##DeCaP## and
##pa_ocaml##, but rather as a quick description of their main features,
illustrated with simple examples. It should contain enough material to get
started writing parsers and syntax extensions, while providing an overall
idea of the working principles of ##DeCaP## and ##pa_ocaml##.

Even though ##DeCaP## can be used directly, a ##pa_ocaml## syntax extension
called ##pa_parser## allows the user to write parsers using a BNF-like
syntax. There is, however, one main restriction: //left recursive// grammars
are forbidden.

-- Input buffer and pre-processing --

The ##Input## module exports an abstract type ##buffer##, on which ##DeCaP##
relies for parsing. Several functions are provided for creating a buffer from
a file, an input channel or a ##string##. The reader can refer to the
interface file ##input.mli## (or to the associated generated ##ocamldoc##
file) for the full details.

We give bellow the type of the three main buffer-creating functions, but we do
not describe them in detail since their names and types should be explicit
enough for the reader to guess the usage. Note, however, that the functions
##buffer_from_string## and ##buffer_from_channel## have an optional argument
##filename## which is used to report better error messages.

###

  buffer_from_file : string -> buffer
  buffer_from_channel : ?filename:string -> in_channel -> buffer
  buffer_from_string : ?filename:string -> string -> buffer

###

We will see later that in some case it might be useful to manually read input
from the ##buffer##. This can be done with the function ##read##, which takes
as input a buffer and a position, and returns a triple containing the
character read, the new state of the buffer, and the position of the next
character.

###

  read : buffer -> int -> char * buffer * int

###

In the current implementation, the ##Input## module comes with a built-in
C-like pre-processor which is very useful to support several versions of
##OCaml##. In the near future, this feature will be disabled by default, as
it might be harmful and prevent the parsing of some languages.

-- Blank functions --

While a string or file is being parsed, it is required to differentiate parts
of the input that are meaningful, from those that need to be ignored.
This part of the work is usually handled by a lexer, but ##DeCaP## relies on
another mechanism: blank functions.

A blank function inspects the input buffer at a given position, and returns
the position of the next meaningful character (i.e. the next character that is
not to be ignored). The type of a blank function is
##blank = buffer -> int -> buffer * int##. The simplest possible blank
function is one that does not ignore any character:

### OCaml

  let no_blank buf pos = (buf, pos)

###

It is possible to eliminate blanks according to a regual expression. To do so,
the function ##blank_regexp : Str.regexp -> blank## may be used. In the
following example, the blank function ignores an arbitrary number of spaces,
tabulations, newline and carriage return characters:

### OCaml

  let blank_re = blank_regexp (Str.regexp "[ \t\n\r]*")

###
//Important remark: due to a limitation of the ##Str## module (which can only
match regular expressions against strings), the current implementation of
##DeCaP## does not behave well on regular expressions containing the new line
symbol (since the ##Input## module is implemented using a stream of lines). A
blank function using a regular expression containing a new line symbol will be
applied to several lines in turn if they are matched completely. This means
that a regular expression containing a new line symbol will behave correctly
only if it is idempotent.//

Another way to build a blank function is to directly read the input buffer
using the ##Input.read## function. For example, the following blank function
ignores any number of spaces, tabulations, and carriage return symbols, but
at most one new line symbol:

### OCaml

  let blank_custom = 
    let rec fn accept_newline buffer pos =
      let (c, buffer', pos') = Input.read buffer pos in
      match c with
      | '\n' when accept_newline -> fn false buffer' pos'
      | ' ' | '\t' | '\r'        -> fn accept_newline buffer' pos'
      | _                        -> buffer, pos
    in fn true

###

As there is no limitation as to what can be used to write a blank function,
one could even decide to use the function ##partial_parse_buffer## (see
##decap.mli##) and use a ##DeCaP## parser to parse blanks.

-- Parsing functions --

The ##DeCaP## library exports an abstract type ##'a grammar## which is the
type of a function parsing a ##buffer## and returning data of type ##'a##.
Given a blank function and a grammar (i.e. an object of type ##'a grammar##),
input is parsed from a ##string##, input channel, file or ##buffer## using one
of the following functions:

### OCaml

  parse_string  : ?filename:string -> 'a grammar -> blank -> string -> 'a
  parse_channel : ?filename:string -> 'a grammar -> blank -> in_channel -> 'a
  parse_file    : 'a grammar -> blank -> string -> 'a
  parse_buffer  : 'a grammar -> blank -> buffer -> 'a

###

Every parsing function take as input a default blank function that will be
used to discard blank characters before every terminal is parsed. This
blank function can be changed at any time by calling the function
##change_layout## in a grammar (see ##decap.mli## and the next sections).

Note that the functions ##parse_string## and ##parse_channel## have an
optional argument ##filename## which is used to report better error messages.
The reader should refer to the file ##decap.mli## (or to the associated
generated ##ocamldoc## file) for more details.

All of the parsing functions above either succeed in parsing all the input,
or fail with an exception (##Parse_error## for example). The function
##handle_exception## is provided for this reason: it handles exceptions and
displays a human-readable error message.

###

  handle_exception : ('a -> 'b) -> 'a -> 'b

###

Parsing functions working on only part of the input are also provided. The
reader should again refer to the file ##decap.mli## for more details. These
functions can be used to implement a blank function using a parser, as was
noted at the end of the section about blank functions.

-- Writing parsers --

The combinators provided by the ##DeCaP## library are not easy to use
directly. That is why an ##OCaml## syntax extension called ##pa_parser## is
distributed along ##pa_ocaml##. It allows the user to write parsers using a
BNF-like syntax. ##OCaml## programs written using this syntax extension need
to be compiled using the ##-pp pa_ocaml## option of ##ocamlc## or
##ocamlopt##. The ##pa_parser## extension is enabled by default when using
the ##pa_ocaml## parser, but this behavious can be changed.

The entry point of the ##pa_parser## syntax extension is a new expression
delimited by the keyword ##parser##, which is followed by an optional ##*##
symbol and the BNF rule for the grammar. If there is no ##*## symbol, the
parser will raise an exception in case of ambibuity. Otherwise, the list of
every possible parse tree is returned by the parser, which will have a type of
the form ##'a list grammar##.

We give bellow the BNF specification of the ##pa_parser## syntax extension,
using the following convention: ##|## sepatates alternatives, ##[…]##
delimits optional elements and ##(…)+## elements repeated one or more
times. Terminal symbols are wrapped into double quotes, and entry points are
wrapped into chevrons. Several entry points of the ##OCaml## language are
used: ##<expr>##, ##<expr_atom>## and ##<let_binding>##. They refer to
expressions (any priority level), expression at the level of atoms (for
example constants, identifiers, projections and anything between parenthesis)
and ##let ... in## bindings respectively.

###

<expr>     ::= ...
             | "parser" ["*"] ["|"] <rule>
             | "parser_locate" <expr> <expr>

###

###

<rule>     ::= <rule> "|"  <rule>
             | <rule> "|?" <rule>
             | <left> "->" <expr>

<left>     ::= <let_binding> <left>
             | "-" <left>
             | <left> "->>" <left>
             | ([<pattern> ":"] <parser> [<option>] [<modifier>])+

<parser>   ::= <terminal>
             | <atom_expr>
             | "{" <rule> "}"

<terminal> ::= "ANY" | "EOF" | "EMPTY" | "FAIL"
             | "CHR"   <atom_expr>
             | "STR"   <atom_expr>
             | "RE"    <atom_expr>
             | "DEBUG" <atom_expr>

<option>   ::= "[" <expr> "]"
<modifier> ::= "?" | "??" | "*" | "**" | "+" | "++"

###

Before entering into the details of the composition of parsers using modifiers
or the alternative marker ##|## and ##|?##, we will describe the action of
each terminal:
\begin{itemize}
\item ##ANY## parses one character (that is not the end of file character),
      and the result of the parsing is the parse character. The type of this
      atomic parser is hence ##char grammar##.
\item ##EOF## parses the end of file character, and returns the expression
      contained in the option field, or unit if it is abscent. This terminal
      is almost always useless because all the parsing functions that parse
      the whole input automatically append ##EOF## at the end of the given
      grammar (this is not the case for ##partial_parse_string## for example).
\item ##EMPTY## parses nothing and and always succeeds. It returns the
      expression contained in the option field, or unit if it is abscent.
\item ##FAIL## fails immediately. If there is an option field, the value of
      The given expression will appear in the error message.
\item ##DEGUG msg## parses nothing but print debuging information including
      the given string ##msg## to ##stderr##.
\item ##CHR c## parses the character ##c## and returns the expression
      contained in the option field, or the parsed character if the option
      is abscent.
\item ##STR s## parses the string ##s## an returns the expression contained
      in the option field, or the parsed string if the option is abscent.
\item ##RE r## parses the input according to the regular expression ##r##,
      which should be a ##string## formated as described in the documentation
      of the ##Str## module. If the option filed is not provided, the value
      returned by the parser if the ##string## that was matched. Otherwise,
      the value of the optional field is returnd. Note that the identifier
      ##group## is bound in the optional field, and can be used to compute
      the return value of the parser. It corresponds to a function that
      maps the natural integer ##n## to the ##n##-th matched group of the
      regular expression.

      \begin{noindent}
      //Important remark: due to a limitation of the ##Str## module (which can
      only match regular expressions against strings), the current
      implementation of ##DeCaP## does not behave well on regular expressions
      containing the new line symbol (since the ##Input## module is
      implemented using a stream of lines). Hence, regular expression in the
      ##RE## terminal should not contain the new line symbol.//
      \end{noindent}
\end{itemize}

(* FIXME hack for correct indentation... *)
###

###

The usual BNF modifiers for optionality (##?##), repetition zero or more
times (##*##) and repetition one or more times (##+##) come in two versions.
The ususal symbols (i.e. the ones that are not doubled) behave in the usual
way, in the sense that once a parse tree has been found, no backtracking is
done to explore the other possibilities. The symbols that are doubled (##??##,
##*##, ##+##) lead to an exploration of every possible parse tree by relying
on backtracking. We also have two kinds of alternative symbols: The usual
##|## symbol stops backtracking when one alternative is successfully parsed.
The alternative symbol ##|?## does a lot more backtracking and explores every
possibility. Note that there should be no difference on grammars that are not
ambiguous.

Let us now give a first example of a parser, implementing a very simplistic
calculator having as only operations addition and substraction. The BNF
grammar of the parsed language will be the following, where ##<int>##
designates a regual expression matchin integers:

###

<op>   ::= "+" | "-"
<expr> ::= <int> (<op> <int>)*

###

This grammar is translated to ##pa_parser## syntax in a straight forward
way. The following ##OCaml## program will parse and compute the result of
any valid string it receives as a command-line argument.

###

###
### OCaml "calc_base.ml"
open Decap

let int = parser
  | n:RE("[0-9]+") -> int_of_string n
let op = parser
  | CHR('+') -> (+)
  | CHR('-') -> (-)
let expr = parser
  | n:int l:{op:op m:int -> (op,m)}* ->
      List.fold_left (fun acc (op,f) -> op acc f) n l

let parse =
  let blank = blank_regexp (Str.regexp "[ \t]*") in
  handle_exception (parse_string ~filename:"arg" expr blank)

let _ =
  let cmd = Sys.argv.(0) in
  match Sys.argv with
  | [|_;s|] -> Printf.printf "%s = %i\n" s (parse s)
  | _       -> Printf.fprintf stderr "Usage: %s \"1 + 2 - 4\"\n" cmd
###

(* TODO:
   - more explanations on the syntax of the first example
   - declare_grammar
   - grammar_family
   - ->> syntax
*)

-- Changing the layout of blanks --

On important feature if that the blank function can be changed using the function:

### OCaml
change_layout : ?old_blank_before:bool -> ?new_blank_after:bool -> 
  'a grammar -> blank -> 'a grammar
###

The grammar returned by ##change_layout parser blank## will only use
the provided blank function and ignore the old one. Since blank functions
are called before every terminals, it is not clear whether the old blank
function should be called before entering the scope of the ##change_layout##,
and whether the new blank function should be called after leaving the scope of
the ##change_layout##.

The first optional argument ##old_blank_before## (##true## by default) will
force using first the old blank function, and then the new one, before parsing
the first terminal inside the scope of the ##change_layout##.

Similarly, ##new_blank_after## (##false## by default) will forces to use the
newly provided blank function once at the end of the parsed input, and then
the old blank function will be used too as expected before the next terminal.

-- Example of a calculator --

Here is the most classical example: a calculator, including variables.

### OCaml "calc_prio.ml"
open Glr

(* Two regexps + a blank function created from a regexp *)
let float_re = {|[0-9]+\([.][0-9]+\)?\([eE][-+]?[0-9]+\)?|}
let ident_re = {|[a-zA-Z_'][a-zA-Z0-9_']*|}
let blank = blank_regexp (Str.regexp {|[ \t\n\r]*|})

(* definition of the pririoty levels and a hash tbl for the 
   values of variables *)
type calc_prio = Sum | Prod | Pow | Atom
let env = Hashtbl.create 101

(* we declare a "family of parser", because we want to
   define a recursive grammar *)
let expression, set_expression = grammar_family "expression" 

(* Two small parsers for infix symbols *)
let products = parser CHR('*') -> ( *. ) | CHR('/') -> ( /. )
let sums = parser CHR('+') -> ( +. ) | CHR('-') -> ( -. )

(* we define the main parser, parametrised by priority *)
let _ = set_expression (fun prio ->
  parser
  | f:RE(float_re) when prio = Atom -> float_of_string f
  | id:RE(ident_re) when prio = Atom ->
      (try Hashtbl.find env id
       with Not_found ->
         Printf.eprintf "Unbound %s\n%!" id; raise Exit)
  | CHR('(') e:(expression Sum) CHR(')') when prio = Atom -> e
  | CHR('-') e:(expression Pow) when prio = Pow -> -. e
  | CHR('+') e:(expression Pow) when prio = Pow -> e
  | e:(expression Atom) e':{STR("**") e':(expression Pow)}? when prio = Pow ->
         (match e' with None -> e | Some e' -> e ** e')
  | e:(expression Pow) l:{fn:products e':(expression Pow)}* when prio = Prod ->
      List.fold_left ( fun acc (fn, e') -> fn acc e') e l
  | e:(expression Prod) l:{fn:sums e':(expression Prod)}* when prio = Sum ->
      List.fold_left ( fun acc (fn, e') -> fn acc e') e l)

(* the parser for commands *)
let command = parser
  | id:RE(ident_re) CHR('=') e:(expression Sum) -> Hashtbl.add env id e; e
  | e:(expression Sum) -> e

(* The main loop *)
let _ =
  try while true do (* we use the Glr function provided to handle exception *)
    handle_exception (fun () ->
      Printf.printf ">> %!";
      (* we call the parser with the choosen blank function *)
      let x = parse_string command blank (input_line stdin) in
      Printf.printf "=> %f\n%!" x) ()
  done with End_of_file -> ()
###

