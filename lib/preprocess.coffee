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

module.exports = preprocessAST
