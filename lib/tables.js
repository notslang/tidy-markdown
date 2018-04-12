// Generated by CoffeeScript 1.12.7
'use_strict'
var _, extractColumns, extractRows, formatHeaderSeparator, formatRow, getAttribute, getCellAlignment, getColumnWidths, isElementNode, isTextNode, joinColumns, longestStringInArray, pad, ref, wcwidth

_ = require('lodash')

wcwidth = require('wcwidth')

getAttribute = require('./utils').getAttribute

ref = require('./tree-adapter'), isTextNode = ref.isTextNode, isElementNode = ref.isElementNode

pad = function (text, length, char) {
  var invert, padlength, ref1, res
  if (char == null) {
    char = ' '
  }
  invert = typeof text === 'number'
  if (invert) {
    ref1 = [text, length], length = ref1[0], text = ref1[1]
  }
  text = text.toString()
  res = ''
  padlength = length - wcwidth(text)
  res += char.repeat(padlength)
  if (invert) {
    return res + text
  } else {
    return text + res
  }
}

/**
 * Find the length of the longest string in an array
 * @param {String[]} array Array of strings
 */

longestStringInArray = function (array) {
  var j, len, len1, longest, str
  longest = 0
  for (j = 0, len1 = array.length; j < len1; j++) {
    str = array[j]
    len = wcwidth(str)
    if (len > longest) {
      longest = len
    }
  }
  return longest
}

/**
 * Determines the alignment for a table cell by reading the style attribute
 * @return {String|null} One of 'right', 'left', 'center', or null
 */

getCellAlignment = function (node) {
  var ref1, ref2
  return ((ref1 = getAttribute(node, 'style')) != null ? (ref2 = ref1.match(/text-align:\s*(right|left|center)/)) != null ? ref2[1] : void 0 : void 0) || null
}

/**
 * Join an array of cells (columns) from a single row.
 * @param {String[]} columns
 * @return {String} The joined row.
 */

joinColumns = function (columns) {
  if (columns.length > 1) {
    return columns.join(' | ')
  } else {
    return '| ' + columns[0]
  }
}

extractColumns = function (row) {
  var alignments, column, columns, j, len1, ref1, ref2
  columns = []
  alignments = []
  ref1 = row.childNodes
  for (j = 0, len1 = ref1.length; j < len1; j++) {
    column = ref1[j]
    if ((ref2 = column.tagName) === 'th' || ref2 === 'td') {
      columns.push(column._replacement)
      alignments.push(getCellAlignment(column))
    } else if (isTextNode(column)) {
      throw new Error('Cannot handle ' + column.tagName + ' in table row')
    }
  }
  return {
    columns: columns,
    alignments: alignments
  }
}

extractRows = function (node) {
  var alignment, alignments, child, elem, i, inqueue, j, k, len1, len2, ref1, ref2, row, rows
  alignments = []
  rows = []
  inqueue = [node]
  while (inqueue.length > 0) {
    elem = inqueue.shift()
    ref1 = elem.childNodes
    for (j = 0, len1 = ref1.length; j < len1; j++) {
      child = ref1[j]
      if (child.tagName === 'tr') {
        row = extractColumns(child)
        rows.push(row.columns)
        ref2 = row.alignments
        for (i = k = 0, len2 = ref2.length; k < len2; i = ++k) {
          alignment = ref2[i]
          if (i + 1 > alignments.length) {
            alignments.push(alignment)
          }
          if (alignment !== alignments[i]) {
            throw new Error('Alignment in a table column ' + i + ' is not consistent')
          }
        }
      } else if (isElementNode(child)) {
        inqueue.push(child)
      }
    }
  }
  while (alignments.length > rows[0].length && alignments.slice(-1)[0] === null) {
    alignments.pop()
  }
  return {
    alignments: alignments,
    rows: rows
  }
}

formatRow = function (row, alignments, columnWidths) {
  var i, j, leftPadded, ref1, whitespace
  for (i = j = 0, ref1 = row.length; 0 <= ref1 ? j < ref1 : j > ref1; i = 0 <= ref1 ? ++j : --j) {
    row[i] = ((function () {
      switch (alignments[i]) {
        case 'right':
          return pad(columnWidths[i], row[i])
        case 'center':
          whitespace = columnWidths[i] - row[i].length
          leftPadded = pad(Math.floor(whitespace / 2) + row[i].length, row[i])
          return pad(leftPadded, Math.ceil(whitespace / 2) + leftPadded.length)
        default:
          return pad(row[i], columnWidths[i])
      }
    })())
  }
  return joinColumns(row).trimRight()
}

formatHeaderSeparator = function (alignments, columnWidths) {
  var columns, i, j, ref1, totalCols
  columns = []
  totalCols = alignments.length
  for (i = j = 0, ref1 = totalCols; 0 <= ref1 ? j < ref1 : j > ref1; i = 0 <= ref1 ? ++j : --j) {
    columns.push((function () {
      switch (alignments[i]) {
        case 'center':
          return ':' + pad('', columnWidths[i] - 2, '-') + ':'
        case 'left':
          return ':' + pad('', columnWidths[i] - 1, '-')
        case 'right':
          return pad('', columnWidths[i] - 1, '-') + ':'
        case null:
          return pad('', columnWidths[i], '-')
      }
    })())
  }
  return joinColumns(columns)
}

getColumnWidths = function (rows) {
  var column, columnWidths, i, j, k, len1, ref1, row, totalCols
  columnWidths = []
  totalCols = rows[0].length
  for (i = j = 0, ref1 = totalCols; 0 <= ref1 ? j < ref1 : j > ref1; i = 0 <= ref1 ? ++j : --j) {
    column = []
    for (k = 0, len1 = rows.length; k < len1; k++) {
      row = rows[k]
      column.push(row[i] || '')
    }
    columnWidths.push(longestStringInArray(column))
  }
  return columnWidths
}

module.exports = {
  extractRows: extractRows,
  formatHeaderSeparator: formatHeaderSeparator,
  formatRow: formatRow,
  getColumnWidths: getColumnWidths
}