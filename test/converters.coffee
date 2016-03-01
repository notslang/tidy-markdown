converters = require '../lib/converters'
should = require 'should'

describe 'converters', ->
  it 'should define a replacement function', ->
    for converter in converters
      converter.replacement.should.type('function')
