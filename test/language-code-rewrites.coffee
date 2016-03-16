rewrites = require '../lib/language-code-rewrites'
should = require 'should'

describe 'language-code-rewrites', ->
  it 'shouldn\'t map output keys to any input keys', ->
    inputKeys = Object.keys(rewrites)
    for inputKey, outputKey of rewrites
      inputKeys.should.not.containEql(outputKey)
