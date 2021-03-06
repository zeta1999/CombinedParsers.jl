# CombinedParsers.jl Documentation

A package for combining parsers and transforming strings into julia types.

Compose parsers parsimoneously within a functional [parser combinator paradigm](https://en.wikipedia.org/wiki/Parser_combinator),
utilize Julia's type inference for transformations,
log conveniently for debugging, and let Julia compile your parser for performance.


!!! note
    `CombinedParsers.jl` is currently a release candidate presented at JuliaCon2020.
    See the next steps section, if interested.
	

## Package Features

- Speed
  - [write parsers faster than `Base.PCRE`](man/pcre-compliance.md), optimized by the Julia compiler for parametric parser and state types.
  - `@generated function`s, trie-based scanning ([example](man/example-either-trie.md)), compile with your custom parsing algorithm ([example](man/example-palindromes.md))
  - (planned: memoization, lazy transformations)
- Simplicity
  - Clear [`@syntax`](@ref) integrates [`map`](@ref) transformations with Julia [`result_type`](@ref) inference.
  - Define without redundancy: parser, memory representation, and instance construction.
    When solely the parser is defined, Julia infers [`result_type`](@ref)(parser) and defines memory layout, 
    and constructors are compiled for the parsing state from [`Transformation`](@ref)s.
  - [AbstractTrees.jl](https://github.com/JuliaCollections/AbstractTrees.jl) interface provides clearly layed out printing in the REPL. [`with_log`](@ref) provides colored logging of the parsing [`with_name`](@ref)s.
- Interoperability
  - [TextParse.jl](https://github.com/queryverse/TextParse.jl): existing `TextParse.AbstractToken` implementations can be used with CombinedParsers. `CombinedParser` provide `TextParse.tryparsenext` and can be used e.g. in CSV.jl.
  - Pure Julia regular expression parsers are provided with the [`@re_str`](@ref) macro, a plug-in replacement for `Base.@r_str`.
    Tested on the [PCRE pattern test set](man/pcre-compliance.md).
- Generality
  - All valid parsings can be [`Base.iterate`](@ref)d lazily.
  - Higher-order parsers depending on the parsing state allow for not context-free parsers ([`after`](@ref)).
  - can process UTF8 strings or any sequence type supporting `getindex`, `nextind`, `prevind` methods.


## Getting started
The [Overview](@ref) provides a tutorial explaining how to get started using CombinedParsers.
The [User guide](man/user.md) provides a summary of CombinedParsers types and constructors.
Some examples of packages using CombinedParsers can be found on the [Examples](@ref) page.
See the [Index](@ref main-index) for the complete list of documented functions and types.

> `CombinedParsers.jl` is a registered package:
Install with
```julia
] add CombinedParsers
```

### Example: rational numbers arithmetics
Parsing is reading and transforming a sequence of characters.
`CombinedParsers` provides constructors to combine parsers and transform (sub-)parsings arbitrarily with julia syntax.
```@example session
using CombinedParsers
using TextParse
nothing # hide
```

This example reads and evaluates arithmetical terms for rational numbers.
The following defines an evaluating parser for rational number terms as sequences of subterms interleaved with operators.
```@setup session
function evaluate( (start, operation_values) )
    aggregated_value::Rational{Int} = start
    for (op,val) in operation_values
        aggregated_value = eval( Expr(:call, Symbol(op), 
			              aggregated_value, val
			              ))
    end
    return aggregated_value
end
```
Subterms are [`Either`](@ref) integer numbers, `TextParse.Numeric(Int)` converted to `Rational{Int}`,
or subterms are written as parentheses around a nested term:
```@example session
@syntax subterm = Either{Rational{Int}}(Any[TextParse.Numeric(Int)]);
@syntax for parenthesis in subterm
    mult         = evaluate |> join(subterm, CharIn("*/"), infix=:prefix )
    @syntax term = evaluate |> join(mult,    CharIn("+-"), infix=:prefix )
    Sequence(2,'(',term,')')
end;
nothing # hide
```
The [`@syntax`](@ref) definition in 5,5 lines is sufficient for parsing and evaluating arithmetics:
[`Base.join`](@ref)`(x, delimiter; infix=:prefix)` is shorthand for [`Sequence`](@ref)`(x ,`[`Repeat`](@ref)`( delimiter * x  ))`,
and `f |> parser` is shorthand for [`map`](@ref)`(f,parser)`.
That's all! [`@syntax`](@ref) registers a `@term_string` macro for parsing and transforming:
```@repl session
result_type(term)
term"(1+2)/5"
# The defined `CombinedParser` `term` function 
# provides optional logging of the parsing process.
term("1/((1+2)*4+3*(5*2))",log = [:parenthesis])
```
[Is every rational answer ultimately the inverse of a universal question in life?](https://en.wikipedia.org/wiki/Phrases_from_The_Hitchhiker%27s_Guide_to_the_Galaxy#Answer_to_the_Ultimate_Question_of_Life,_the_Universe,_and_Everything_(42))


Note: The `evaluate` function definition is detailed in [the full example](man/example-arithmetic.md).
```@repl session
evaluate( (0, [ ('+',1), ('-',2) ]) )
evaluate( (1, [ ('*',4), ('/',3) ]) )
```




  

## Useful Design
- [WikitextParser.jl](https://github.com/gkappler/WikitextParser.jl) is a `CombinedParser` for parsing [wikitext syntax](https://en.wikipedia.org/wiki/Help:Wikitext),
  quite comprehensibly and representing Wikipedia articles within Julia.
- OrgmodeParser.jl is a `CombinedParser` for parsing main [org mode](https://orgmode.org/) syntax,
  representing org files within Julia.
- [CombinedParserTools.jl](https://github.com/gkappler/CombinedParserTools.jl) is currently more or less my own workspace to provide a set of re-useable parsers, used in `WikitextParser`.
- [Tries.jl](https://github.com/gkappler/Tries.jl) is the abstract implementation of the fast prefix-tree matching in `CombinedParsers` (see [docs](https://gkappler.github.io/CombinedParsers.jl/dev/man/example-either-trie/))
If you want to work with any of these open source packages, I will gladly provide professional support.
If you are writing your own recursive `CombinedParser` and seek inspiration, you might find these comprehensive examples interesting.
(currently α release, so beware, dragons!)

The `CombinedParsers` design 
- is fast due to Julia parametric types, and compiler optimizations with generated functions,
- its strictly typed parsing defines the domain data types,
- is composable and optimizable with Julia method dispatch,
- provides flexible public API for parsing, matching, iteration

Making Julia parametric types central for the parser design equally allows automation of the data pipeline after parsing.

FilingForest demonstrates indexing the German Wiktionary into a columnar database, with fast selecting and measuring.
I am finishing the write-up of Wiktionary data parsing into a language graph database including:
- fast db-indexing of text streams (e.g. logging): If you need support indexing logging streams into a (SQL-)Database, the (currently) proprietary TypeGraphs.jl provides `CombinedParsers` plug and play: Table schemas are infered from your parser.
- fast out-of core data science/AI on your parsed data: If you need support with storing parsed data in optimized memory-mapped JuliaDB, TypeDB.jl provides `CombinedParsers` plug and play. 
- fast scientific measurements in a data graph: FilingForest IA.jl provides `CombinedParsers` plug and play: even for recursively nested data.
All (currently) proprietary packages are default-over-configuration for fast integration, and are in active development.
- fast HTTP-serving of parsed data: If you need support with a parsing server-client infrastructure, the (currently) proprietary GraphQLAlchemy.jl provides `CombinedParsers` plug and play: GraphQL schemas and resolver are infered from your parser.

## Optimization Strategy
With the C PCRE2 library testset, and for 58% of patterns, `CombinedParsers`  match faster than `Regex` (first 100 pattern).
C PCRE2 optimized is among the fastest regex libraries ([second behind Rust](https://github.com/mariomka/regex-benchmark/tree/optimized), running [mariomka](https://github.com/mariomka)'s benchmark will position CombinedParser among its competition).
Explorations for optimization are in git branches.
> All benchmarks are wrong, but some are useful - [Szilard](https://github.com/szilard), [benchm-ml](https://github.com/szilard/benchm-ml)
```@contents
Pages = [
    "man/pcre-compliance.md",
]
Depth = 5
```

The package is still young, and optimization is ongoing.
If you are interested in and able to dive deeper into the Julia memory layout and compiler, I would gladly collaborate on further optimizations:
- String layout: Parsing requires repeated Char comparisons. In UTF8, frequent characters are encoded shorter (8 bit), rare have longer codes.
  For this reason, in Julia `String` indices are not consecutive and transversal requires using infamous `nextind` and `prevind`.
  Profiling:
  - `nextind` and `prevind` comsume considerable time.  Could be cached/memoized?
  - `CombinedParsers` currently operates on the result of `getindex(::String,index)::Char` (technically on `iterate(::String,index)::Tuple{Char,Int}`).  Could matching use the raw byte representation directly?
- Macros: make all iteration `@generated` functions using expressions generated by a dispatched `iterate_expression` that can be used in a macro `@iterate` to generate an unrolled/unnested iteration code.
  (Profiling hints that function calls do hardly contribute to runtime.)



## Acknowledgements

This package is enabled only due to the Julia's compiler and superior type system.
Thankfully: a really concise language for powerful computing!

I am thankful for contributions and inspiration from many great packages:
### [TextParse.jl](https://github.com/queryverse/TextParse.jl)
> A bunch of fast text parsing tools, used in CSV.jl

`CombinedParsers` composes with fast
[TextParse.jl](https://github.com/queryverse/TextParse.jl) both ways 
because `CombinedParser <: TextParse.AbstractToken`
and by providing a method for `TextParse.tryparsenext`,
(leveraging the supreme Julia compiler, type and package architecture).

- If you seek support with a dates parser example, please contact me.
- If you seek support with a CSV example, please contact me (e.g. address text field parsing).


```@docs
CombinedParsers.tryparsenext
```
### Inspirations

- The work was strongly inspired by the great Scala [fastparse](https://github.com/lihaoyi/fastparse) package, and also the [elm parser](https://package.elm-lang.org/packages/elm/parser/latest/).
- [Parsers.jl](https://github.com/JuliaData/Parsers.jl), a collection of parsers for date and primitive types, inspired the [`parse`](@ref) methods.
- [Automa.jl](https://github.com/BioJulia/Automa.jl), a Julia package for text validation, parsing, and tokenizing based on state machine compiler.  The package compiles deterministic finite automata.  (Currently there is no inter-operation possible, because in `Automa` processing of parsed tokens is done with actions and UTF8 support is lacking).
- [ParserCombinator.jl](https://github.com/andrewcooke/ParserCombinator.jl) was a great inspiration.
  Yet I decided for a new design with a focus on transformations and type inference with parametric types, instead of basing this work off `ParserCombinator`, written before 2016 (and fixed for Julia 1.0 in 2018).
  `CombinedParsers` integrates into the Julia 1.0 Iteration API, small `Union{Nothing,T} where T` types instead of using Nullables, compiler optimizations and generated functions.
  I want to provide benchmarks comparisons with `ParserCombinator.jl`.


## Next Steps
- [ ] Syntax freeze -- your comments are appreciated!
- [ ] decide for a error tracing strategy, backtracking. If you want to collaborate on stepping & debugging, please reach out to me.
- [ ] Performance optimizations
- [ ] streaming
- [ ] test coverage underestimated (PCRE tests are not included in travis)
- [ ] [![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

# Contributing and Questions
Contributions and feedback are very welcome, 
especially regarding brief syntax and constructor dispatch. 
Please open an issue if you encounter any problems or would just like to ask a question,
or contact me at mail@g-kappler.de.


## Outline
### Manual
```@contents
Pages = [
	"man/guide.md",
	"man/user.md",
	"man/example-either-trie.md",
	]
Depth = 5
```

### Examples
```@contents
Pages = [
"man/example-person.md",
"man/example-number-ranges.md",
 "man/pcre.md",
 "man/example-palindromes.md",
 "man/json.md",
]
Depth = 5
```


### Library API

```@contents
Pages = [ "lib/public.md", "lib/internals.md" ]
Depth = 5
```
## [Index](@id main-index)

```@index
Pages = ["lib/public.md", "lib/internals.md"]
Modules = [ CombinedParsers, CombinedParsers.Regexp ]
Order = [ :function, :type ]
```

