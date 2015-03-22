tidyMarkdown = require './'
packageInfo = require('../package')
ArgumentParser = require('argparse').ArgumentParser

argparser = new ArgumentParser(
  version: packageInfo.version
  addHelp: true
  description: packageInfo.description
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

argv = argparser.parseArgs()

process.stdin.setEncoding 'utf8'
process.stdin.on 'readable', ->
  buffer = ''
  while null != (chunk = process.stdin.read())
    buffer += chunk
  process.stdout.write tidyMarkdown(buffer, argv)
  return
