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
  ast = fixHeaders(ast)
  console.log JSON.stringify(ast, null, '  ')

  for token in ast
    token.indent ?= ''
    switch token.type
      when 'heading'
        if previousToken not in ['', 'heading'] then out.push ''
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

###*
 * Some people accidently skip levels in their headers (like jumping from h1 to
 * h3), which screws up things like tables of contents. This function fixes
 * that.

 * The algorithim assumes that relations between nearby headers are correct and
 * will try to preserve them. For example, "h1, h3, h3" becomes "h1, h2, h2"
 * rather than "h1, h2, h3".
###
fixHeaders = (ast) ->
  i = 0
  lastHeaderDepth = 0
  while i < ast.length
    if ast[i].type isnt 'heading'
      # nothing
    else if ast[i].depth <= lastHeaderDepth + 1
      lastHeaderDepth = ast[i].depth
    else
      # find all the children of that header and cut them down by the amount in
      # the gap between the offending header and the last good header. For
      # example, a jump from h1 to h3 would be `gap = 1` and all headers
      # directly following that h3 which are h3 or greater would need to be
      # reduced by 1 level.
      e = i
      gap = ast[i].depth - (lastHeaderDepth + 1)
      console.log gap
      parentDepth = ast[i].depth
      while e < ast.length
        if ast[e].type isnt 'heading'
          # nothing
        else if ast[e].depth >= parentDepth
          ast[e].depth -= gap
        else
          break
        e++

      # don't let it increment `i`. we need to get the offending header checked
      # again so it sets the new `lastHeaderDepth`
      continue
    i++
  return ast
