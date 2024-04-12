token_types = [
    {type: 'comment', pattern: /^\/\/.*/},
    {type: 'comment', pattern: /^\/\*.*\*\//s},
    {type: 'inc', pattern: /^\+\+/},
    {type: 'dec', pattern: /^--/},
    {type: 'let', pattern: /^let/},
    {type: 'enum', pattern: /^enum/},
    {type: 'return', pattern: /^return/},
    {type: 'lambda', pattern: /^=>/},
    {type: 'newline', pattern: /^\n/},
    {type: 'false', pattern: /^false/},
    {type: 'true', pattern: /^true/},
    {type: 'comma', pattern: /^,/},
    {type: 'semicolon', pattern: /^;/},
    {type: 'bang', pattern: /^!/},
    {type: 'plus', pattern: /^\+/},
    {type: 'minus', pattern: /^-/},
    {type: 'mult', pattern: /^\*/},
    {type: 'div', pattern: /^\//},
    {type: 'num', pattern: /^\d+\.?\d*/},
    {type: 'lt', pattern: /^</},
    {type: 'gt', pattern: /^>/},
    {type: 'le', pattern: /^<=/},
    {type: 'ge', pattern: /^>=/},
    {type: 'eq', pattern: /^==/},
    {type: 'eq', pattern: /^!=/},
    {type: 'and', pattern: /^&&/},
    {type: 'or', pattern: /^\|\|/},
    {type: 'string', pattern: /^(['"])((?:\\\1|(?:(?!\1).))*)\1/g},
    {type: 'func', pattern: /^fn/},
    {type: 'while', pattern: /^while/},
    {type: 'for', pattern: /^for/},
    {type: 'if', pattern: /^if/},
    {type: 'symbol', pattern: /^[A-Za-z_]+/},
    {type: 'l_bracket', pattern: /^\[/},
    {type: 'r_bracket', pattern: /^\]/},
    {type: 'assign', pattern: /^=/},
    {type: 'period', pattern: /^\./}
]

class Lexer {

    constructor(){
        /* */
    }

    _cur() {
        return this.input_string[this.cursor]
    }

    _next_char() {
        this.cursor++
        this.col++
    }

    _jump_ahead(j) {
        this.cursor += j
        this.col += j
    }

    _skip_comment(token_type) {
        if(token_type === 'line_comment') {
            let jump = this.input_string.slice(this.cursor).match(/\n/)
            this.line++
            this.cursor += jump
        } else {
            let jump = this.input_string.slice(this.cursor).match(/\*\//)
            let lines = this.input_string.slice(this.cursor).slice(0,jump)
                .reduce((p,c) => p += c === '\n' ? 1 : 0)
            this.line += lines
            this.cursor += jump
        }
    }

    _next_token() {
        while (this._cur() === ' ') {
            this._next_char()
        }
        if(this._cur() === '\n') {
            this.line++ 
            this.col = 0
        }

        let searchable = this.input_string.slice(this.cursor)

        for(let i = 0; i < token_types.length; i++) {
            let token_type = token_types[i]
            let tok = searchable.match(token_type.pattern)
            
            if (tok !== null) {
                return {
                    type: token_type.type,
                    value: ((token_type, token, lexer_state) => {
                        let len = token[0].length
                        if (token_type === 'num') {
                            lexer_state._jump_ahead(len)
                            return Number(token[0])
                        } else if (token_type === 'string') {
                            lexer_state._jump_ahead(len)
                            return token[0].slice(1,len-1)
                        } else {
                            lexer_state._jump_ahead(len)
                            return token[0]
                        }
                    })(token_type.type, tok, this),
                    col: this.col,
                    line: this.line
                }
            }
        }
        throw new Error('bad token at ' + this.cursor + 
                ': ' + this.input_string[this.cursor])
    }

    tokenize(input_string) {
        let tokens = []
        this.input_string = input_string.replace(/\r?\n$/, '')
        this.cursor = 0
        this.line = 1
        this.col = 0
        while (this._cur()) {
            let tok = this._next_token()
            if(tok.type === 'comment') continue
            tokens.push(tok)
        }
        return tokens
    }
}

module.exports = Lexer