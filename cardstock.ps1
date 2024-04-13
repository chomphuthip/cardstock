$mode = ''
if($args.Count -eq 1) { $mode = 'i'}
if($args.Count -eq 0) { $mode = 'repl'}
if($mode -eq '') { Throw 'Wrong Number of Arguments' }

function console_log($obj) { $obj | ConvertTo-Json -Depth 100 | Out-Host}

class Token {
    [String] $type
    [Int] $line
    [Int] $col 
    [Object] $value

    Token() {
        $this.type = ''
        $this.value = ''
        $this.line = 0
        $this.col = 0
    }
}

class Lexer {
    [String] $input_string
    [Int] $cursor 
    [Int] $line
    [Int] $col 
    [Array] $token_types 

    Lexer() {
        $this.input_string = ''
        $this.cursor = 0
        $this.line = 1
        $this.col = 0
        $this.token_types = @(
            @{type = 'string'; pattern = "^(?<!\\)([""\']).*?(?<!\\)\1"},
            @{type = 'num'; pattern = '^\d+(\.\d+)?'},
            @{type = 'comment'; pattern = '^\/\/.*'},
            @{type = 'comment'; pattern = '^(?s)/\*.*?\*/'},
            @{type = 'return'; pattern = '^return'},
            @{type = 'while'; pattern = '^while'},
            @{type = 'enum_def'; pattern = '^enum'},
            @{type = 'bool'; pattern = '^false'},
            @{type = 'bool'; pattern = '^true'},
            @{type = 'for'; pattern = '^for'},
            @{type = 'let'; pattern = '^let'},
            @{type = 'fn_def'; pattern = '^fn'},
            @{type = 'if'; pattern = '^if'},
            @{type = 'inc'; pattern = '^\+\+'},
            @{type = 'dec'; pattern = '^--'},
            @{type = 'lambda'; pattern = '^=>'},
            @{type = 'newline'; pattern = '^\n'},
            @{type = 'comma'; pattern = '^,'},
            @{type = 'semicolon'; pattern = '^;'},
            @{type = 'plus'; pattern = '^\+'},
            @{type = 'minus'; pattern = '^-'},
            @{type = 'mult'; pattern = '^\*'},
            @{type = 'mod'; pattern = '^%'},
            @{type = 'div'; pattern = '^\/'},
            @{type = 'le'; pattern = '^<='},
            @{type = 'ge'; pattern = '^>='},
            @{type = 'eq'; pattern = '^=='},
            @{type = 'eq'; pattern = '^!='},
            @{type = 'and'; pattern = '^&&'},
            @{type = 'or'; pattern = '^\|\|'},
            @{type = 'l_bracket'; pattern = '^\['},
            @{type = 'r_bracket'; pattern = '^\]'},
            @{type = 'bang'; pattern = '^!'},
            @{type = 'lt'; pattern = '^<'},
            @{type = 'assign'; pattern = '^='},
            @{type = 'gt'; pattern = '^>'},
            @{type = 'symbol'; pattern = '^[A-Za-z_]+'},
            @{type = 'period'; pattern = '^\.'}
        )
    }

    [Object]_cur() {
        if ($this.cursor -ge $this.input_string.Length) { return 'EOF'}
        return $this.input_string[$this.cursor]
    }

    _next_char() {
        $this.cursor++
        $this.col++
    }

    _jump_ahead($j) {
        $substring = $this.input_string.SubString($this.cursor, $j)
        $newlines = [regex]::matches($substring, '\r\n')
        $this.line += $newlines.count
        if($newlines.count -ge 1) {$this.col = 0}
        $this.col += $j
        $this.cursor += $j
    }

    [Token]_next_token() {
        while(($this._cur() -ceq ' ') -or ($this._cur() -ceq "`r")) { $this._next_char() }

        $searchable = $this.input_string.SubString($this.cursor)
        foreach ($type in $this.token_types) {
            if(!($searchable -match $type.pattern)) { continue }

            $tok = [Token]::New()
            $tok.type = $type.type
            $tok.line = $this.line
            $tok.col = $this.col
            if($this._cur() -ceq "`n") { $this.line++; $this.col = 0}
            
            $len = $Matches[0].Length
            $this._jump_ahead($len)
            if($tok.type -ceq 'num') { 
                $tok.value = [Double]$Matches[0]
            } elseif($tok.type -ceq 'string') { 
                $tok.value = $Matches[0].SubString(1, $len-2) 
            } else {
                $tok.value = $Matches[0]
            }
            return $tok
        }
        Throw ("Lexing Error: Bad Input at $($this.line):$($this.col) ""$($this.input_string[$this.cursor])"" `n")
    }

    [Token[]]tokenize($input_string) {
        $tokens = @()
        $this.input_string = $input_string
        $this.cursor = 0
        $this.line = 1
        $this.col = 0
        while('EOF' -ne $this._cur()) {
            $tok = $this._next_token()
            if($tok.type -ceq 'comment') { continue }
            $tokens += $tok
        }
        return $tokens
    }
}

class Parser {
    [Token[]] $token_stream
    [Int] $cursor

    [Object]_cur() {
        if($this.cursor -ge $this.token_stream.Length) { return @{ type = 'EOF'; value = 'end'} }
        return $this.token_stream[$this.cursor]
    }

    _next() {
        $this.cursor++
    }

    [Token]_peek() {
        if($this.cursor + 1 -ge $this.token_stream.Length) { return @{ type = 'EOF'; value = 'end'} }
        return $this.token_stream[$this.cursor + 1]
    }

    _next_if_cur($token_type) {
        $cur = $this._cur()
        if($cur.type -eq $token_type) { $this._next() }
        else {throw "Parsing Error: Expected $($token_type) at $($cur.line):$($cur.col), got $($cur.value) ($($cur.type)) instead"}
    }

    [Object]_delim($start_type, $end_type, $skip_tokens, $parser) {
        $this._next_if_cur($start_type)
        $children = @()
        if($this._cur().type -eq $end_type) { $this._next(); return $children }
        while($this._cur().type -ne 'EOF') {
            if($this._cur().type -eq $end_type) { break }
            if($this._cur().type -in $skip_tokens) { $this._next() }
            $children += $($parser.Invoke())
            while($this._cur().type -in $skip_tokens) { $this._next() }
        }
        $this._next_if_cur($end_type)
        return $children
    }

    ##### EXPRESSIONS

    [Object]_parse_lambda() {
        $this._next_if_cur('lambda')

        $parameters = $this._delim('l_bracket', 'r_bracket', @('comma','newline'), $this._parse_atom)
        $body = $this._delim('l_bracket', 'r_bracket', @('semicolon','newline'), $this._parse_statement)
        
        return @{
            type = 'lambda'
            parameters = $parameters
            body = $body
        }
    }

    [Object]_parse_list() {
        $elements = $this._delim('l_bracket', 'r_bracket', @('comma','newline'), $this._parse_expr)
        return @{
            type = 'list'
            elements = $elements
        }
    }
    
    [Object]_parse_atom() {
        $res = $null
        switch($this._cur().type) {
            'num' {$res = $this._cur(); $this._next(); break}
            'bool' {$res = $this._cur(); $this._next(); break}
            'string' {$res = $this._cur(); $this._next(); break}
            'symbol' {$res = $this._cur(); $this._next(); break}
            'l_bracket' {$res = $this._parse_list(); break}
            'lambda' {$res = $this._parse_lambda(); break}
        }
        while(($this._cur().type -eq 'period') -or ($this._cur().type -eq 'l_bracket')) {
            if($this._cur().type -eq 'period') { $this._next() }
            $res = @{
                type = 'access'
                of = $res
                args = @($this._parse_list().elements)
            }
        }
        
        return $res
    }

    [Object]_parse_unary() {
        $cur = $this._cur()
        switch($cur.type) {
            'minus' { $this._next(); return @{ type = 'minus'; right = $this._parse_unary()}}
            'bang' { $this._next(); return @{ type = 'bang'; right = $this._parse_unary()}}
            'inc' { $this._next(); return @{ type = 'pre_inc'; right = $this._parse_atom()}}
            'dec' { $this._next(); return @{ type = 'pre_dec'; right = $this._parse_atom()}}
        }
        if(($this._peek().type -eq 'inc') -or ($this._peek().type -eq 'dec')) {
            $atom = $this._parse_atom()
            $type = $this._cur().type
            $this._next()
            return @{
                type = 'post_' + $type
                left = $atom
            }
        }
        return $this._parse_atom()
    }

    [Object]_parse_term() {
        $node = $this._parse_unary()
        $cur = $this._cur()

        while($cur.value -eq '*' -or $cur.value -eq '/' -or $cur.value -eq '%') {
            $this._next()
            $node = @{
                type = $cur.value
                left = $node
                right = $this._parse_unary()
            }
            $cur = $this._cur()
        }
        return $node
    }

    [Object]_parse_alg() {
        $node = $this._parse_term()
        $cur = $this._cur()

        while ($cur.value -eq '+' -or $cur.value -eq '-') {
            $this._next()
            $node = @{
                type = $cur.value
                left = $node
                right = $this._parse_ineq()
            }
            $cur = $this._cur()
        }
        return $node
    }

    [Object]_parse_ineq() {
        $node = $this._parse_alg()
        $cur = $this._cur()

        $ineq_syms = @(">" , ">=", "<", "<=")
        while($cur.value -in $ineq_syms) {
            $this._next()
            $node = @{
                type = $cur.value
                left = $node
                right = $this._parse_ineq()
            }
            $cur = $this._cur()
        }
        return $node
    }

    [Object]_parse_eq() {
        $node = $this._parse_ineq()
        $cur = $this._cur()

        while($cur.value -eq '!=' -or $cur.value -eq '==') {
            $this._next()
            $node = @{
                type = $cur.value
                left = $node
                right = $this._parse_ineq()
            }
            $cur = $this._cur()
        }
        return $node
    }

    [Object]_parse_and() {
        $node = $this._parse_eq()
        $cur = $this._cur()

        while($cur.value -eq '&&') {
            $this._next()
            $node = @{
                type = $cur.value
                left = $node
                right = $this._parse_eq()
            }
            $cur = $this._cur()
        }
        return $node
    }

    [Object]_parse_or() {
        $node = $this._parse_and()
        $cur = $this._cur()

        while($cur.value -eq '||') {
            $this._next()
            $node = @{
                type = $cur.value
                left = $node
                right = $this._parse_and()
            }
            $cur = $this._cur()
        }
        return $node
    }

    [Object]_parse_assign() {
        $node = $this._parse_or()
        $cur = $this._cur()

        while($cur.type -eq 'assign') {
            $this._next()
            $node = @{
                type = 'assign'
                left = $node
                right = $this._parse_or()
            }
            $cur = $this._cur()
        }
        return $node
    }

    [Object]_parse_expr() {
        return $this._parse_assign()
    }

    #### STATEMENTS

    [Object]_parse_expr_stmt() {
        return @{
            type = 'expr_stmt'
            expr = $this._parse_expr()
        }
    }

    [Object]_parse_fn_def() {
        $this._next_if_cur('fn_def')

        $name = $this._cur().value
        $this._next()

        $parameters = $this._delim('l_bracket', 'r_bracket', @('comma', 'newline'), $this._parse_atom)
        $body = $this._delim('l_bracket', 'r_bracket', @('semicolon', 'newline'), $this._parse_statement)
        return @{
            type = 'fn_def'
            name = $name
            parameters = $parameters
            body = $body
        }
    }

    [Object]_parse_enum_def() {
        $this._next_if_cur('enum_def')

        $name = $this._cur().value
        $this._next()

        $enums = $this._delim('l_bracket', 'r_bracket', @('comma', 'newline'), $this._parse_atom)
        return @{
            type = 'enum_def'
            name = $name
            enums = $enums
        }
    }

    [Object]_parse_init_var() {
        $this._next_if_cur('let')

        $name = $this._cur().value
        $this._next()

        $this._next_if_cur('assign')
        $expr = $this._parse_expr()
        return @{
            type = 'init_var'
            name = $name
            expr = $expr
        }
    }

    [Object]_parse_block() {
        $statements = $this._delim('l_bracket', 'r_bracket', @('semicolon','newline'), $this._parse_statement)
        return @{
            type = 'block'
            statements = $statements
        }
    }

    [Object]_parse_if() {
        $this._next_if_cur('if')

        $expr = $this._delim('l_bracket', 'r_bracket', @(), $this._parse_expr)
        $body = $this._delim('l_bracket', 'r_bracket', @('semicolon','newline'), $this._parse_statement)

        return @{
            type = 'if'
            expr = $expr
            body = $body
        }
    }

    [Object]_parse_while() {
        $this._next_if_cur('while')

        $expr = $this._delim('l_bracket', 'r_bracket', @(), $this._parse_expr)
        $body = $this._delim('l_bracket', 'r_bracket', @('semicolon','newline'), $this._parse_statement)

        return @{
            type = 'while'
            expr = $expr
            body = $body
        }
    }

    [Object]_parse_for() {
        $this._next_if_cur('for')
        
        $this._next_if_cur('l_bracket')

        $init = $this._parse_statement()
        $this._next_if_cur('semicolon')
        
        $expr = $this._parse_expr()
        $this._next_if_cur('semicolon')

        $inc = $this._parse_statement()
        $this._next_if_cur('r_bracket')

        $body = $this._delim('l_bracket', 'r_bracket', @('semicolon','newline'), $this._parse_statement)

        return @{
            type = 'for'
            init = $init
            expr = $expr
            inc = $inc
            body = $body
        }
    }

    [Object]_parse_block_ctrl() {
        if($this._cur().type -eq 'return') {
            $this._next_if_cur('return')
            return @{
                type = 'return'
                right = $this._parse_expr()
            }
        }
        return @{
            type = $this._cur().type
        }
    }

    [Object]_parse_assignment() {
        $name = $this._cur().value
        $this._next_if_cur('assign')
        $expr = $this._parse_expr()
        return @{
            type = 'assign'
            name = $name
            expr = $expr
        }
    }

    [Object]_parse_statement() {
        $cur = $this._cur()
        switch($cur.type) {
            'fn_def' { return $this._parse_fn_def() }
            'if' { return $this._parse_if() }
            'for' { return $this._parse_for() }
            'let' { return $this._parse_init_var() }
            'while' { return $this._parse_while() }
            'enum_def' { return $this._parse_enum() }
            'break' { return $this._parse_block_ctrl() }
            'continue' { return $this._parse_block_ctrl() }
            'return' { return $this._parse_block_ctrl() }
            'l_bracket' { return $this._parse_block() }
            default { return $this._parse_expr_stmt()}
        }
        Throw ("Parsing Error: Bad Token at $($cur.line):$($cur.col) ""$($cur.value)""")
    }

    [Object]_parse_program(){
        $statements = $this._delim('BOF', 'EOF', @('newline'), $this._parse_statement)
        return @{
            type = 'program'
            statements = $statements
        }
    }

    [Object]parse($token_stream){
        $this.token_stream = @(@{ type = 'BOF' }) + $token_stream + @(@{ type = 'EOF' })
        $this.cursor = 0
        return $this._parse_program()
    }
}

class Visitor {

    _new_scope($state) {
        $state.scopes += @{}
    }

    _cleanup_scope($state) {
        $state.scopes = $state.scopes[0..($state.scopes.Length-2)]
    }

    [Object]_collapse_list($list) {
        $res = @()
        foreach($e in $list.elements) {
            $res += $e.value
        }
        return $res
    }
    
    [Object]_collapse_simple($simple) {
        return $simple.value
    }

    [Object]_collapse($expr) {
        switch($expr.type) {
            'list' { return $this._collapse_list($expr)}
            default { return $this._collapse_simple($expr)}
        }
        Throw "Runtime Error: Bad Collapse Attempt"
    }

    [Object]_handle_collapsed($data, $arguments, $state) {
        if($data -is [Object[]]) { return $data[$arguments[0].value] }
        Throw "Runtime Error: Bad Collapse Access"
    }

    [Object]_handle_access($expr, $state) {
        if($expr.of.value -eq 'print') {
            console_log($expr.args[0])
            Write-Host $this._handle_expr($expr.args[0], $state)
            return $expr.args[0]
        }

        if($expr.of.type -eq 'list') {
            return $this._get($expr.of.value, $state)
        }
        if($expr.of.type -eq 'lambda') {
            $this._new_scope()
            for($i = 0; $i -lt $expr.of.args.Count; $i++) {
                $this._set($expr.of.args[$i], $expr.args[$i], $state)
            }
            return ($this._exec_body($expr.of.body, $state)).value
        }
        if($expr.of.type -eq 'access') {
            return $this._handle_access($expr.of, $state)
        }
        if($expr.of.type -eq 'symbol') {
            return $this._handle_collapsed($this._get($expr.of.value, $state), $expr.args, $state)
        }
        Throw "Runtime Error: Bad Access"
    }

    [Object]_handle_list($list, $state) {
        return $list
    }

    [Object]_handle_lambda($lambda, $state) {
        return $lambda
    }

    [Object]_handle_access_assign($expr, $state) {
        $value = $this._handle_expr($expr.right, $state)
        $state_cur = $value

        $expr_cur = $expr.left
        $state_cur = $this._get($expr.left.of.value, $state)

        if($state_cur -is [Object[]]) { $state_cur[$expr_cur.args[0].value] = $value; return $value}

        while($null -ne $expr_cur.args) {
            $arg = $expr_cur.args[0]
            if(!$state_cur[$arg.value]) { $state_cur[$arg] = @{} }
            $state_cur = $state_cur[$arg]
            $expr_cur = $expr_cur.of
        }
        return $value
    }

    [Object]_handle_symbol_assign($expr, $state) {
        $value = $this._collapse($this._handle_expr($expr.right, $state))
        $this._set($expr.left.value, $value, $state)
        return $true
    }

    [Object]_handle_assign($expr, $state) {
        if($expr.left.type -eq 'symbol') {return $this._handle_symbol_assign($expr, $state)}
        if($expr.left.type -eq 'access') {return $this._handle_access_assign($expr, $state)}
        Throw "Runtime Error: Invalid Assignment"
    }

    [Object]_handle_symbol($expr, $state) {
        return $this._get($expr.value, $state)
    }

    [Object]_handle_post_inc($expr, $state) {
        $val = $this._handle_symbol($expr.left, $state)
        $this._set($expr.left.value, $val + 1, $state)
        return $val
    }

    [Object]_handle_pre_inc($expr, $state) {
        $val = $this._handle_symbol($expr.left, $state)
        $this._set($expr.left.value, $val + 1, $state)
        return $val + 1
    }

    [Object]_handle_pre_dec($expr, $state) {
        $val = $this._handle_symbol($expr.left, $state)
        $this._set($expr.left.value, $val - 1, $state)
        return $val - 1
    }

    [Object]_handle_post_dec($expr, $state) {
        $val = $this._handle_symbol($expr.left, $state)
        $this._set($expr.left.value, $val - 1, $state)
        return $val
    }

    [Object]_handle_expr($expr, $state) {
        if($expr.type -eq 'num') { return $expr.value }
        if($expr.type -eq 'bool') { return $expr.value }
        if($expr.type -eq 'symbol') { return $this._handle_symbol($expr, $state)}
        if($expr.type -eq 'assign') { return $this._handle_assign($expr, $state)}
        if($expr.type -eq 'lambda') { return $this._handle_lambda($expr, $state)}
        if($expr.type -eq 'list') { return $this._handle_lambda($expr, $state)}
        if($expr.type -eq 'access') { return $this._handle_access($expr, $state)}
        if($expr.type -eq 'string') { return $expr.value }
        if($expr.type -eq 'post_inc') { return $this._handle_post_inc($expr, $state) }
        if($expr.type -eq 'pre_inc') { return $this._handle_pre_inc($expr, $state) }
        if($expr.type -eq 'post_dec') { return $this._handle_post_dec($expr, $state) }
        if($expr.type -eq 'pre_dec') { return $this._handle_pre_dec($expr, $state) }
        if($null -ne $expr.left -and $null -ne $expr.right) {
            $left = $this._handle_expr($expr.left, $state)
            $right = $this._handle_expr($expr.right, $state)
            switch($expr.type) {
                '+' { return $left + $right }
                '-' { return $left - $right }
                '*' { return $left * $right }
                '/' { return $left / $right }
                '%' { return $left % $right }
                '==' { return $left -ceq $right }
                '!=' { return $left -cne $right }
                '<' { return $left -lt $right }
                '<=' { return $left -le $right }
                '>' { return $left -gt $right }
                '>=' { return $left -ge $right }
                '&&' { return $left -and $right }
                '||' { return $left -or $right }
            }
        }
        Throw "Runtime Error: Unknown Expression Type: $($expr.type)"
    }

    [Object]_handle_expr_stmt($stmt, $state) {
        return $this._handle_expr($stmt.expr, $state)
    }

    [Object]_get($name, $state) {
        for($i = $state.scopes.Length-1; $i -ge 0; $i--){
            if($state.scopes[$i].ContainsKey($name)) { return $state.scopes[$i][$name] }
        }
        Throw "Runtime Error: $($name) not initialized"
    }

    [Object]_set($name, $value, $state) {
        if($null -eq $name) {Write-host $(Get-PSCallSTack)}
        for($i = $state.scopes.Length-1; $i -ge 0; $i--){
            if($state.scopes[$i].ContainsKey($name)) { $state.scopes[$i][$name] = $value}
        }
        return $true
    }

    [Object]_exec_body($statements, $state){
        foreach($statement in $statements) {
            $res = $this._handle_statement($statement, $state)
            if($res.signal -eq 'break') { return @{ signal = 'break' }}
            if($res.signal -eq 'continue') { return @{ signal = 'done' } }
            if($res.signal -eq 'return') { return @{ signal = 'return'; value = $res.value}}
        }
        return @{ signal = 'done' }
    }

    [Object]_handle_init_var($init_var_stmt, $state) {
        $state.scopes[-1][$init_var_stmt.name] = @{}
        $this._set($init_var_stmt.name, $this._collapse($this._handle_expr($init_var_stmt.expr, $state)), $state)
        return $this._get($init_var_stmt.name, $state)
    }

    [Object]_handle_fn_def($fn_def, $state) {
        $state.scopes[-1][$fn_def.name] = @{
            parameters = $fn_def.parameters
            body = $fn_def.body
        }
        return $state.scopes[-1][$fn_def.name]
    }

    [Object]_handle_if($if_stmt, $state) {
        $this._new_scope($state)
        $if = $this._handle_expr($if_stmt.expr, $state)
        $res = $null
        if($if) {$res = $this._exec_body($if_stmt.body, $state)}
        $this._cleanup_scope($state)
        return $res
    }

    [Object]_handle_for($for_stmt, $state) {
        $this._new_scope($state)
        $this._handle_statement($for_stmt.init, $state)
        $res = $null
        while($this._handle_expr($for_stmt.expr, $state)) {
            $res = $this._exec_body($for_stmt.body, $state)
            $this._handle_statement($for_stmt.inc, $state)
            if($res.signal -eq 'return') { return $res }
            if($res.signal -eq 'break') { break }
        }
        $this._cleanup_scope($state)
        return @{ signal = 'done' }
    }

    [Object]_handle_while($while_stmt, $state) {
        $this._new_scope($state)
        while($this._handle_expr($while_stmt.expr, $state)) {
            $res = $this._exec_body($while_stmt.body, $state)
            if($res.signal -eq 'return') { return $res }
            if($res.signal -eq 'break') { break }
        }
        $this._cleanup_scope($state)
        return @{ signal = 'done'}
    }

    [Object]_handle_enum_def($enum_def, $state) {
        $state.scopes[-1][$enum_def.name].type = 'enum'
        $state.scopes[-1][$enum_def.name].value = $enum_def.enums
        return @{ signal = 'done' }
    }

    [Object]_handle_break($stmt, $state) {
        return @{ signal = 'break' }
    }

    [Object]_handle_continue($stmt, $state) {
        return @{ signal = 'continue' }
    }

    [Object]_handle_return($stmt, $state)  {
        return @{ signal = 'return '; value = $this._parse_expr($stmt.right, $state)}
    }

    [Object]_handle_block($stmt, $state)  {
        $this._new_scope($state)
        $this._exec_body($stmt.statements, $state)
        $this._cleanup_scope($state)
        return @{ signal = 'done' }
    }

    [Object]_handle_statement($statement, $state) {
        console_log($statement)
        switch($statement.type) {
            'init_var' { return $this._handle_init_var($statement, $state) }
            'fn_def' { return $this._handle_fn_def($statement, $state) }
            'enum_def' { return $this._handle_enum_def($statement, $state) }
            'if' { return $this._handle_if($statement, $state) }
            'for' { return $this._handle_for($statement, $state) }
            'while' { return $this._handle_while($statement, $state) }
            'break' { return $this._handle_break($statement, $state) }
            'continue' { return $this._handle_continue($statement, $state) }
            'return' { return $this._handle_return($statement, $state) }
            'block' { return $this._handle_block($statement, $state) }
            'expr_stmt' { return $this._handle_expr_stmt($statement, $state) }
        }
        Throw "Runtime Error: Bad Statement Type: $($statement.type)"
    }

    [Object]_handle_program($AST, $state) {
        foreach ($statement in $AST.statements) {
            if($AST.statements.Count -gt 0) {$this._handle_statement($statement, $state)}
        }
        return $state
    }

    [Object]walk($AST,$state) {
        return $this._handle_program($AST, $state)
    }
}


$lexer = [Lexer]::New()
$parser = [Parser]::New()
$visitor = [Visitor]::New()

if($mode -eq 'i') {
    $in_string = $(Get-Content -Raw $args[0])
    $token_stream = $lexer.tokenize($in_string)
    #$token_stream | ConvertTo-Json -Depth 100 | ForEach-Object {$_.replace('    ',' ')} | Out-File tokens.json

    $ast = $parser.parse($token_stream)
    $ast | ConvertTo-Json -Depth 100 | ForEach-Object {$_.replace('    ',' ')} | Out-File ast.json

    $state = @{ scopes = @(@{}) }
    $visitor.walk($ast, $state)
} else {
    $state = @{ scopes = @(@{}) }
    while(1) {
        $fart = Read-Host
        $token_stream = $lexer.tokenize($fart)
        $ast = $parser.parse($token_stream)
        $state = $visitor.walk($ast, $state)
    }
}