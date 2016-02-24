fm = require 'front-matter'
marked = require 'marked'
yaml = require 'js-yaml'
{parseFragment, treeAdapters} = require 'parse5'

converters = require './converters'
{cleanText, decodeHtmlEntities, nodeType, isBlock, isVoid} = require './utils'

treeAdapter = treeAdapters.default

###*
 * Some people accidently skip levels in their headers (like jumping from h1 to
   h3), which screws up things like tables of contents. This function fixes
   that.
 * The algorithm assumes that relations between nearby headers are correct and
   will try to preserve them. For example, "h1, h3, h3" becomes "h1, h2, h2"
   rather than "h1, h2, h3".
###
fixHeaders = (dom, ensureFirstHeaderIsH1) ->
  topLevelHeaders = [] # the headers that aren't nested in any other elements
  for child in dom.childNodes
    if /h[0-6]/.test child.nodeName
      topLevelHeaders.push child

  # there are no headers in this document, so skip
  if topLevelHeaders.length is 0 then return

  # by starting at 0, we force the first header to be an h1 (or an h0, but that
  # doesn't exist)
  lastHeaderDepth = 0

  if not ensureFirstHeaderIsH1
    # set the depth to `firstHeaderDepth - 1` so the rest of the function will
    # act as though that was the root
    lastHeaderDepth = topLevelHeaders[0].nodeName[1] - 1

  # we track the rootDepth to ensure that no headers go "below" the level of the
  # first one. for example h3, h4, h2 would need to be corrected to h3, h4, h3.
  # this is really only needed when the first header isn't an h1.
  rootDepth = lastHeaderDepth + 1

  i = 0
  while i < topLevelHeaders.length
    headerDepth = parseInt topLevelHeaders[i].nodeName[1]
    if rootDepth <= headerDepth <= lastHeaderDepth + 1
      lastHeaderDepth = headerDepth # header follows all rules, move on to next
    else
      # find all the children of that header and cut them down by the amount in
      # the gap between the offending header and the last good header. For
      # example, a jump from h1 to h3 would be `gap = 1` and all headers
      # directly following that h3 which are h3 or greater would need to be
      # reduced by 1 level. and of course the offending header is reduced too.
      # if the issue is that the offending header is below the root header, then
      # the same procedure is applied, but *increasing* the offending header &
      # children to the nearest acceptable level.
      if headerDepth <= rootDepth
        gap = headerDepth - rootDepth
      else
        gap = headerDepth - (lastHeaderDepth + 1)

      for e in [i...topLevelHeaders.length]
        childHeaderDepth = parseInt topLevelHeaders[e].nodeName[1]
        if childHeaderDepth >= headerDepth
          topLevelHeaders[e].nodeName = 'h' + (childHeaderDepth - gap)
        else
          break

      # don't let it increment `i`. we need to get the offending header checked
      # again so it sets the new `lastHeaderDepth`
      continue
    i++
  return

###*
 * Flattens DOM tree into single array
###
bfsOrder = (node) ->
  inqueue = [node]
  outqueue = []
  while inqueue.length > 0
    elem = inqueue.shift()
    outqueue.push elem
    for child in elem.childNodes
      if nodeType(child) is 1 then inqueue.push child

  outqueue.shift() # remove root node
  outqueue

###*
 * Contructs a Markdown string of replacement text for a given node
###
getContent = (node) ->
  if node.nodeName is '#text' then return node.value

  text = ''
  for child in node.childNodes
    text += (
      switch nodeType(child)
        when 1
          child._replacement
        when 3
          if node.nodeName in ['code', 'pre']
            # these tags contain whitespace-sensitive content, so we can't apply
            # advanced text cleaning
            decodeHtmlEntities(child.value)
          else
            cleanText(child.value)
    )
  text

canConvert = (node, filter) ->
  if typeof filter is 'string'
    return filter is node.nodeName
  if Array.isArray(filter)
    return node.nodeName.toLowerCase() in filter
  else if typeof filter is 'function'
    return filter(node)
  else
    throw new TypeError('`filter` needs to be a string, array, or function')
  return

###*
 * @return {Integer} The index of the given `node` relative to all the children
   of its parent
###
getNodeIndex = (node) ->
  node.parentNode.childNodes.indexOf(node)

getPreviousSibling = (node) ->
  node.parentNode.childNodes[getNodeIndex(node) - 1]

getNextSibling = (node) ->
  node.parentNode.childNodes[getNodeIndex(node) + 1]

isFlankedByWhitespace = (side, node) ->
  isFlanked = false
  if side is 'left'
    sibling = getPreviousSibling(node)
    regExp = /\s$/
  else
    sibling = getNextSibling(node)
    regExp = /^\s/

  if sibling and not isBlock(sibling)
    isFlanked = regExp.test getContent(sibling)
  isFlanked

flankingWhitespace = (node) ->
  leading = ''
  trailing = ''
  if not isBlock(node)
    content = getContent(node)
    hasLeading = /^\s/.test content
    hasTrailing = /\s$/.test content
    if hasLeading and not isFlankedByWhitespace('left', node)
      leading = ' '
    if hasTrailing and not isFlankedByWhitespace('right', node)
      trailing = ' '

  return {leading, trailing}

###
 * Finds a Markdown converter, gets the replacement, and sets it on
 * `_replacement`
###
process = (node) ->
  content = getContent(node)
  # Remove blank nodes
  if not isVoid(node) and node.nodeName isnt 'a' and /^\s*$/i.test(content)
    node._replacement = ''
    return

  for converter in converters
    if canConvert(node, converter.filter)
      if typeof converter.replacement isnt 'function'
        throw new TypeError(
          '`replacement` needs to be a function that returns a string'
        )
      whitespace = flankingWhitespace(node)
      if node.nodeName not in ['pre', 'ul', 'ol'] and
         node.parentNode.nodeName not in ['pre', 'ul', 'ol']
        # pre tags are whitespace-sensitive, and ul/ol tags are composed of li
        # tags, so they don't have leading/trailing whitespace, and stripping
        # them would screw up spacing around nested lists
        content = content.trim()
      replacement = (
        whitespace.leading +
        converter.replacement(content, node) +
        whitespace.trailing
      )
      break

  node._replacement = replacement
  return

removeEmptyNodes = (nodes) ->
  # remove whitespace text nodes
  for node in nodes
    emptyChildren = []
    for child in node.childNodes
      if child.nodeName is '#text' and child.value.trim() is ''
        previousSibling = getPreviousSibling(child)
        nextSibling = getNextSibling(child)
        if not previousSibling or not nextSibling or
           isBlock(previousSibling) or isBlock(nextSibling)
          emptyChildren.push(child)
    for child in emptyChildren
      treeAdapter.detachNode child

module.exports = (dirtyMarkdown, options = {}) ->
  if typeof dirtyMarkdown isnt 'string'
    throw new TypeError('Markdown input is not a string')

  options.ensureFirstHeaderIsH1 ?= true

  out = ''

  # handle yaml front-matter
  content = fm(dirtyMarkdown)
  if Object.keys(content.attributes).length isnt 0
    out += '---\n' + yaml.safeDump(content.attributes).trim() + '\n---\n\n'

  ast = marked.lexer(content.body)
  links = ast.links # see issue: https://github.com/chjj/marked/issues/472
  html = marked.parser(ast)

  # Escape potential ol triggers
  html = html.replace(/(\d+)\. /g, '$1\\. ')

  root = parseFragment(html)

  # remove empty nodes that are direct children of the root first
  removeEmptyNodes([root])

  fixHeaders(root, options.ensureFirstHeaderIsH1)
  nodes = bfsOrder(root)
  removeEmptyNodes(nodes)

  # Process nodes in reverse (so deepest child elements are first).
  for node in nodes by -1
    process node

  # remove this section because it fucks up code blocks with extra space in them
  out += getContent(root).trimRight().replace(
    /\n{3,}/g, '\n\n'
  ).replace(
    /^\n+/, ''
  ) + '\n'

  if Object.keys(links).length > 0 then out += '\n'
  for id, link of links
    optionalTitle = if link.title then " \"#{link.title}\"" else ''
    out += "[#{id}]: #{link.href}#{optionalTitle}\n"

  return out
