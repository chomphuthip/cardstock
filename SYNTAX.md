Table of Contents
1. [Variables](#variables)
2. [Lists](#lists)
3. [Objects](#objects)
4. [Lambdas and Functions](#lambdas-and-functions)
5. [If](#if)
6. [Loops](#loops)
7. [Blocks](#blocks)
8. [I/O](#io)
9. [REPL Commands](#repl-commands)

### Variables
```
let foo = 1
let bar = 'string'
let baz = true
```
### Lists
```
let foo = [1, 2, 3]
```
### Objects
```
let z = [
  p1 = 'hello',
  p2 = 2
]
```
### Lambdas and Functions
```
// =>[parameter1, parameterN][ statement1, statementN]
let square = =>[x][return x*x]

//returning a lambda (when you return a fn_def type, the scope is preserved with the function definition)
fn curried_add [x] [
  return =>[y][return x+y]
]
```

### If
```
if[foo == bar] [
  print['foo is equal to bar']
]
if[x == 5][print['x is equal to 5]]else[print['x is not equal to 5']
```

### Loops
```
//standard C-style loops
for[let i=0;i<5;i++][print[i*5]]

while[i<5][print[i++]]
```

### Blocks
```
//blocks have their own scope
[
  let x = 5
]

[
  // this will be an uninitialized error
  print[x]
]
```

### I/O
```
//runs another file and adds global state as another scope on top
import['cool_functions.crd']

//if its being assigned to a variable, that variable will hold the state instead
let z = import['cool_methods.crd']
z.cool_method[]

let user_input = input['Write your name: ']
print['Hello ' + user_input + '!']
```

### REPL Commands
```
.tokens to show token stream
.ast to show AST
.state to show the state
.exit to exit
```
