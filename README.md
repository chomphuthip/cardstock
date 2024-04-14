# cardstock
An expressive, dynamically typed language, running completely in Windows Powershell.

## Get Started!
cardstock runs in a single `.ps1` file. Download it or run this one-liner in your local Windows Powershell:


`iwr -useb https://raw.githubusercontent.com/chomphuthip/cardstock/main/cardstock.ps1|iex`

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
I was thinking about writing a tool for work, but I realized I can't really write, compile, and then download stuff on my work computer. Additionally, I would need to write a [DSL](https://en.wikipedia.org/wiki/Domain-specific_language) to configure and use it. This lead me to thinking about how interpreters work. Here I am, just a week later!

I think the next step would be to write a LALR(1) parser generator for Powershell. This would actually speed up the developement of those types of tools that would need a DSL to be used.
