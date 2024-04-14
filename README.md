# cardstock
An expressive, dynamically typed language, running completely in Windows Powershell.

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
Powershell has unbeatable reach. You can distribute it with a one-liner, you don't even have to download the file, and that it runs on every Windows computer. 

I had thought of a simple Layer 1 network simulation tool that can traverse a graph of nodes, figuring out which nodes would be affected in the event one or more nodes went offline. 

To actually control it, you would need an easy way to tell the simulation to knock some off, import new data, recalculate which services would be affected; you would probably need a [DSL](https://en.wikipedia.org/wiki/Domain-specific_language). 

I wanted to see how hard it would be to implement the whole lexer, parser, and visitor in Powershell, allowing me to write specialized tools that can run anywhere and don't even have to write to disk.

I think the next step would be to write a LALR(1) parser generator for Powershell. This would drastically speed up the developement of Powershell tools that require a DSL to control them and is a super undertapped market.
