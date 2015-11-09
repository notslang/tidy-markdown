Entities = require('html-entities').AllHtmlEntities
marked = require 'marked'

{delimitCode} = require './utils'

htmlEntities = new Entities()
IMG_REGEX = /<img src="([^"]*)"(?: alt="([^"]*)")?(?: title="([^"]*)")?>/g
LINK_REGEX = /<a href="([^"]*)"(?: title="([^"]*)")?>([^<]*)<\/a>/g
CODE_REGEX = /<code>([^<]+)<\/code>/g
tidyInlineMarkdown = (token) ->
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
        title = title.replace /\\|"/g, (m) -> "\\#{m}"
        url += " \"#{title}\""
      return "![#{alt}](#{url})"
    .replace LINK_REGEX, (m, url='', title, text='') ->
      if title?
        title = title.replace /\\|"/g, (m) -> "\\#{m}"
        url += " \"#{title}\""

      if url is text and url isnt ''
        return "<#{url}>"
      else
        return "[#{text}](#{url})"

  token.text = htmlEntities.decode(token.text)
  return token

module.exports = tidyInlineMarkdown
