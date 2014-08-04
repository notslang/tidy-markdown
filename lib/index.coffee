marked = require 'marked'
Entities = require('html-entities').AllHtmlEntities

htmlEntities = new Entities()

`function stringRepeat(x, n) {
  var s = '';
  for (;;) {
    if (n & 1) s += x;
    n >>= 1;
    if (n) x += x;
    else break;
  }
  return s;
}`

module.exports = (dirtyMarkdown) ->
  ast = marked.lexer(dirtyMarkdown)
  out = []
  previousToken = ''
  ast = preprocessAST(ast)
  console.log JSON.stringify(ast, null, '  ')

  for token in ast
    token.indent ?= ''
    switch token.type
      when 'heading'
        if previousToken isnt '' then out.push ''
        out.push stringRepeat('#', token.depth) + ' ' + token.text
      when 'paragraph'
        if previousToken is 'paragraph' then out.push ''
        out.push token.indent + prettyInlineMarkdown(token).text.replace /\n/, ' '
      when 'text'
        out.push token.indent + prettyInlineMarkdown(token).text
      when 'code'
        out.push "```#{token.lang}\n#{token.text}\n```\n"

    previousToken = token.type

  return out.join('\n')

IMG_REGEX = /<img src="([^"]*)"(?: alt="([^"]*)")?(?: title="([^"]*)")?>/g
LINK_REGEX = /<a href="([^"]*)"(?: title="([^"]*)")?>([^<]*)<\/a>/g
CODE_REGEX = /<code>([^<]+)<\/code>/
prettyInlineMarkdown = (token) ->
  token.text = marked
    .inlineLexer(token.text, token.links or {})
    .replace /\u2014/g, '--' # em-dashes
    .replace /\u2018|\u2019/g, '\'' # opening/closing singles & apostrophes
    .replace /\u201c|\u201d/g, '"' # opening/closing doubles
    .replace /\u2026/g, '...' # ellipses
    .replace /<\/?strong>/g, '**'
    .replace /<\/?em>/g, '_'
    .replace /<\/?del>/g, '~~'
    .replace CODE_REGEX, (m, code) ->
      delimiter = '`'
      while ///([^`]|^)#{delimiter}([^`]|$)///.test code
        # make sure that the delimiter isn't being used inside of the text. if
        # it is, we need to increase the number of times the delimiter is
        # repeated.
        delimiter += '`'

      if code[0] is '`' then code = ' ' + code # add starting space
      if code[-1...] is '`' then code += ' ' # add ending space
      return delimiter + code + delimiter


    .replace IMG_REGEX, (m, url='', alt='', title) ->
      if title?
        url += " \"#{title.replace /\\|"/g, (m) -> "\\#{m}"}\""
      return "![#{alt}](#{url})"
    .replace LINK_REGEX, (m, url='', title, text='') ->
      if title?
        url += " \"#{title.replace /\\|"/g, (m) -> "\\#{m}"}\""
      return "[#{text}](#{url})"

  token.text = htmlEntities.decode(token.text)
  return token

nestingStartTokens = ['list_item_start', 'blockquote_start']
nestingEndTokens = ['list_item_end', 'blockquote_end']
nestContainingTokens = ['list_item', 'blockquote']
skippedTokens = ['list_start', 'list_end']
preprocessAST = (ast) ->
  # preprocess ast
  i = 0
  out = []
  while i < ast.length
    currentToken = ast[i]
    if currentToken.type in skippedTokens
      # do nothing
    else if currentToken.type in nestingStartTokens
      nestingStartToken = currentToken.type
      tokenIndex = nestingStartTokens.indexOf(nestingStartToken)
      nestingEndToken = nestingEndTokens[tokenIndex]
      currentToken.type = nestContainingTokens[tokenIndex]
      i++

      # if other nestingStartTokens of the same type open while looking for the
      # end of this subAST, make sure not to steal their nestingEndToken
      nestingLevel = 0
      subAST = []
      loop
        if ast[i].type is nestingEndToken
          if nestingLevel is 0
            break
          else
            nestingLevel--
        else if ast[i].type is nestingStartToken
          nestingLevel++

        subAST.push ast[i]
        i++
      for token in preprocessAST(subAST)
        token.nesting ?= []
        token.indent ?= ''
        token.nesting.push currentToken.type
        if token.nesting isnt [] and token.nesting.length > 1
          token.indent = '  ' + token.indent
        else if currentToken.type is 'blockquote'
          token.indent += '> '
        else if currentToken.type is 'list_item'
          token.indent += '- '
        else
          token.indent = '  ' + token.indent
        out.push token

    else
      out.push currentToken

    i++
  return out
