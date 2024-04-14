### Variable
```
let foo = 1
let bar = 'string'
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
### Lambda and Function
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
