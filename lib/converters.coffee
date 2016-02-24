indent = require 'indent'
{serialize} = require 'parse5'

{delimitCode, getAttribute, stringRepeat, isBlock} = require './utils'
{
  extractRows
  formatHeaderSeparator
  formatRow
  getColumnWidths
} = require './tables'

CODE_HIGHLIGHT_REGEX = /highlight highlight-(\S+)/

###*
 * Returns the HTML string of an element with its contents converted
###
outer = (node, content) ->
  serialize(node).replace '><', '>' + content + '<'

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
    replacement: -> '<br>\n'
  }
  {
    filter: 'a'
    surroundingBlankLines: false
    replacement: (content, node) ->
      url = getAttribute(node, 'href') or ''
      title = getAttribute(node, 'title') or ''
      if not title and url isnt '' and content is url
        "<#{url}>"
      else if title
        "[#{content}](#{url} \"#{title}\")"
      else
        "[#{content}](#{url})"
  }
  {
    filter: 'img'
    surroundingBlankLines: false
    replacement: (content, node) ->
      alt = getAttribute(node, 'alt') or ''
      url = getAttribute(node, 'src') or ''
      title = getAttribute(node, 'title')
      if title
        "![#{alt}](#{url} \"#{title}\")"
      else
        "![#{alt}](#{url})"
  }
  {
    filter: (node) ->
      node.type is 'checkbox' and node.parentNode.nodeName is 'li'
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
      if node.childNodes[0]?.nodeName is 'code'
        language = getAttribute(
          node.childNodes[0], 'class'
        )?.match(/lang-([^\s]+)/)?[1]
      if not language? and node.parentNode.nodeName is 'div'
        language = getAttribute(
          node.parentNode, 'class'
        )?.match(CODE_HIGHLIGHT_REGEX)?[1]
      delimitCode("#{language or ''}\n#{content}", '```')
  }
  {
    filter: 'code'
    surroundingBlankLines: false
    replacement: (content, node) ->
      if node.parentNode.nodeName isnt 'pre'
        delimitCode(content, '`') # inline code
      else
        # code that we'll handle once it reaches the pre tag. we only bother
        # passing it through this converter to avoid it being serialized before
        # it gets to the pre tag
        content
  }
  {
    filter: (node) ->
      node.nodeName is 'div' and CODE_HIGHLIGHT_REGEX.test(node.className)
    surroundingBlankLines: true
    replacement: (content) -> content
  }
  {
    filter: ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']
    surroundingBlankLines: true
    replacement: (content, node) ->
      hLevel = node.nodeName[1]
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
    replacement: (content, node) ->
      content = indent(content, '  ').replace(/^\s+/, '')
      parent = node.parentNode
      index = parent.childNodes.indexOf(node) + 1
      prefix = if parent.nodeName is 'ol' then index + '. ' else '- '
      prefix + content
  }
  {
    filter: ['ul', 'ol']
    surroundingBlankLines: true
    replacement: (content, node) ->
      strings = []
      for child in node.childNodes
        strings.push child._replacement
      strings.join '\n'
  }
  {
    filter: (node) -> isBlock node
    surroundingBlankLines: true
    replacement: (content, node) -> outer node, content
  }
  {
    filter: -> true
    surroundingBlankLines: false
    replacement: (content, node) -> outer node, content
  }
]
