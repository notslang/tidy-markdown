_ = require 'lodash'
indent = require 'indent'
{serialize} = require 'parse5'

languageCodeRewrite = require '../lib/language-code-rewrites'
treeAdapter = require './tree-adapter'
{delimitCode, getAttribute, stringRepeat, isBlock} = require './utils'
{
  extractRows
  formatHeaderSeparator
  formatRow
  getColumnWidths
} = require './tables'

CODE_HIGHLIGHT_REGEX = /(?:highlight highlight|lang(?:uage)?)-(\S+)/
{insertTextBefore, insertText, isTextNode} = treeAdapter

indentChildren = (node) ->
  allChildrenAreElements = true
  for child in node.childNodes
    if isTextNode(child) then allChildrenAreElements = false

  if allChildrenAreElements
    children = []
    children.push child for child in node.childNodes
    for child in children
      insertTextBefore(node, '\n  ', child)
    insertText(node, '\n')

  # TODO: handle indenting nested children

fallback = -> true

###*
 * This array holds a set of "converters" that process DOM nodes and output
   Markdown. The `filter` property determines what nodes the converter is run
   on. The `replacement` function takes the content of the node and the node
   itself and returns a string of Markdown. The `surroundingBlankLines` option
   determines whether or not the block should have a blank line before and after
   it. Converters are matched to nodes starting from the top of the converters
   list and testing each one downwards.
 * @type {Array}
###
module.exports = [
  {
    filter: (node) -> node.parentNode?._converter?.filter is fallback
    surroundingBlankLines: false
    replacement: (content, node) ->
      indentChildren(node)
      return ''
  }
  {
    filter: 'p'
    surroundingBlankLines: true
    replacement: (content) -> content
  }
  {
    filter: ['td', 'th']
    surroundingBlankLines: false
    replacement: (content) -> content
  }
  {
    filter: ['tbody', 'thead', 'tr']
    surroundingBlankLines: false
    replacement: -> ''
  }
  {
    filter: ['del', 's', 'strike']
    surroundingBlankLines: false
    replacement: (content) -> "~~#{content}~~"
  }
  {
    filter: ['em', 'i']
    surroundingBlankLines: false
    replacement: (content) -> "_#{content}_"
  }
  {
    filter: ['strong', 'b']
    surroundingBlankLines: false
    replacement: (content) -> "**#{content}**"
  }
  {
    filter: 'br'
    surroundingBlankLines: false
    trailingWhitespace: '\n'
    replacement: -> '<br>'
  }
  {
    filter: 'a'
    surroundingBlankLines: false
    replacement: (content, node, links) ->
      url = getAttribute(node, 'href') or ''
      title = getAttribute(node, 'title')
      referenceLink = _.find(links, {url, title})
      if referenceLink
        if content.toLowerCase() is referenceLink.name
          "[#{content}]"
        else
          "[#{content}][#{referenceLink.name}]"
      else if not title and url isnt '' and content is url
        "<#{url}>"
      else if title
        "[#{content}](#{url} \"#{title}\")"
      else
        "[#{content}](#{url})"
  }
  {
    filter: 'img'
    surroundingBlankLines: false
    replacement: (content, node, links) ->
      alt = getAttribute(node, 'alt') or ''
      url = getAttribute(node, 'src') or ''
      title = getAttribute(node, 'title')
      referenceLink = _.find(links, {url, title})
      if referenceLink
        if alt.toLowerCase() is referenceLink.name
          "![#{alt}]"
        else
          "![#{alt}][#{referenceLink.name}]"
      else if title
        "![#{alt}](#{url} \"#{title}\")"
      else
        "![#{alt}](#{url})"
  }
  {
    filter: (node) ->
      node.type is 'checkbox' and node.parentNode.tagName is 'li'
    surroundingBlankLines: false
    replacement: (content, node) ->
      (if node.checked then '[x]' else '[ ]') + ' '
  }
  {
    filter: 'table'
    surroundingBlankLines: true
    replacement: (content, node) ->
      {alignments, rows} = extractRows(node)
      columnWidths = getColumnWidths(rows)
      totalCols = rows[0].length

      out = [
        formatRow(rows[0], alignments, columnWidths)
        formatHeaderSeparator(alignments, columnWidths)
      ]

      for i in [1...rows.length]
        out.push(formatRow(rows[i], alignments, columnWidths))

      out.join('\n')
  }
  {
    filter: 'pre'
    surroundingBlankLines: true
    replacement: (content, node) ->
      if node.childNodes[0]?.tagName is 'code'
        language = getAttribute(
          node.childNodes[0], 'class'
        )?.match(CODE_HIGHLIGHT_REGEX)?[1]
      if not language? and node.parentNode.tagName is 'div'
        language = getAttribute(
          node.parentNode, 'class'
        )?.match(CODE_HIGHLIGHT_REGEX)?[1]
      if language?
        language = language.toLowerCase()
        if languageCodeRewrite[language]?
          language = languageCodeRewrite[language]
      delimitCode("#{language or ''}\n#{content}", '```')
  }
  {
    filter: 'code'
    surroundingBlankLines: false
    replacement: (content, node) ->
      if node.parentNode.tagName isnt 'pre'
        delimitCode(content, '`') # inline code
      else
        # code that we'll handle once it reaches the pre tag. we only bother
        # passing it through this converter to avoid it being serialized before
        # it gets to the pre tag
        content
  }
  {
    filter: (node) ->
      node.tagName is 'div' and CODE_HIGHLIGHT_REGEX.test(node.className)
    surroundingBlankLines: true
    replacement: (content) -> content
  }
  {
    filter: ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']
    surroundingBlankLines: true
    replacement: (content, node) ->
      hLevel = node.tagName[1]
      "#{stringRepeat('#', hLevel)} #{content}"
  }
  {
    filter: 'hr'
    surroundingBlankLines: true
    replacement: -> stringRepeat('-', 80)
  }
  {
    filter: 'blockquote'
    surroundingBlankLines: true
    replacement: (content) -> indent(content, '> ')
  }
  {
    filter: 'li'
    surroundingBlankLines: false
    trailingWhitespace: '\n'
    replacement: (content, node) ->
      if '\n' in content
        # the indent here is for all the lines after the first, so we only need
        # do it if there's a linebreak in the content
        content = indent(content, '  ').trimLeft()
      parent = node.parentNode
      prefix = (
        if parent.tagName is 'ol'
          parent.childNodes.indexOf(node) + 1 + '. '
        else '- '
      )
      prefix + content
  }
  {
    filter: ['ul', 'ol']
    surroundingBlankLines: true
    replacement: (content) -> content
  }
  {
    filter: '_comment'
    replacement: (content) -> "<!-- #{content} -->"
  }
  {
    filter: fallback
    surroundingBlankLines: true
    replacement: (content, node) ->
      indentChildren(node)
      serialize(
        {children: [node], nodeName: '#document-fragment', quirksMode: false}
        {treeAdapter}
      )
  }
]
