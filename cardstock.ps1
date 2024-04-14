$mode = ''
if($args.Count -eq 1) { $mode = 'i'}
if($args.Count -eq 0) { $mode = 'repl'}
if($mode -eq '') { Throw 'Wrong Number of Arguments' }

function console_log($obj) { $obj | ConvertTo-Json -Depth 100 | ForEach-Object {$_.replace('    ',' ')} | Out-Host}

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
            @{type = 'num'; pattern = '^\d+(\.\d+)?'},
            @{type = 'comment'; pattern = '^\/\/.*'},
            @{type = 'comment'; pattern = '^(?s)/\*.*?\*/'},
            @{type = 'return'; pattern = '^return'},
            @{type = 'break'; pattern = '^break'},
            @{type = 'continue'; pattern = '^continue'},
            @{type = 'while'; pattern = '^while'},
            @{type = 'else'; pattern = '^else'},
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
            @{type = 'period'; pattern = '^\.'},
            @{type = 'string'; pattern = "^(?<!\\)([""\']).*?(?<!\\)\1"}
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
        while(($this._cur() -ceq ' ') -or ($this._cur() -ceq "`r") -or ($this._cur() -ceq "`t")) { $this._next_char() }

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
            type = 'fn_def'
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
            if($this._cur().type -eq 'period') { 
                $this._next() 
                $sym = $this._cur()
                $this._next_if_cur('symbol')
                $res = @{
                    type = 'access'
                    subtype = 'prop'
                    of = $res
                    args = @($sym)
                }
            } else {
                $res = @{
                    type = 'access'
                    subtype = 'hash'
                    of = $res
                    args = @($this._parse_list().elements)
                }
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

        $else_body = $null
        if($this._cur().type -eq 'else') {
            $this._next_if_cur('else')
            $else_body = $this._delim('l_bracket', 'r_bracket', @('semicolon','newline'), $this._parse_statement)
        }
        return @{
            type = 'if'
            expr = $expr
            body = $body
            else_body = $else_body
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
        $type = $this._cur().type
        $this._next()
        return @{
            type = $type
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

    [Object]_handle_access($expr, $state) {
        if($expr.of.value -eq 'print') {
            $display = ''
            foreach($arg in $expr.args) {
                $display += $this._handle_expr($arg, $state)
                $display += " "
            }
            Write-Host $display
            return $display
        }
        if($expr.of.value -eq 'input') {
            Write-Host $this._handle_expr($expr.args[0], $state) -NoNewLine
            return $global:Host.UI.ReadLine()
        }
        if($expr.of.value -eq 'import') {
            $in_string = $(Get-Content -Raw $($this._handle_expr($expr.args[0], $state)))
            $lexer = [Lexer]::New()
            $parser = [Parser]::New()
            $state = @{ scopes = @(@{}) }
            $foreign_state = $this.walk($parser.parse($lexer.tokenize($in_string)), $state)
            return $foreign_state.scopes[-1]
        }

        $cur = $expr.of
        if($expr.of.type -eq 'symbol') {
            $cur = $this._get($expr.of.value, $state)
        }
        if($expr.of.type -eq 'access') {
            $cur = $this._handle_access($expr.of, $state)
        }
        if($cur.type -eq 'fn_def') {
            $this._new_scope($state)
            for($i = 0; $i -lt $cur.parameters.Count; $i++) {
                $this._set($cur.parameters[$i].value, $this._handle_expr($expr.args[$i], $state), $state)
            }
            if($cur.ContainsKey('priv_scope')) { $state.scopes += $cur.priv_scope}
            $res = $this._exec_body($cur.body, $state)
            $this._cleanup_scope($state)
            return $res.value
        } else {
            $cur = $expr
            $arg_chain = @()
            while($cur.type -eq 'access') {
                if($cur.subtype -eq 'prop') {$arg_chain += $cur.args[0].value}
                if($cur.subtype -eq 'hash') {$arg_chain += $this._handle_expr($cur.args[0], $state)}
                $cur = $cur.of
            }
            $res = $this._get($cur.value, $state)
            for($i = $arg_chain.Length-1; $i -ge 0; $i--) {
                if($res -is [Object[]]) {$res = $res[$arg_chain[$i]]; continue }
                if($res -is [Object]) {$res = $res.($arg_chain[$i]); continue }
            }
            return $res
        }
        Throw "Runtime Error: Bad Access" 
    }

    [Object]_handle_list($list, $state) {
        $this._new_scope($state)
        $res = @()
        foreach($e in $list.elements) {
            $res += ,$this._handle_expr($e, $state)
        }
        if($state.scopes[-1].Keys.Count -gt 0) { $res = $state.scopes[-1]}
        $this._cleanup_scope($state)
        return $res
    }

    [Object]_handle_lambda($lambda, $state) {
        return $lambda
    }

    [Object]_handle_access_assign($expr, $state) {
        $value = $this._handle_expr($expr.right, $state)

        $ast_cur = $expr
        $arg_chain = @()
        while ($ast_cur.type -eq 'access') {
            if($ast_cur.subtype -eq 'prop') {$arg_chain += $ast_cur.args[0].value}
            if($ast_cur.subtype -eq 'hash') {$arg_chain += $this._handle_expr($ast_cur.args[0], $state)}
            $ast_cur = $ast_cur.of
        }
        $mem_cur = $state[$ast_cur.value]
        for ($i = $arg_chain.Length - 1; $i -ge 1; $i--) {
            $mem_cur = $mem_cur[$arg_chain[$i]]
        }
        $mem_cur[$arg_chain[0]] = $value
        return $value
    }

    [Object]_handle_symbol_assign($expr, $state) {
        $value = $this._handle_expr($expr.right, $state)
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
        if($expr.type -eq 'fn_def') { return $this._handle_lambda($expr, $state)}
        if($expr.type -eq 'list') { return $this._handle_list($expr, $state)}
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
        console_log($expr)
        Throw "Runtime Error: Unknown Expression Type: $($expr.type)"
    }

    [Object]_handle_expr_stmt($stmt, $state) {
        $val = $this._handle_expr($stmt.expr, $state)
        return $val
    }

    [Object]_get($name, $state) {
        for($i = $state.scopes.Length-1; $i -ge 0; $i--){
            if($state.scopes[$i].ContainsKey($name)) { return $state.scopes[$i][$name] }
        }
        Throw "Runtime Error: $($name) not initialized"
    }

    [Object]_set($name, $value, $state) {
        if($null -eq $name) {Write-host $(Get-PSCallSTack)}
        $set = $false
        for($i = $state.scopes.Length-1; $i -ge 0; $i--){
            if($state.scopes[$i].ContainsKey($name)) { $state.scopes[$i][$name] = $value; $set = $true}
        }
        if(!$set) { $state.scopes[-1][$name] = $value }
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
        $this._set($init_var_stmt.name, $this._handle_expr($init_var_stmt.expr, $state), $state)
        return $this._get($init_var_stmt.name, $state)
    }

    [Object]_handle_fn_def($fn_def, $state) {
        $state.scopes[-1][$fn_def.name] = $fn_def
        return $state.scopes[-1][$fn_def.name]
    }

    [Object]_handle_if($if_stmt, $state) {
        $this._new_scope($state)
        $if = $this._handle_expr($if_stmt.expr, $state)
        $res = $null
        if($if) {
            $res = $this._exec_body($if_stmt.body, $state)
        } elseif ($null -ne $if_stmt.else_body) {
            $res = $this._exec_body($if_stmt.else_body, $state)
        }
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

    [Object]_handle_break($stmt, $state) {
        return @{ signal = 'break' }
    }

    [Object]_handle_continue($stmt, $state) {
        return @{ signal = 'continue' }
    }

    [Object]_handle_return($stmt, $state)  {
        $val = $this._handle_expr($stmt.right, $state)
        if($val.type -eq 'fn_def') {$val.priv_scope = $state.scopes[-1]}
        return @{ signal = 'return'; value = $val}
    }

    [Object]_handle_block($stmt, $state)  {
        $this._new_scope($state)
        $this._exec_body($stmt.statements, $state)
        $this._cleanup_scope($state)
        return @{ signal = 'done' }
    }

    [Object]_handle_statement($statement, $state) {
        switch($statement.type) {
            'init_var' { return $this._handle_init_var($statement, $state) }
            'fn_def' { return $this._handle_fn_def($statement, $state) }
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
            if($AST.statements.Count -gt 0) {
                $res = $this._handle_statement($statement, $state)
                if($statement.type -eq 'expr_stmt') {
                    $dont_print = @('print', 'import')
                    if($statement.expr.of.value -notin $dont_print) {Write-Host $res}
                    if($statement.expr.of.value -eq 'import') {$state.scopes += $res}
                }
            }
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

function brackets_balanced() {
    param($token_stream)
    $l_b = 0
    $r_b = 0
    foreach($token in $token_stream) {
        if($token.type -eq 'l_bracket') { $l_b++ }
        if($token.type -eq 'r_bracket') { $r_b++ }
    }
    if($l_b -ne $r_b) { return $false } else { return $true }
}

if($mode -eq 'i') {
    $in_string = $(Get-Content -Raw $args[0])
    $token_stream = $lexer.tokenize($in_string)
    #$token_stream | ConvertTo-Json -Depth 100 | ForEach-Object {$_.replace('    ',' ')} | Out-File tokens.json

    $ast = $parser.parse($token_stream)
    $ast | ConvertTo-Json -Depth 100 | ForEach-Object {$_.replace('    ',' ')} | Out-File ast.json

    $state = @{ scopes = @(@{}) }
    if(!$visitor.walk($ast, $state)) {Throw "Something Went Wrong"}
} else {
    $state = @{ scopes = @(@{}) }
    $show_tokens = $false
    $show_ast = $false
    $show_state = $false

    while(1) {
        $user_input = Read-Host ">>"
        if($user_input -ceq '.tokens') {$show_tokens = !$show_tokens; continue}
        if($user_input -ceq '.ast') {$show_ast = !$show_ast; continue}
        if($user_input -ceq '.state') {$show_state = !$show_state; continue}
        if($user_input -ceq '.exit') { break }

        try {
            $token_stream = $lexer.tokenize($user_input)
            while(-not (brackets_balanced($token_stream))) {
                $user_input = Read-Host "::"
                $token_stream += $lexer.tokenize($user_input)
            }
            if($show_tokens) {console_log($token_stream)}

            $ast = $parser.parse($token_stream)
            if($show_ast) {console_log($ast)}

            $state = $visitor.walk($ast, $state)
            if($show_state) {console_log($state)}
        } catch {
            Write-Host $_.Exception.Message
            continue
        }
    }
}