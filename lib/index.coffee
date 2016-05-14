_ = require 'lodash'
fm = require 'front-matter'
marked = require 'marked'
yaml = require 'js-yaml'
{parseFragment} = require 'parse5'

converters = require './converters'
treeAdapter = require './tree-adapter'
{cleanText, decodeHtmlEntities, isBlock, isVoid} = require './utils'

{
  createElement
  detachNode
  getCommentNodeContent
  getTextNodeContent
  insertBefore
  insertText
  isCommentNode
  isElementNode
  isTextNode
} = treeAdapter

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
    if /h[0-6]/.test child.tagName
      topLevelHeaders.push child

  # there are no headers in this document, so skip
  if topLevelHeaders.length is 0 then return

  # by starting at 0, we force the first header to be an h1 (or an h0, but that
  # doesn't exist)
  lastHeaderDepth = 0

  if not ensureFirstHeaderIsH1
    # set the depth to `firstHeaderDepth - 1` so the rest of the function will
    # act as though that was the root
    lastHeaderDepth = topLevelHeaders[0].tagName[1] - 1

  # we track the rootDepth to ensure that no headers go "below" the level of the
  # first one. for example h3, h4, h2 would need to be corrected to h3, h4, h3.
  # this is really only needed when the first header isn't an h1.
  rootDepth = lastHeaderDepth + 1

  i = 0
  while i < topLevelHeaders.length
    headerDepth = parseInt topLevelHeaders[i].tagName[1]
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
        childHeaderDepth = parseInt topLevelHeaders[e].tagName[1]
        if childHeaderDepth >= headerDepth
          topLevelHeaders[e].tagName = 'h' + (childHeaderDepth - gap)
        else
          break

      # don't let it increment `i`. we need to get the offending header checked
      # again so it sets the new `lastHeaderDepth`
      continue
    i++
  return

convertCommentNode = (node) ->
  commentElement = createElement('_comment', null, [])
  insertText(commentElement, getCommentNodeContent(node))
  insertBefore(node.parent, commentElement, node)
  detachNode(node)
  return commentElement

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
      if isCommentNode(child) then child = convertCommentNode(child)
      if isElementNode(child) then inqueue.push child

  outqueue.shift() # remove root node
  outqueue

###*
 * Contructs a Markdown string of replacement text for a given node
###
getContent = (node) ->
  if isTextNode(node) then return getTextNodeContent(node)

  content = ''
  previousSibling = null
  for child in node.childNodes
    childText = (
      if isElementNode(child)
        child._replacement
      else if isTextNode(child)
        cleanText(child)
      else
        throw new Error("Unsupported node type: #{child.type}")
    )

    # prevent extra whitespace around `<br>`s
    if child.tagName is 'br' then content = content.trimRight()
    if previousSibling?.tagName is 'br' then childText = childText.trimLeft()

    if previousSibling?
      whitespaceSeparator = (
        (child._whitespace?.leading or '') +
        (previousSibling?._whitespace?.trailing or '')
      ).replace(
        /\n{3,}/, '\n\n'
      )
      content += whitespaceSeparator

    content += childText
    previousSibling = child

  return content

canConvert = (node, filter) ->
  if typeof filter is 'string'
    filter is node.tagName
  else if Array.isArray(filter)
    node.tagName in filter
  else if typeof filter is 'function'
    filter(node)
  else
    throw new TypeError('`filter` needs to be a string, array, or function')

findConverter = (node) ->
  for converter in converters
    if canConvert(node, converter.filter) then return converter

isFlankedByWhitespace = (side, node) ->
  if side is 'left'
    sibling = node.previousSibling
    regExp = /\s$/
  else
    sibling = node.nextSibling
    regExp = /^\s/

  if sibling and not isBlock(sibling)
    regExp.test getContent(sibling)
  else
    false

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

  # add whitespace from leading / trailing whitespace attributes in first / last
  # child nodes
  if node.childNodes[0]?._whitespace?.leading
    leading += node.childNodes[0]._whitespace.leading
  if node.childNodes[-1...][0]?._whitespace?.trailing
    trailing += node.childNodes[-1...][0]._whitespace.trailing

  return {leading, trailing}

###
 * Finds a Markdown converter, gets the replacement, and sets it on
 * `_replacement`
###
process = (node, links) ->
  content = getContent(node)
  converter = node._converter

  if 'pre' not in [node.tagName, node.parentNode.tagName]
    content = content.trim() # pre tags are whitespace-sensitive

  if converter.surroundingBlankLines
    whitespace = {leading: '\n\n', trailing: '\n\n'}
  else
    whitespace = flankingWhitespace(node)
    if converter.trailingWhitespace?
      whitespace.trailing += converter.trailingWhitespace

  if node.tagName is 'li'
    # li isn't allowed to have leading whitespace
    whitespace.leading = ''

  node._replacement = converter.replacement(content, node, links)
  node._whitespace = whitespace
  return

###*
 * Remove whitespace text nodes from children
###
removeEmptyNodes = (node) ->
  # gather a list of children to remove, because removing them right away
  # would screw up iteration
  emptyChildren = []
  for child in node.childNodes
    if isTextNode(child) and getTextNodeContent(child).trim() is ''
      previousSibling = child.previousSibling
      nextSibling = child.nextSibling
      if not previousSibling or not nextSibling or
         isBlock(previousSibling) or isBlock(nextSibling)
        emptyChildren.push(child)
  for child in emptyChildren
    detachNode child
  return

module.exports = (dirtyMarkdown, options = {}) ->
  if typeof dirtyMarkdown isnt 'string'
    throw new TypeError('Markdown input is not a string')

  options.ensureFirstHeaderIsH1 ?= true

  out = ''

  # handle yaml front-matter
  try
    content = fm(dirtyMarkdown)
    if Object.keys(content.attributes).length isnt 0
      out += '---\n' + yaml.safeDump(content.attributes).trim() + '\n---\n\n'
    content = content.body
  catch
    # parsing failed, just ignore front-matter
    content = dirtyMarkdown

  ast = marked.lexer(content)

  rawLinks = ast.links # see issue: https://github.com/chjj/marked/issues/472
  links = []
  for link, value of rawLinks
    links.push(
      name: link.toLowerCase()
      url: value.href
      title: value.title or null
    )
  links = _.sortBy(links, ['name', 'url'])

  html = marked.parser(ast)

  # Escape potential ol triggers
  html = html.replace(/(\d+)\. /g, '$1\\. ')
  root = parseFragment(html, {treeAdapter})

  # remove empty nodes that are direct children of the root first
  removeEmptyNodes(root)

  fixHeaders(root, options.ensureFirstHeaderIsH1)
  nodes = bfsOrder(root)
  removeEmptyNodes(node) for node in nodes

  # find converters, starting from the top of the tree. if a converter cannot be
  # found, then the element and all children should be treated as HTML
  for node in nodes
    node._converter = findConverter(node)

  # Process nodes in reverse (so deepest child elements are first).
  for node in nodes by -1
    process node, links

  out += getContent(root).trimRight() + '\n'

  if links.length > 0 then out += '\n'
  for {name, url, title} in links
    optionalTitle = if title then " \"#{title}\"" else ''
    out += "[#{name}]: #{url}#{optionalTitle}\n"

  return out
