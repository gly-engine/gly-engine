/**
 * javascript as of ES5 plus async/await, the only modern syntax allowed.
 * builtins newer than ES5 are caught by tsc (jsconfig.json lib).
 */
var modern = [
    ['ArrowFunctionExpression', 'arrow function'],
    ['ClassDeclaration', 'class'],
    ['ClassExpression', 'class'],
    ['TemplateLiteral', 'template literal'],
    ['VariableDeclaration[kind!="var"]', 'let/const'],
    ['ObjectPattern', 'destructuring'],
    ['ArrayPattern', 'destructuring'],
    ['SpreadElement', 'spread'],
    ['RestElement', 'rest parameter'],
    ['AssignmentPattern', 'default parameter'],
    ['ForOfStatement', 'for...of'],
    ['Property[shorthand=true]', 'shorthand property'],
    ['Property[method=true]', 'method shorthand'],
    ['Property[computed=true]', 'computed key'],
    ['FunctionDeclaration[generator=true]', 'generator'],
    ['FunctionExpression[generator=true]', 'generator'],
    ['BinaryExpression[operator="**"]', 'exponent operator'],
    ['AssignmentExpression[operator="**="]', 'exponent operator'],
    ['MetaProperty', 'new.target'],
    ['Literal[regex.flags=/[uy]/]', 'regex flag u/y'],
    ['Literal[raw=/^0[bBoO]/]', 'binary/octal literal']
]

module.exports = [
    {
        files: ['src/**/*.js'],
        languageOptions: {
            ecmaVersion: 2017,
            sourceType: 'commonjs'
        },
        rules: {
            'no-restricted-syntax': ['error'].concat(modern.map(function (rule) {
                return {selector: rule[0], message: rule[1] + ' is not allowed, write ES5.'}
            }))
        }
    }
]
