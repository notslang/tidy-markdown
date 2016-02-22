fm = require 'front-matter'
marked = require 'marked'
yaml = require 'js-yaml'
{parseFragment, serialize, treeAdapters} = require 'parse5'

blocks = require './block-tags'
converters = require './converters'
voids = require './void-tags'
{cleanText, decodeHtmlEntities, nodeType} = require './utils'
{stringRepeat, delimitCode} = require './utils'

treeAdapter = treeAdapters.default

###*
 * Utilities
###
isBlock = (node) -> node.nodeName in blocks
isVoid = (node) -> node.nodeName in voids

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
  text = ''
  for child in node.childNodes
    text += (
      switch nodeType(child)
        when 1
          child._replacement
        when 3
          if node.nodeName in ['code', 'pre']
            decodeHtmlEntities(child.value)
          else
            cleanText(child.value)
    )
  text

###*
 * Returns the HTML string of an element with its contents converted
###
outer = (node, content) ->
  serialize(node).replace '><', '>' + content + '<'

canConvert = (node, filter) ->
  if typeof filter is 'string'
    return filter is node.nodeName
  if Array.isArray(filter)
    return node.nodeName.toLowerCase() in filter
  else if typeof filter is 'function'
    return filter.call(toMarkdown, node)
  else
    throw new TypeError('`filter` needs to be a string, array, or function')
  return

isFlankedByWhitespace = (side, node) ->
  isFlanked = undefined
  if side is 'left'
    sibling = node.previousSibling
    regExp = RegExp(' $')
  else
    sibling = node.nextSibling
    regExp = /^ /
  if sibling
    if nodeType(sibling) is 3
      isFlanked = regExp.test(sibling.nodeValue)
    else if nodeType(sibling) is 1 and not isBlock(sibling)
      isFlanked = regExp.test(sibling.textContent)
  isFlanked

flankingWhitespace = (node) ->
  leading = ''
  trailing = ''
  if not isBlock(node)
    hasLeading = /^[ \r\n\t]/.test(node.innerHTML)
    hasTrailing = /[ \r\n\t]$/.test(node.innerHTML)
    if hasLeading and not isFlankedByWhitespace('left', node)
      leading = ' '
    if hasTrailing and not isFlankedByWhitespace('right', node)
      trailing = ' '
  {
    leading: leading
    trailing: trailing
  }

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
      if whitespace.leading or whitespace.trailing
        content = content.trim()
      replacement = (
        whitespace.leading +
        converter.replacement.call(toMarkdown, content, node) +
        whitespace.trailing
      )
      break

  node._replacement = replacement
  return

toMarkdown = (input, options = {}) ->
  options.ensureFirstHeaderIsH1 ?= true

  if typeof input isnt 'string'
    throw new TypeError("#{input} is not a string")
  # Escape potential ol triggers
  input = input.replace(/(\d+)\. /g, '$1\\. ')
  clone = parseFragment(input)
  fixHeaders(clone, options.ensureFirstHeaderIsH1)
  nodes = bfsOrder(clone)
  # remove whitespace text nodes
  for node in nodes
    emptyChildren = []
    for child in node.childNodes
      if child.nodeName is '#text' and child.value.trim() is ''
        emptyChildren.push(child)
    for child in emptyChildren
      treeAdapter.detachNode child

  # Process nodes in reverse (so deepest child elements are first).
  for node in nodes by -1
    process node

  # remove this section because it fucks up code blocks with extra space in them
  getContent(clone).trimRight().replace(
    /\n{3,}/g, '\n\n'
  ).replace(
    /^\n+/, ''
  ) + '\n'

toMarkdown.isBlock = isBlock
toMarkdown.outer = outer

module.exports = (dirtyMarkdown, options) ->
  out = ''

  # handle yaml front-matter
  content = fm(dirtyMarkdown)
  if Object.keys(content.attributes).length isnt 0
    out += '---\n' + yaml.safeDump(content.attributes).trim() + '\n---\n\n'

  html = marked(content.body)
  out += toMarkdown(html, options)

  ###
  ast = marked.lexer(content.body)

  # see issue: https://github.com/chjj/marked/issues/472
  links = ast.links

  if Object.keys(links).length > 0 then out.push ''
  for id, link of links
    optionalTitle = if link.title then " \"#{link.title}\"" else ''
    out.push "[#{id}]: #{link.href}#{optionalTitle}"

  # filter multiple sequential linebreaks
  out = out.filter (val, i, arr) -> not (val is '' and arr[i - 1] is '')
  ###
  return out
