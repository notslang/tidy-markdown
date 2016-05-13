Entities = require('html-entities').AllHtmlEntities
_ = require 'lodash'

blocks = require './block-tags'
voids = require './void-tags'
{getAttrList, getTextNodeContent} = require './tree-adapter'

###*
 * @param {String} x The string to be repeated
 * @param {String} n Number of times to repeat the string
 * @return {String} The result of repeating the string
###
stringRepeat = (x, n) ->
  s = ''
  loop
    if n & 1 then s += x
    n >>= 1
    if n
      x += x
    else
      break
  return s

###*
 * Wrap code with delimiters
 * @param {String} code
 * @param {String} delimiter The delimiter to start with, additional backticks
   will be added if needed; like if the code contains a sequence of backticks
   that would end the code block prematurely.
###
delimitCode = (code, delimiter) ->
  while ///([^`]|^)#{delimiter}([^`]|$)///.test code
    # Make sure that the delimiter isn't being used inside of the text. If it
    # is, we need to increase the number of times the delimiter is repeated.
    delimiter += '`'

  if code[0] is '`' then code = ' ' + code # add starting space
  if code[-1...] is '`' then code += ' ' # add ending space
  return delimiter + code + delimiter

getAttribute = (node, attribute) ->
  _.find(getAttrList(node), name: attribute)?.value or null

cleanText = (node) ->
  parent = node.parentNode
  text = decodeHtmlEntities(getTextNodeContent(node))

  if 'pre' not in [parent.tagName, parent.parentNode?.tagName]
    text = text.replace /\s+/g, ' ' # excessive whitespace & linebreaks

  if parent.tagName in ['code', 'pre']
    # these tags contain whitespace-sensitive content, so we can't apply
    # advanced text cleaning
    text
  else
    text.replace(
      /\u2014/g, '--' # em-dashes
    ).replace(
      /\u2018|\u2019/g, '\'' # opening/closing singles & apostrophes
    ).replace(
      /\u201c|\u201d/g, '"' # opening/closing doubles
    ).replace(
      /\u2026/g, '...' # ellipses
    )

htmlEntities = new Entities()
decodeHtmlEntities = (text) ->
  htmlEntities.decode(text)

isBlock = (node) ->
  if node.tagName is 'code' and node.parentNode?.tagName is 'pre'
    true # code tags in a pre are treated as blocks
  else
    node.tagName in blocks

isVoid = (node) -> node.tagName in voids

module.exports = {
  cleanText
  decodeHtmlEntities
  delimitCode
  getAttribute
  isBlock
  isVoid
  stringRepeat
}
