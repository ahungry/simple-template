:- module(st_parse, [
    st_parse/3 % +Codes, -Blocks, +Options
]).

/** <module> Template parser

Parses a list of tokens into a template structure.
*/

:- use_module(library(option)).

:- use_module(st_white).
:- use_module(st_simple_tokens).
:- use_module(semblance_tokens).

init_fe :-
    source_file(init_fe, FWD),
    file_directory_name(FWD, PWD),
    assert(user:file_search_path(sl, PWD)).

:- init_fe.

% Check if alternate tokenizer is set
is_semblance_p(semblance).

%! st_tokens(+Codes, -Tokens, +Options) is det.
%
% Throw an error if no valid tokenizer is chosen in options
st_tokens(_Codes, _Tokens, Options):-
    option(frontend(Frontend), Options),
    \+member(Frontend, [simple, semblance]),
    throw(error(invalid_frontend_tokenizer(Frontend))).

%! st_tokens(+Codes, -Tokens, +Options) is det.
%
% Assists in choosing optional tokenizer, tokenizes.
st_tokens(Codes, Tokens, Options):-
    option(frontend(Frontend), Options),
    is_semblance_p(Frontend),
    semblance_tokens(Codes, Tokens).

%! st_tokens(+Codes, -Tokens, +Options) is det.
%
% Fallback to default st_tokens incase the Options are not set in
% default_options, or if the `simple` option (default) is set.
%
% Tokenizes the input.
st_tokens(Codes, Tokens, _Options):-
    st_simple_tokens(Codes, Tokens).

%! st_parse(+Codes, -Templ, +Options) is det.
%
% Parses given list of codes into a template.
%
% Throws various parsing errors.
st_parse(Codes, Blocks, Options):-
    st_tokens(Codes, Tokens, Options),
    phrase(blocks(Tmp, Options), Tokens, Rest), !,
    check_rest(Rest),
    Blocks = Tmp.

% Checks the remaining tokens.
% Checks the remaining tokens.
% Some tokens (end, else, else_if)
% could appear by mistake without the
% block-starting token. This will catch
% such errors.

check_rest([]):- !.

check_rest([end|_]):-
    throw(error(unexpected_block_end)).

check_rest([else|_]):-
    throw(error(unexpected_else)).

check_rest([else_if(_)|_]):-
    throw(error(unexpected_else_if)).

% Takes as many blocks as possible.

blocks([Block|Blocks], Options) -->
    block(Block, Options), !,
    blocks(Blocks, Options).

blocks([], _) --> [].

% Output statement.

block(out(Term), _) -->
    [out(Term)].

% Unescaped output statement.

block(out_unescaped(Term), _) -->
    [out_unescaped(Term)].

% Each loop.

block(each(Items, Item, Blocks), Options) -->
    [each(Items, Item)], blocks(Blocks, Options), block_end.

block(each(Items, Item, Index, Blocks), Options) -->
    [each(Items, Item, Index)], blocks(Blocks, Options), block_end.

block(each(Items, Item, Index, Len, Blocks), Options) -->
    [each(Items, Item, Index, Len)], blocks(Blocks, Options), block_end.

% if/else/else if blocks.

block(if(Cond, True, Rest), Options) -->
    [if(Cond)], blocks(True, Options), cond_rest(Rest, Options).

% Text output.

block(text(String), Options) -->
    [text(Codes)], !,
    {
        (   option(strip(true), Options)
        ->  st_strip_indent(Codes, Stripped),
            string_codes(String, Stripped)
        ;   string_codes(String, Codes))

    }.

% Include.

block(include(File), _) -->
    [include(File)].

block(include(File, Var), _) -->
    [include(File, Var)].

% Dynamic include.

block(dynamic_include(FileVar), _) -->
    [dynamic_include(FileVar)].

block(dynamic_include(FileVar, Var), _) -->
    [dynamic_include(FileVar, Var)].

% Recognizes block end or
% throws an error when one not found.

block_end -->
    [end], !.

block_end -->
    { throw(error(expecting_block_end)) }.

% Remainer part of if/else if block.

cond_rest([], _) -->
    [end], !.

cond_rest(Blocks, Options) -->
    [else], blocks(Blocks, Options), block_end, !.

cond_rest([if(Cond, True, Rest)], Options) -->
    [else_if(Cond)], blocks(True, Options), cond_rest(Rest, Options), !.

cond_rest(_, _) -->
    { throw(error(expecting_cond_else_or_end)) }.
