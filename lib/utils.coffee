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
 * @param {String} code
 * @param {String} delimiter The delimiter to start with, additional backticks
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

module.exports = {stringRepeat, longestStringInArray, delimitCode}
