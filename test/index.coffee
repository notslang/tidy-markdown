should = require 'should'
tidyMarkdown = require '../lib'
fs = require 'fs'

describe 'headings', ->
  it 'should fix spaces between heading and text', ->
    tidyMarkdown('''
      #test
      ##test
      ###test
    ''').should.equal('''
      # test
      ## test
      ### test
    ''')

  it 'should fix atx-style headings', ->
    tidyMarkdown('''
      # test #
      ## test ##
      ### test ###
    ''').should.equal('''
      # test
      ## test
      ### test
    ''')

  it 'should fix underlined headings', ->
    tidyMarkdown('''
      test
      ====
      test
      ----
    ''').should.equal('''
      # test
      ## test
    ''')

  it 'should fix skips between header levels', ->
    tidyMarkdown('''
      ## test
    ''').should.equal('''
      # test
    ''')

    tidyMarkdown('''
      # test
      ### test
      ### test
    ''').should.equal('''
      # test
      ## test
      ## test
    ''')

    tidyMarkdown('''
      # test
      ### test
      #### test
      ### test
      #### test
    ''').should.equal('''
      # test
      ## test
      ### test
      ## test
      ### test
    ''')

  it 'should strip trailing whitespace', ->
    tidyMarkdown('#test ').should.equal('# test')

describe 'paragraphs', ->
  it 'should get rid of mid-paragraph linebreaks', ->
    tidyMarkdown('Lorem ipsum dolor adipiscing\nquis massa lorem')
      .should.equal('Lorem ipsum dolor adipiscing quis massa lorem')

  it 'should only separate paragraphs with one blank line', ->
    tidyMarkdown('''
      Lorem ipsum dolor adipiscing


      quis massa lorem
    ''').should.equal('''
      Lorem ipsum dolor adipiscing

      quis massa lorem
    ''')

describe 'blockquotes', ->
  it 'should normalize blockquotes', ->
    tidyMarkdown('''
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
    tidyMarkdown('''
       * item
       * another item
       * last item
    ''').should.equal('''
      - item
      - another item
      - last item
    ''')
    tidyMarkdown('''
       + item
       + another item
       + last item
    ''').should.equal('''
      - item
      - another item
      - last item
    ''')

  it 'should normalize unordered nested lists', ->
    tidyMarkdown('''
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
  it 'should handle special characters', ->
    tidyMarkdown('2 < 4').should.equal('2 < 4')
    tidyMarkdown('5 > 4').should.equal('5 > 4')

  it 'should handle bold text', ->
    tidyMarkdown('**bold**').should.equal('**bold**')
    tidyMarkdown('__bold__').should.equal('**bold**')

  it 'should handle italic text', ->
    tidyMarkdown('*italic*').should.equal('_italic_')
    tidyMarkdown('_italic_').should.equal('_italic_')

  it 'should handle code', ->
    tidyMarkdown('<code>code</code>').should.equal('`code`')
    tidyMarkdown('`code`').should.equal('`code`')
    tidyMarkdown('` code `').should.equal('`code`')
    tidyMarkdown('```blah` ``').should.equal('`` `blah` ``')
    tidyMarkdown('` ``blah`` `').should.equal('` ``blah`` `')

  it 'should handle strikethrough', ->
    tidyMarkdown('<del>code</del>').should.equal('~~code~~')
    tidyMarkdown('~~code~~').should.equal('~~code~~')

  it 'should handle links', ->
    tidyMarkdown('[text](#anchor)').should.equal('[text](#anchor)')
    tidyMarkdown('[text]( #anchor )').should.equal('[text](#anchor)')
    tidyMarkdown('[](#anchor)').should.equal('[](#anchor)')
    tidyMarkdown('[]()').should.equal('[]()')
    tidyMarkdown('[](#anchor "Title")').should.equal('[](#anchor "Title")')

  it 'should handle images', ->
    tidyMarkdown('![text](image.jpg)').should.equal('![text](image.jpg)')
    tidyMarkdown('![text]( image.jpg )').should.equal('![text](image.jpg)')
    tidyMarkdown('![]()').should.equal('![]()')
    tidyMarkdown('![]("")').should.equal('![]("")')
    tidyMarkdown(
      '![alt text](/path/to/img.jpg "Title")'
    ).should.equal(
      '![alt text](/path/to/img.jpg "Title")'
    )
    tidyMarkdown(
      '[![text]( image.jpg )]( #anchor )'
    ).should.equal(
      '[![text](image.jpg)](#anchor)'
    )

  it 'should allow inline html to pass through', ->
    tidyMarkdown('<span>blag</span>').should.equal('<span>blag</span>')

describe 'tables', ->
  it 'should handle tables', ->
    tidyMarkdown('''
      Group                     | Domain          | First Appearance
      ------------------------- | --------------- | ----------------
      ShinRa                    | Mako Reactors   | FFVII
      Moogles                   | MogNet          | FFIII
      Vana'diel Chocobo Society | Chocobo Raising | FFXI:TOAU
    ''').should.equal('''
      Group                     | Domain          | First Appearance
      ------------------------- | --------------- | ----------------
      ShinRa                    | Mako Reactors   | FFVII
      Moogles                   | MogNet          | FFIII
      Vana'diel Chocobo Society | Chocobo Raising | FFXI:TOAU
    ''')

  it 'should handle tables with text alignment', ->
    tidyMarkdown('''
      Group                     | Domain          | First Appearance
      ------------------------: | :-------------: | :---------------
      ShinRa                    | Mako Reactors   | FFVII
      Moogles                   | MogNet          | FFIII
      Vana'diel Chocobo Society | Chocobo Raising | FFXI:TOAU
    ''').should.equal('''
      Group                     | Domain          | First Appearance
      ------------------------: | :-------------: | :---------------
                         ShinRa | Mako Reactors   | FFVII
                        Moogles | MogNet          | FFIII
      Vana'diel Chocobo Society | Chocobo Raising | FFXI:TOAU
    ''')

describe 'full documents', ->
  it 'should reformat to match expected', ->
    for file in fs.readdirSync('./test/cases')
      try
        tidyMarkdown(
          fs.readFileSync("./test/cases/#{file}", encoding: 'utf8')
        ).trim().should.equal(
          fs.readFileSync("./test/expected/#{file}", encoding: 'utf8').trim()
        )
      catch e
        e.showDiff = false
        throw e
