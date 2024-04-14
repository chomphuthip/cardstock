Table of Contents
1. [Variables](###-Variables)
2. [List](###-List)
3. [Object](###-Object)
4. [Lambdas and Functions](###-Lambdas-and-Functions)
5. [If](###-If)
6. [Loops](###-Loops)
7. [Blocks](###-Blocks)
8. [I/O](###-I/O)
9. [REPL Commands](###-REPL-Commands)

### Variables
```
let foo = 1
let bar = 'string'
let baz = true
```
### List
```
let foo = [1, 2, 3]
```
### Object
```
let z = [
  prop1 = 'hello',
  prop2 = 2
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
