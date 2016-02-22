indent = require 'indent'

{delimitCode, getAttribute, nodeType, stringRepeat} = require './utils'
{
  extractRows
  formatHeaderSeparator
  formatRow
  getColumnWidths
} = require './tables'

CODE_HIGHLIGHT_REGEX = /highlight highlight-(\S+)/

module.exports = [
  {
    filter: 'p'
    replacement: (content) -> "\n\n#{content}\n\n"
  }
  {
    filter: ['del', 's', 'strike']
    replacement: (content) -> "~~#{content}~~"
  }
  {
    filter: (node) ->
      node.type is 'checkbox' and node.parentNode.nodeName is 'li'
    replacement: (content, node) ->
      (if node.checked then '[x]' else '[ ]') + ' '
  }
  {
    filter: ['td', 'th']
    replacement: (content) -> content
  }
  {
    filter: 'table'
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
    filter: (node) ->
      node.nodeName is 'pre' and node.childNodes[0]?.nodeName is 'code'
    replacement: (content, node) ->
      language = getAttribute(
        node.childNodes[0], 'class'
      )?.match(/lang-([^\s]+)/)?[1]
      if not language? and node.parentNode.nodeName is 'div'
        language = getAttribute(
          node.parentNode, 'class'
        )?.match(CODE_HIGHLIGHT_REGEX)?[1]
      '\n\n' + delimitCode("#{language or ''}\n#{content}", '```') + '\n\n'
  }
  {
    filter: 'code'
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
    replacement: (content) -> "\n\n#{content}\n\n"
  }
  {
    filter: ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']
    replacement: (content, node) ->
      hLevel = node.nodeName[1]
      "\n\n#{stringRepeat('#', hLevel)} #{content}\n\n"
  }
  {
    filter: 'hr'
    replacement: -> "\n\n#{stringRepeat('-', 80)}\n\n"
  }
  {
    filter: ['em', 'i']
    replacement: (content) -> "_#{content}_"
  }
  {
    filter: ['strong', 'b']
    replacement: (content) -> "**#{content}**"
  }
  {
    filter: 'a'
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
    replacement: (content, node) ->
      alt = getAttribute(node, 'alt') or ''
      url = getAttribute(node, 'src') or ''
      title = getAttribute(node, 'title') or ''
      if title
        "![#{alt}](#{url} \"#{title}\")"
      else
        "![#{alt}](#{url})"
  }
  {
    filter: 'blockquote'
    replacement: (content) ->
      content = indent(content.trim().replace(/\n{3,}/g, '\n\n'), '> ')
      "\n\n#{content}\n\n"
  }
  {
    filter: 'li'
    replacement: (content, node) ->
      content = indent(content, '  ').replace(/^\s+/, '')
      parent = node.parentNode
      index = parent.childNodes.indexOf(node) + 1
      prefix = if parent.nodeName is 'ol' then index + '. ' else '- '
      prefix + content
  }
  {
    filter: ['ul', 'ol']
    replacement: (content, node) ->
      strings = []
      for child in node.childNodes
        strings.push child._replacement
      "\n\n#{strings.join '\n'}\n\n"
  }
  {
    filter: (node) -> @isBlock node
    replacement: (content, node) ->
      "\n\n#{@outer(node, content)}\n\n"
  }
  {
    filter: -> true
    replacement: (content, node) ->
      @outer node, content
  }
]
