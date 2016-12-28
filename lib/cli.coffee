{ArgumentParser} = require 'argparse'

fs = require 'fs'
packageInfo = require '../package'
tidyMarkdown = require './'

argparser = new ArgumentParser(
  addHelp: true
  description: packageInfo.description + ' Unformatted Markdown is read from
  STDIN, formatted, and written to STDOUT.'
  version: packageInfo.version
)

argparser.addArgument(
  ['path'],
  action: 'store',
  type: 'string',
  help: 'Filename to read (default: STDIN)'
  defaultValue: null,
  nargs: '?',
  required: false
)

argparser.addArgument(
  ['--no-ensure-first-header-is-h1']
  action: 'storeFalse'
  help: 'Disable fixing the first header when it isn\'t an H1. This is useful if
  the markdown you\'re processing isn\'t a full document, but rather a piece of
  a larger document.'
  defaultValue: true
  dest: 'ensureFirstHeaderIsH1'
)

argparser.addArgument(
  ['-w', '--write']
  action: 'storeTrue',
  help: 'Write result to (source) file instead of stdout',
  dest: 'write'
)

argv = argparser.parseArgs()


if argv.path is null
  input = process.stdin
  input.setEncoding 'utf8'
else
  input = fs.createReadStream(argv.path, {encoding: 'utf8'})

input.on 'readable', ->
  buffer = ''
  while (chunk = input.read()) isnt null
    buffer += chunk
  input.close()

  if argv.write
    output = fs.createWriteStream(argv.path, {encoding: 'utf8'})
  else
    output = process.stdout

  if buffer isnt ''
    output.write tidyMarkdown(buffer, argv)
  return
