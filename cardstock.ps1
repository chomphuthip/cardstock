$mode = ''
if($args.length -eq 1) { $mode = 'interpreter'}
if($args.length -eq 0) { $mode = 'repl'}
if($mode -eq '') { Throw 'Wrong Number of Arguments' }

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
            @{type = 'enum'; pattern = '^enum'},
            @{type = 'false'; pattern = '^false'},
            @{type = 'true'; pattern = '^true'},
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
            @{type = 'bang'; pattern = '^!'},
            @{type = 'plus'; pattern = '^\+'},
            @{type = 'minus'; pattern = '^-'},
            @{type = 'mult'; pattern = '^\*'},
            @{type = 'div'; pattern = '^\/'},
            @{type = 'lt'; pattern = '^<'},
            @{type = 'gt'; pattern = '^>'},
            @{type = 'le'; pattern = '^<='},
            @{type = 'ge'; pattern = '^>='},
            @{type = 'eq'; pattern = '^=='},
            @{type = 'eq'; pattern = '^!='},
            @{type = 'and'; pattern = '^&&'},
            @{type = 'or'; pattern = '^\|\|'},
            @{type = 'l_bracket'; pattern = '^\['},
            @{type = 'r_bracket'; pattern = '^\]'},
            @{type = 'assign'; pattern = '^='},
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
                $tok.value = [Int]$Matches[0]
            } elseif($tok.type -ceq 'string') { 
                $tok.value = $Matches[0].SubString(1, $len-1) 
            } else {
                $tok.value = $Matches[0]
            }
            return $tok
        }
        Throw ("Bad Token at $($this.line):$($this.col) ""$($this.input_string[$this.cursor])"" `n")
    }

    [Token[]]tokenize($input_string) {
        $tokens = @()
        $this.input_string = $input_string
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
        else {throw "Expected $($token_type) at $($cur.line):$($cur.col), got $($cur.value) instead `n$(Get-PSCallStack)"}
    }

    [Object]_delim($start_type, $end_type, $skip_tokens, $parser) {
        $this._next_if_cur($start_type)
        $children = @()
        if($this._cur().type -eq $end_type) { return $children }
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
            'true' {$res = $this._cur(); $this._next(); break}
            'false' {$res = $this._cur(); $this._next(); break}
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
                args = @($this._parse_expr())
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

        while($cur.value -eq '*' -or $cur.value -eq '/') {
            $this._next()
            $node = @{
                type = $cur.value
                left = $node
                right = $this._parse_unary()
            }
            cur = $this._cur()
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
                type = $cur.value
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

    [Object]_parse_expr_s() {
        return $this._parse_expr()
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
        $this._next_if_cur('enum')

        $name = $this._cur().value
        $this._next()

        $enums = $this._delim('l_bracket', 'r_bracket', @('comma', 'newline'), $this._parse_atom)
        return @{
            type = 'enum'
            name = $name
            enums = $enums
        }
    }

    [Object]_parse_init_var() {
        $this._next_if_cur('let')

        $name = $this._cur().value
        $this._next()

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
            'enum' { return $this._parse_enum() }
            'break' { return $this._parse_block_ctrl() }
            'continue' { return $this._parse_block_ctrl() }
            'return' { return $this._parse_block_ctrl() }
            'l_bracket' { return $this._parse_block() }
            default { return $this._parse_expr_s()}
        }
        Throw ("Bad Token at $($cur.line):$($cur.col) ""$($cur.value)""")
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

$in_string = $(Get-Content -Raw $args[0])
$lexer = [Lexer]::New()
$parser = [Parser]::New()


$token_stream = $lexer.tokenize($in_string)
#$token_stream | ConvertTo-Json | Out-File output.json

$ast = $parser.parse($token_stream)

$ast | ConvertTo-Json -Depth 100 | ForEach-Object {$_.replace('    ',' ')} | Out-File output.json