# cardstock
An expressive, multi-paradigm programming language, interpreted by a single Windows Powershell script.

## Get Started!
cardstock runs in a single `.ps1` file. Download it or run this one-liner in your local Windows Powershell:


`iwr -useb https://raw.githubusercontent.com/chomphuthip/cardstock/main/cardstock.ps1|iex`

Check out [SYNTAX.md](./SYNTAX.md) for syntax.

## Features
* Simple syntax: LL(1) parsable grammar with only 12 keywords
* Portability: can run on any Windows Computer
* Functional programming: functions are treated as first class citizens (you can write closures!)

## Example:
```
let foo = 0
let bar = 20
for[let i=0;i<10;i++][foo++;bar--]

//function that returns a lambda
fn foobar[x,y][return =>[z][print[x,y,z]]]

//currying
foobar[1,2][3]

//running a lambda after declaration
=>[x,y][return x+y][5,6] == 11

[
    let x = 3
    print['this is a block, which has its own scope']
    if[x<2][
        while[x<5][++x;print[x]]
    ]
]
```

## Inspiration
This was primarily a proof of concept for writing a parser in Powershell. In the future, I may write tools in Powershell that probably require a [DSL](https://en.wikipedia.org/wiki/Domain-specific_language) to operate.

I remember in 7th grade when I realised that the `()` and `[]` operators were just like the mathematical notation for a function's output. So, I thought it would be cool to write a language that only used brackets. Also, you need to press shift to type `()` and `{}` which is kind of annoying.

I think the next step would be to write a LALR(1) parser generator for Powershell. This would drastically speed up the developement of Powershell tools that require a DSL to control them.
