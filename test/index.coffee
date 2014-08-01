should = require 'should'
prettyMarkdown = require '../lib'
fs = require 'fs'

describe 'headings', ->
  it 'should fix spaces between heading and text', ->
    prettyMarkdown('#test').should.equal('# test')
    prettyMarkdown('##test').should.equal('## test')
    prettyMarkdown('###test').should.equal('### test')

    prettyMarkdown('#test#').should.equal('# test')
    prettyMarkdown('##test##').should.equal('## test')
    prettyMarkdown('###test###').should.equal('### test')

  it 'should convert underlined headings into normal ones', ->
    prettyMarkdown('test\n====').should.equal('# test')
    prettyMarkdown('test\n----').should.equal('## test')

  it 'should strip trailing whitespace', ->
    prettyMarkdown('#test ').should.equal('# test')

describe 'paragraphs', ->
  it 'should get rid of mid-paragraph linebreaks', ->
    prettyMarkdown('Lorem ipsum dolor adipiscing\nquis massa lorem')
      .should.equal('Lorem ipsum dolor adipiscing quis massa lorem')

  it 'should only separate paragraphs with one blank line', ->
    prettyMarkdown('''
      Lorem ipsum dolor adipiscing


      quis massa lorem
    ''').should.equal('''
      Lorem ipsum dolor adipiscing

      quis massa lorem
    ''')

describe 'blockquotes', ->
  it 'should normalize blockquotes', ->
    prettyMarkdown('''
      > blockquote with two paragraphs
      > consectetuer adipiscing
      >
      > Donec sit amet nisl
      > id sem consectetuer.
    ''').should.equal('''
      > blockquote with two paragraphs consectetuer adipiscing

      > Donec sit amet nisl id sem consectetuer.
    ''')

describe 'lists', ->
  it 'should normalize unordered lists', ->
    prettyMarkdown('''
       * item
       * another item
       * last item
    ''').should.equal('''
      - item
      - another item
      - last item
    ''')
    prettyMarkdown('''
       + item
       + another item
       + last item
    ''').should.equal('''
      - item
      - another item
      - last item
    ''')

  it 'should normalize unordered nested lists', ->
    prettyMarkdown('''
       - item
       - another item
         - sub-list item
         - sub-list another item
         - sub-list last item
       - last item
    ''').should.equal('''
      - item
      - another item
        - sub-list item
        - sub-list another item
        - sub-list last item
      - last item
    ''')


describe 'inline grammar', ->
  it 'should handle bold text', ->
    prettyMarkdown('**bold**').should.equal('**bold**')
    prettyMarkdown('__bold__').should.equal('**bold**')

  it 'should handle italic text', ->
    prettyMarkdown('*italic*').should.equal('_italic_')
    prettyMarkdown('_italic_').should.equal('_italic_')

  it 'should handle code', ->
    prettyMarkdown('<code>code</code>').should.equal('`code`')
    prettyMarkdown('`code`').should.equal('`code`')
    prettyMarkdown('` code `').should.equal('`code`')

  it 'should handle strikethrough', ->
    prettyMarkdown('<del>code</del>').should.equal('~~code~~')
    prettyMarkdown('~~code~~').should.equal('~~code~~')

  it 'should handle links', ->
    prettyMarkdown('[text](#anchor)').should.equal('[text](#anchor)')
    prettyMarkdown('[text]( #anchor )').should.equal('[text](#anchor)')
    prettyMarkdown('[](#anchor)').should.equal('[](#anchor)')
    prettyMarkdown('[]()').should.equal('[]()')
    prettyMarkdown('[](#anchor "Title")').should.equal('[](#anchor "Title")')

  it 'should handle images', ->
    prettyMarkdown('![text](image.jpg)').should.equal('![text](image.jpg)')
    prettyMarkdown('![text]( image.jpg )').should.equal('![text](image.jpg)')
    prettyMarkdown('![]()').should.equal('![]()')
    prettyMarkdown('![]("")').should.equal('![]("")')
    prettyMarkdown(
      '![alt text](/path/to/img.jpg "Title")'
    ).should.equal(
      '![alt text](/path/to/img.jpg "Title")'
    )
    prettyMarkdown(
      '[![text]( image.jpg )]( #anchor )'
    ).should.equal(
      '[![text](image.jpg)](#anchor)'
    )

  it 'should allow inline html to pass through', ->
    prettyMarkdown('<span>blag</span>').should.equal('<span>blag</span>')

describe 'full documents', ->
  it.skip 'should reformat to match expected', ->
    for file in fs.readdirSync('./test/cases')
      fs.writeFileSync(
        "./test/cases/2#{file}"
        prettyMarkdown(
          fs.readFileSync("./test/cases/#{file}", encoding: 'utf8')
        )
      )
      try
        prettyMarkdown(
          fs.readFileSync("./test/cases/#{file}", encoding: 'utf8')
        ).trim().should.equal(
          fs.readFileSync("./test/expected/#{file}", encoding: 'utf8').trim()
        )
      catch e
        e.showDiff = false
        throw e
