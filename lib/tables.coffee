_ = require 'lodash'
pad = require 'pad'

{getAttribute, nodeType} = require './utils'

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
 * Determines the alignment for a table cell by reading the style attribute
 * @return {String|null} One of 'right', 'left', 'center', or null
###
getCellAlignment = (node) ->
  getAttribute(node, 'style')?.match(
    /text-align:\s*(right|left|center)/
  )?[1] or null

###*
 * Join an array of cells (columns) from a single row.
 * @param {String[]} columns
 * @return {String} The joined row.
###
joinColumns = (columns) ->
  if columns.length > 1
    columns.join ' | '
  else
    # use a leading pipe for single column tables, otherwise the output won't
    # render as a table
    '| ' + columns[0]

extractColumns = (row) ->
  columns = []
  alignments = []
  for column in row.childNodes
    # we don't care if it's a `th` or `td` because we cannot represent the
    # difference in markdown anyway - the first row always represents the
    # headers
    if column.tagName in ['th', 'td']
      columns.push(column._replacement)
      alignments.push(getCellAlignment(column))
    else if column.nodeName isnt '#text'
      throw new Error("Cannot handle #{column.nodeName} in table row")
  return {columns, alignments}

extractRows = (node) ->
  alignments = []
  rows = []
  inqueue = [node]
  while inqueue.length > 0
    elem = inqueue.shift()
    for child in elem.childNodes
      if child.tagName is 'tr'
        row = extractColumns(child)
        rows.push(row.columns)

        # alignments in markdown are column-wide, so after the first row we just
        # want to make sure there aren't any conflicting values within a single
        # column
        for alignment, i in row.alignments
          if i + 1 > alignments.length
            # if all previous rows were shorter, or if we are at the beginning
            # of the table, then we need to populate the alignments array
            alignments.push alignment
          if alignment isnt alignments[i]
            throw new Error(
              "Alignment in a table column #{i} is not consistent"
            )

      else if nodeType(child) is 1
        inqueue.push child

  # when there are more alignments than headers (from columns that extend beyond
  # the headers), and those alignments aren't doing anything, it looks better to
  # remove them
  while alignments.length > rows[0].length and alignments[-1...][0] is null
    alignments.pop()

  return {alignments, rows}

formatRow = (row, alignments, columnWidths) ->
  # apply padding around each cell for alignment and column width
  for i in [0...row.length]
    row[i] = (
      switch alignments[i]
        when 'right'
          pad(columnWidths[i], row[i])
        when 'center'
          # rounding causes a bias to the left because we can't have half a char
          whitespace = columnWidths[i] - row[i].length
          leftPadded = pad(Math.floor(whitespace / 2) + row[i].length, row[i])
          pad(leftPadded, Math.ceil(whitespace / 2) + leftPadded.length)
        else
          # left is the default alignment when formatting
          pad(row[i], columnWidths[i])
    )

  # trimRight is to remove any trailing whitespace added by the padding
  joinColumns(row).trimRight()

formatHeaderSeparator = (alignments, columnWidths) ->
  columns = []
  totalCols = alignments.length
  for i in [0...totalCols]
    columns.push(
      switch alignments[i]
        when 'center' then ':' + pad('', columnWidths[i] - 2, '-') + ':'
        when 'left' then ':' + pad('', columnWidths[i] - 1, '-')
        when 'right' then pad('', columnWidths[i] - 1, '-') + ':'
        when null then pad('', columnWidths[i], '-')
    )
  joinColumns(columns)

getColumnWidths = (rows) ->
  columnWidths = []
  totalCols = rows[0].length
  for i in [0...totalCols]
    column = []
    column.push row[i] or '' for row in rows
    columnWidths.push longestStringInArray(column)
  return columnWidths

module.exports = {
  extractRows
  formatHeaderSeparator
  formatRow
  getColumnWidths
}
