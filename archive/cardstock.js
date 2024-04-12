#!/usr/bin/env node

function pretty_print(node, indent = '', last = true) {
    let marker = last ? "└──" : "├──";

    if(node.type === undefined) return false
    process.stdout.write(node.type)
    console.log('')
    process.stdout.write(indent)
    process.stdout.write(marker)

    indent += last ? "    " : "│   "

    let children = []
    for (const [key, entry] of Object.entries(node)) {
        children.push(entry)
    }

    for(let i=0;i<children.length;i++) {
        pretty_print(children[i], indent, i===children.length-1)
    }
}

const fs = require('fs')
const LexerClass = require('./lexer')
const ParserClass = require('./parser')

let lexer = new LexerClass()
let parser = new ParserClass()

if(process.argv[2] === null) {
    throw new Error('provide a file')
}

const in_string = fs.readFileSync(process.argv[2],
    { encoding: 'utf8', flag: 'r' })

const token_stream = lexer.tokenize(in_string)
//console.log(token_stream)

const ast = parser.parse(token_stream) 
console.log(JSON.stringify(ast,false,2))
