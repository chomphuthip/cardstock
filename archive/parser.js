class Parser {

    constructor() {
        /* */
    }

    _cur() {
        return this.token_stream[this.cursor] || { type: 'eof', value: 'end'}
    }

    _next() {
        let cur = this._cur().value
        let next = this._peek().value
        
        this.cursor++
    }

    _peek() {
        return this.token_stream[this.cursor + 1] || { type: 'eof', value: 'end'}
    }

    _skip_expected(token_type) {
        let cur = this._cur()
        if(cur.type === token_type) return this._next()
        throw new Error(
            'Expected ' + token_type + 
            ' at ' + cur.line + ':' + cur.col + 
            ' instead got ' + this._cur().value)
    }

    /*
    atom = NUM | 
        STRING | 
        TRUE | 
        FALSE |
        SYMBOL |
        list |
        access
    */
    _parse_atom() {
        let res = null

        switch(this._cur().type) {
            case 'num': res = this._cur(); this._next(); break
            case 'true': res = this._cur(); this._next(); break
            case 'false': res = this._cur(); this._next(); break
            case 'string': res = this._cur(); this._next(); break
            case 'symbol': res = this._cur(); this._next(); break
            case 'l_bracket': res = this._parse_list(); break
            case 'lambda': res = this._parse_lambda(); break
            default: return null
        }
        //if next is a period or an l_bracket, do the loop
        while(this._cur().type === 'period' || this._cur().type === 'l_bracket') {
            if(this._cur().type === 'period') this._next()
            res = {
                type: 'access',
                of: res,
                args: [this._parse_atom()]
            }
        }
        return res
    }

    /*
    lambda = 
        '=>' '[' SYMBOL { ',' SYMBOL } ']' 
            '[' statement { '\n' statement } ']'
    */
    _parse_lambda() {
        this._skip_expected('lambda') //skip lambda token
        this._skip_expected('l_bracket') //skip l_bracket

        let parameters = []
        if(this._cur().type !== 'r_bracket') {
            parameters.push(this._cur())
            this._next()
            let cur = this._cur()
            while(cur.type === 'comma') {
                this._next()
                parameters.push(this._cur())
                this._next()
                cur = this._cur()
            }
        }
        this._skip_expected('r_bracket')

        let body = this._parse_block()
        return {
            type: 'lambda',
            parameters: parameters,
            body: body
        }
    }

    /*
    list = '[' exp { ',' exp } ']'
    */
    _parse_list() {
        this._next() //skip open bracket

        if(this._cur().type === 'r_bracket') return { type: 'list', elements: [] }

        let elements = []
        let cur = this._cur()

        do {
            if(elements.length !== 0) this._next()
            let exp = this._parse_exp()
            if(exp) elements.push(exp)
            cur = this._cur()
        } while(cur.type === 'comma')
        this._skip_expected('r_bracket')
        return {
            type: 'list',
            elements: elements
        }
    }

    /*
    un_op = 
        ( "!" | "-" ) un_op |
        atom ( "++"| "--" ) |
        atom
    */
    _parse_un() {
        let cur = this._cur()

        if(cur.type === 'minus') {
            this._next()
            return {
                type: 'negative',
                right: this._parse_atom()
            }
        }
        if(cur.type === 'bang') {
            this._next()
            let node = this._parse_atom()
            do {
                this._next()
                node = {
                    type: 'bang',
                    right: node
                }
                cur = this._cur()
            } while (cur.type === 'bang')
            return node
        }
        if(cur.type === 'inc' || cur.type === 'dec') {
            this._next()
            let node = {
                type: 'pre_' + cur.type,
                left: this._parse_atom()
            }
            return node
        }
        if(this._peek().type === 'inc' || this._peek().type === 'dec') {
            let node = {
                type: 'post_' + this._peek().type,
                left: this._parse_atom()
            }
            this._next()
            return node
        }
        return this._parse_atom()
    }

    /*
    term_op =
        un_op { ( "*" | "/" ) un_op }
    */
    _parse_term() {
        let node = this._parse_un()
        let cur = this._cur()

        while(cur.value === '*' || cur.value === '/') {
            this._next()
            node = {
                type: cur.value,
                left: node,
                right: this._parse_un()
            }
            cur = this._cur()
        }
        return node
    }

    /*
    alg_exp =
        term_op { ( "+" | "-" ) term_op }
    */
    _parse_alg() {
        let node = this._parse_term()
        let cur = this._cur()

        while(cur.value === '+' || cur.value === '-') {
            this._next()
            node = {
                type: cur.value,
                left: node,
                right: this._parse_ineq()
            }
            cur = this._cur()
        }
        return node
    }


    /*
    ineq_exp =
        alg_exp { ( ">" | ">=" | "<" | "<=" ) alg_exp}
    */
    _parse_ineq() {
        let node = this._parse_alg()
        let cur = this._cur()

        let ineq_syms = [">" , ">=", "<", "<="]
        while(ineq_syms.includes(cur.value)) {
            this._next()
            node = {
                type: cur.value,
                left: node,
                right: this._parse_ineq()
            }
            cur = this._cur()
        }
        return node
    }

    /*
    eq_exp = 
        ineq_exp { ( "!=" | "==" ) ineq_exp}
    */
    _parse_eq() {
        let node = this._parse_ineq()
        let cur = this._cur()

        while(cur.value === '!=' || cur.value === '==') {
            this._next()
            node = {
                type: cur.value,
                left: node,
                right: this._parse_ineq()
            }
            cur = this._cur()
        }
        return node
    }

    /*
    and_exp
        = eq_exp { "&&" eq_exp }
    */
    _parse_and() {
        let node = this._parse_eq()
        let cur = this._cur()

        while(cur.value === '&&') {
            this._next()
            node = {
                type: cur.value,
                left: node,
                right: this._parse_eq()
            }
            cur = this._cur()
        }
        return node
    }

    /*
    or_exp
        = and_exp { "||" and_exp }
    */
    _parse_or() {
        let node = this._parse_and()
        let cur = this._cur()

        while(cur.value === '||') {
            this._next()
            node = {
                type: cur.value,
                left: node,
                right: this._parse_and()
            }
            cur = this._cur()
        }
        return node
    }
    
    /*
    exp = or_exp
    */
    _parse_exp() {
        return this._parse_or()
    }

    /*
    block_ctrl =
        'return' exp |
        'continue' |
        'break'
    */
    _parse_block_ctrl() {
        let cur = this._cur()
        if(cur.type === 'return') {
            this._next()
            let exp = this._parse_exp()
            return {
                type: 'return',
                exp: exp
            }
        } else {
            this.next()
            return {
                type: cur.type
            }
        }
    }

    /*
    enum_dec =
        'enum' '[' SYMBOL { '\n' SYMBOL } ']'
    */
    _parse_enum() {
        this.next() //skip enum
        this._skip_expected('l_bracket') //skip left bracket
        
        let names = [this._cur().value]
        this._next()
        
        let cur = this._cur()
        while(cur.type === 'newline' || cur.type === 'semicolon') {
            this._next()
            names.push(this._cur().value)
            cur = this._cur()
        }
        this._skip_expected('r_bracket')
        return {
            type: 'enum',
            names: names
        }
    }

    /*
    init_var =
        'let' SYMBOL '=' exp
    */
    _parse_init_var() {
        this._next()

        let name = this._cur().value
        this._skip_expected('symbol')
        this._skip_expected('assign')

        let exp = this._parse_exp()
        return {
            type: 'init_var',
            name: name,
            exp: exp
        }
    }

    /*
    while_s =
        'while' '[' exp ']' 
            '[' statement { '\n' statement } ']'
    */
    _parse_while_s() {
        this._next() //skip at for token
        this._skip_expected('l_bracket') //skip at l_bracket
        
        let cond = this._parse_exp()

        this._skip_expected('r_bracket') //skip r_bracket

        let body = this._parse_block()
        return {
            type: 'while_s',
            cond: cond,
            body: body
        }
    }

    _parse_assign() {
        let symbol = this._cur()
        this._next() //skip symbol
        this._next() //skip operator

        let exp = this._parse_exp()
        return {
            type: 'assign',
            var_name: symbol,
            exp: exp
        }
    }


    /*
    block =
    '[' statement { '\n' statement } ']'
    */
    _parse_block() {
        this._skip_expected('l_bracket') //skip l_bracket

        let statements = []
        let cur = this._cur()
        do {
            if(cur.type === 'newline' || cur.type === 'semicolon') this._next()
            let statement = this._parse_statement()
            if(statement !== null) statements.push(statement)
            cur = this._cur()
        } while(cur.type === 'newline' || cur.type === 'semicolon')
        this._skip_expected('r_bracket')
        return {
            type: 'block',
            body: statements
        }
    }

    /*
    for_s =
        'for' '[' statement ';' exp ';' statement ']'
            '[' statement { '\n' statement }']'
    */
    _parse_for_s() {
        this._next() //pointing at for token
        this._skip_expected('l_bracket') //pointing at l_bracket
        
        let init = null
        if(this._peek().type !== 'semicolon')
            init = this._parse_statement()
        
        this._skip_expected('semicolon') //skip semicolon
        let cond = null
        if(this._peek().type !== 'semicolon')
            cond = this._parse_exp()

        this._skip_expected('semicolon') //skip semicolon
        let inc = null
        if(this._peek().type !== 'semicolon')
            inc = this._parse_statement()

        this._skip_expected('r_bracket') //skip r_bracket

        let body = this._parse_block()
        return {
            type: 'for_s',
            init: init,
            cond: cond,
            inc: inc,
            body: body
        }
    }

    /*
    if_s =
        'if' '[' exp ']' 
            '[' statement { '\n' statement }']'
    */
    _parse_if_s() {
        this._next() //pointing at if token
        this._skip_expected('l_bracket') //pointing at l_bracket
        
        //now pointing at conditional expression
        let cond = this._parse_exp()

        this._skip_expected('r_bracket') //pointing at r_bracket

        let body = this._parse_block()
        return {
            type: 'if_s',
            cond: cond,
            body: body
        }
    }

    _parse_exp_s() {
        return this._parse_exp()
    }
    
    /*
    func_dec =
        'fn' '[' SYMBOL { ',' SYMBOL } ']' 
            '[' statement {'\n' statement }']'
    */ 
    _parse_func_def() {
        this._next() //pointing at fn token
        let func_name = this._cur().value
        this._next()
        this._skip_expected('l_bracket') //pointing at l_bracket
        
        let parameters = []
        let cur = this._cur()
        if(cur.type !== 'r_bracket') {
            parameters.push(cur)
            this._next()
            cur = this._cur()
            while(cur.type === 'comma') {
                this._next()
                parameters.push(this._cur())
                this._next()
                cur = this._cur()
            }
        }
        this._skip_expected('r_bracket') //pointing at r_bracket

        let body = this._parse_block()
        return {
            type: 'func_def',
            func_name: func_name,
            parameters: parameters,
            body: body
        }
    }

    /*
    statement =
        access |
        func_dec |
        init_var |
        while_s |
        assign |
        block |
        for_s |
        exp_s |
        if_s
    */
    _parse_statement() {
        let cur = this._cur()

        if(cur.type === 'symbol') {
            let next = this._peek()
            if(next.value === '[') {
                return this._parse_atom()
            } else if(next.value === '.') {
                return this._parse_atom()
            } else if(next.value === '=') {
                return this._parse_assign()
            } else {
                return this._parse_exp_s()
            }
        }
        switch(cur.type) {
            case 'func': return this._parse_func_def()
            case 'if': return this._parse_if_s()
            case 'for': return this._parse_for_s()
            case 'let': return this._parse_init_var()
            case 'enum': return this._parse_enum()
            case 'while': return this._parse_while_s()
            case 'break': return this._parse_block_ctrl()
            case 'return': return this._parse_block_ctrl()
            case 'continue': return this._parse_block_ctrl()
            case 'l_bracket': return this._parse_block()
            default: return this._parse_exp_s()
        }
    }

    /*
        program = statement { '\n' statement }
    */
    _parse_program() {
        let statement = this._parse_statement()
        let cur = this._cur()
        
        let statements = [statement]
        while(cur.type === 'newline' || cur.type === 'semicolon') {
            this._next()
            let statement = this._parse_statement()
            if(statement) statements.push(statement)
            cur = this._cur()
        }
        return {
            type: 'program',
            statements: statements
        }
    }
    
    parse(token_stream) {
        this.token_stream = token_stream
        this.cursor = 0
        return this._parse_program()
    }
}

module.exports = Parser
