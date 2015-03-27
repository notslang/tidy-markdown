marked = require 'marked'
Entities = require('html-entities').AllHtmlEntities
indent = require 'indent'
pad = require 'pad'
yaml = require 'js-yaml'
fm = require 'front-matter'


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

###*
 * Find the length of the longest string in an array
 * @param {String[]} array Array of strings
###
longestStringInArray = (array) ->
  longest = 0
  for str in array
    len = str.length
    if len > longest then longest = len
  return longest

###*
 * Wrap code with delimiters
 * @param {[type]} code
 * @param {[type]} delimiter The delimiter to start with, additional backticks
   will be added if needed; like if the code contains a sequence of backticks
   that would end the code block prematurely.
###
delimitCode = (code, delimiter) ->
  while ///([^`]|^)#{delimiter}([^`]|$)///.test code
    # make sure that the delimiter isn't being used inside of the text. if
    # it is, we need to increase the number of times the delimiter is
    # repeated.
    delimiter += '`'

  if code[0] is '`' then code = ' ' + code # add starting space
  if code[-1...] is '`' then code += ' ' # add ending space
  return delimiter + code + delimiter

IMG_REGEX = /<img src="([^"]*)"(?: alt="([^"]*)")?(?: title="([^"]*)")?>/g
LINK_REGEX = /<a href="([^"]*)"(?: title="([^"]*)")?>([^<]*)<\/a>/g
CODE_REGEX = /<code>([^<]+)<\/code>/g
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
    .replace CODE_REGEX, (m, code) -> delimitCode(code, '`')
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

nestingStartTokens = ['list_item_start', 'blockquote_start', 'loose_item_start']
nestingEndTokens = ['list_item_end', 'blockquote_end', 'loose_item_end']
nestContainingTokens = ['list_item', 'blockquote', 'loose_item']
preprocessAST = (ast) ->
  i = 0
  out = []
  orderedList = false
  while i < ast.length
    currentToken = ast[i]
    if currentToken.type is 'list_start'
      orderedListItemNumber = 0
      # this is actually all we need the list start token for
      orderedList = currentToken.ordered
    else if currentToken.type in nestingStartTokens
      tokenIndex = nestingStartTokens.indexOf(currentToken.type)
      currentToken.type = nestContainingTokens[tokenIndex]
      i++

      # there is no `loose_item_end` token, so we don't actually check the type
      # of the token that's closing a given nesting level... we just assume it's
      # correct.
      nestingLevel = 1
      subAST = []
      loop
        if ast[i].type in nestingEndTokens
          nestingLevel--
        else if ast[i].type in nestingStartTokens
          nestingLevel++

        if nestingLevel is 0
          break

        subAST.push ast[i]
        i++

      e = 0
      for token in preprocessAST(subAST)
        token.nesting ?= []
        token.indent ?= ''
        token.nesting.push currentToken.type
        if token.nesting isnt [] and token.nesting.length > 1
          token.indent = '  ' + token.indent
        else if currentToken.type is 'blockquote'
          token.indent += '> '
        else if currentToken.type is 'list_item'
          token.type = 'list_item'
          if orderedList
            orderedListItemNumber++
            token.indent += "#{orderedListItemNumber}. "
          else
            token.indent += '- '
        else if e is 0 and token.type is 'text' and
                currentToken.type is 'loose_item'
          token.type = 'list_item'
          token.indent += '- '
        else
          token.indent = '  ' + token.indent

        if token.type is 'text' and currentToken.type is 'loose_item'
          # text inside of a loose item is actually a `paragraph`... the ast
          # just calls it `text`
          token.type = 'paragraph'

        e++
        out.push token
    else
      out.push currentToken

    i++
  return out

###*
 * Some people accidently skip levels in their headers (like jumping from h1 to
 * h3), which screws up things like tables of contents. This function fixes
 * that.

 * The algorithm assumes that relations between nearby headers are correct and
 * will try to preserve them. For example, "h1, h3, h3" becomes "h1, h2, h2"
 * rather than "h1, h2, h3".
###
fixHeaders = (ast, ensureFirstHeaderIsH1) ->
  i = 0

  # by starting at 0, we force the first header to be an h1 (or an h0, but that
  # doesn't exist)
  lastHeaderDepth = 0

  if not ensureFirstHeaderIsH1
    e = 0
    while e < ast.length
      if ast[e].type isnt 'heading'
        e++ # keep going
      else
        # we found the first header, set the depth to `firstHeaderDepth - 1` so
        # the rest of the function will act as though that was the root
        lastHeaderDepth = ast[e].depth - 1
        break

  # we track the rootDepth to ensure that no headers go "below" the level of the
  # first one. for example h3, h4, h2 would need to be corrected to h3, h4, h3.
  # this is really only needed when the first header isn't an h1.
  rootDepth = lastHeaderDepth + 1

  while i < ast.length
    if ast[i].type isnt 'heading'
      # nothing
    else if rootDepth <= ast[i].depth <= lastHeaderDepth + 1
      lastHeaderDepth = ast[i].depth
    else
      # find all the children of that header and cut them down by the amount in
      # the gap between the offending header and the last good header. For
      # example, a jump from h1 to h3 would be `gap = 1` and all headers
      # directly following that h3 which are h3 or greater would need to be
      # reduced by 1 level. and of course the offending header is reduced too.
      # if the issue is that the offending header is below the root header, then
      # the same procedure is applied, but *increasing* the offending header &
      # children to the nearest acceptable level.
      e = i
      if ast[i].depth <= rootDepth
        gap = ast[i].depth - rootDepth
      else
        gap = ast[i].depth - (lastHeaderDepth + 1)
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

formatTable = (token) ->
  out = []
  for i in [0...token.header.length]
    col = [token.header[i]]
    for j in [0...token.cells.length]
      token.cells[j][i] = (
        if token.cells[j][i]?
          # https://github.com/chjj/marked/issues/473
          token.cells[j][i].trim()
        else
          ''
      )
      col.push token.cells[j][i]

    colWidth = longestStringInArray(col)
    token.header[i] = pad(token.header[i], colWidth)

    alignment = token.align[i]
    token.align[i] = (
      switch alignment
        when null then pad('', colWidth, '-')
        when 'left' then ':' + pad('', colWidth - 1, '-')
        when 'center' then ':' + pad('', colWidth - 2, '-') + ':'
        when 'right' then pad('', colWidth - 1, '-') + ':'
    )

    for j in [0...token.cells.length]
      token.cells[j][i] = (
        if alignment is 'right'
          pad(colWidth, token.cells[j][i])
        else
          pad(token.cells[j][i], colWidth)
      )

  # trimRight is to remove any trailing whitespace added by the padding
  if token.header.length > 1
    out.push token.header.join(' | ').trimRight()
    out.push token.align.join(' | ')

    for row in token.cells
      out.push row.join(' | ').trimRight()
  else
    # use a leading pipe for single col tables, otherwise the output won't
    # render as a table
    out.push '| ' + token.header[0].trimRight()
    out.push '| ' + token.align[0]

    for row in token.cells
      out.push '| ' + row[0].trimRight()

  out.push '' # newline after tables
  return out

module.exports = (dirtyMarkdown, options = {}) ->
  options.ensureFirstHeaderIsH1 ?= true

  out = []

  # handle yaml front-matter
  content = fm(dirtyMarkdown)
  if Object.keys(content.attributes).length isnt 0
    out.push '---', yaml.safeDump(content.attributes).trim(), '---\n'

  ast = marked.lexer(content.body)

  # see issue: https://github.com/chjj/marked/issues/472
  links = ast.links

  previousToken = undefined

  # remove all the `space` and `list_end` tokens - they're useless
  ast = ast.filter (token) -> token.type not in ['space', 'list_end']
  ast = preprocessAST(ast)
  ast = fixHeaders(ast, options.ensureFirstHeaderIsH1)

  for token in ast
    token.indent ?= ''
    token.nesting ?= []
    switch token.type
      when 'heading'
        if previousToken? and previousToken.type isnt 'heading' then out.push ''
        out.push stringRepeat('#', token.depth) + ' ' + token.text
      when 'paragraph'
        if previousToken?.type in ['paragraph', 'list_item', 'text']
          out.push ''
        out.push token.indent + prettyInlineMarkdown(token).text.replace /\n/g, ' '
      when 'text', 'list_item'
        if previousToken? and token.type is 'list_item' and
           (previousToken.nesting.length > token.nesting.length or
           (previousToken.type is 'paragraph' and
           previousToken.nesting?.length >= token.nesting.length))

          out.push ''
        out.push token.indent + prettyInlineMarkdown(token).text
      when 'code'
        token.lang ?= ''
        token.text = delimitCode("#{token.lang}\n#{token.text}\n", '```')
        out.push '', indent(token.text, token.indent), ''
      when 'table'
        if previousToken? then out.push ''
        out.push(formatTable(token)...)

      when 'hr'
        if previousToken? then out.push ''
        out.push token.indent + stringRepeat('-', 80), ''

      when 'html'
        out.push line for line in token.text.split('\n')

      else
        throw new Error("Unknown Token: #{token.type}")

    previousToken = token

  if Object.keys(links).length > 0 then out.push ''
  for id, link of links
    optionalTitle = if link.title then " \"#{link.title}\"" else ''
    out.push "[#{id}]: #{link.href}#{optionalTitle}"

  out.push '' # trailing newline

  # filter multiple sequential linebreaks
  out = out.filter (val, i, arr) -> not (val is '' and arr[i - 1] is '')
  return out.join('\n')
