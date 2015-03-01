should = require 'should'
tidyMd = require '../lib'
fs = require 'fs'

# tidyMd witout the trailing newline
tidyMdSnippet = (text) -> tidyMd(text).trimRight()

describe 'headings', ->
  it 'should fix spaces between heading and text', ->
    tidyMdSnippet('''
      #test
      ##test
      ###test
    ''').should.equal('''
      # test
      ## test
      ### test
    ''')

  it 'should fix atx-style headings', ->
    tidyMdSnippet('''
      # test #
      ## test ##
      ### test ###
    ''').should.equal('''
      # test
      ## test
      ### test
    ''')

  it 'should fix underlined headings', ->
    tidyMdSnippet('''
      test
      ====
      test
      ----
    ''').should.equal('''
      # test
      ## test
    ''')

  it 'should fix skips between header levels', ->
    tidyMdSnippet('''
      ## test
    ''').should.equal('''
      # test
    ''')

    tidyMdSnippet('''
      # test
      ### test
      ### test
    ''').should.equal('''
      # test
      ## test
      ## test
    ''')

    tidyMdSnippet('''
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
    tidyMdSnippet('#test ').should.equal('# test')

describe 'paragraphs', ->
  it 'should get rid of mid-paragraph linebreaks', ->
    tidyMdSnippet('Lorem ipsum dolor adipiscing\nquis massa lorem')
      .should.equal('Lorem ipsum dolor adipiscing quis massa lorem')

  it 'should only separate paragraphs with one blank line', ->
    tidyMdSnippet('''
      Lorem ipsum dolor adipiscing


      quis massa lorem
    ''').should.equal('''
      Lorem ipsum dolor adipiscing

      quis massa lorem
    ''')

describe 'blockquotes', ->
  it 'should normalize blockquotes', ->
    tidyMdSnippet('''
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
    tidyMdSnippet('''
       * item
       * another item
       * last item
    ''').should.equal('''
      - item
      - another item
      - last item
    ''')
    tidyMdSnippet('''
       + item
       + another item
       + last item
    ''').should.equal('''
      - item
      - another item
      - last item
    ''')

  it 'should normalize unordered nested lists', ->
    tidyMdSnippet('''
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
    tidyMdSnippet('2 < 4').should.equal('2 < 4')
    tidyMdSnippet('5 > 4').should.equal('5 > 4')

  it 'should handle bold text', ->
    tidyMdSnippet('**bold**').should.equal('**bold**')
    tidyMdSnippet('__bold__').should.equal('**bold**')

  it 'should handle italic text', ->
    tidyMdSnippet('*italic*').should.equal('_italic_')
    tidyMdSnippet('_italic_').should.equal('_italic_')

  it 'should handle code', ->
    tidyMdSnippet('<code>code</code>').should.equal('`code`')
    tidyMdSnippet('`code`').should.equal('`code`')
    tidyMdSnippet('` code `').should.equal('`code`')
    tidyMdSnippet('```blah` ``').should.equal('`` `blah` ``')
    tidyMdSnippet('` ``blah`` `').should.equal('` ``blah`` `')

  it 'should handle strikethrough', ->
    tidyMdSnippet('<del>code</del>').should.equal('~~code~~')
    tidyMdSnippet('~~code~~').should.equal('~~code~~')

  it 'should handle links', ->
    tidyMdSnippet('[text](#anchor)').should.equal('[text](#anchor)')
    tidyMdSnippet('[text]( #anchor )').should.equal('[text](#anchor)')
    tidyMdSnippet('[](#anchor)').should.equal('[](#anchor)')
    tidyMdSnippet('[]()').should.equal('[]()')
    tidyMdSnippet('[](#anchor "Title")').should.equal('[](#anchor "Title")')

  it 'should handle images', ->
    tidyMdSnippet('![text](image.jpg)').should.equal('![text](image.jpg)')
    tidyMdSnippet('![text]( image.jpg )').should.equal('![text](image.jpg)')
    tidyMdSnippet('![]()').should.equal('![]()')
    tidyMdSnippet('![]("")').should.equal('![]("")')
    tidyMdSnippet(
      '![alt text](/path/to/img.jpg "Title")'
    ).should.equal(
      '![alt text](/path/to/img.jpg "Title")'
    )
    tidyMdSnippet(
      '[![text]( image.jpg )]( #anchor )'
    ).should.equal(
      '[![text](image.jpg)](#anchor)'
    )

  it 'should allow inline html to pass through', ->
    tidyMdSnippet('<span>blag</span>').should.equal('<span>blag</span>')

describe 'tables', ->
  it 'should handle tables', ->
    tidyMd('''
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

  it 'should support single column tables & not make trailing whitespace', ->
    tidyMd('''
      | Group
      | -------------------------
      | ShinRa
      | Moogles
      | Vana'diel Chocobo Society
    ''').should.equal('''
      | Group
      | -------------------------
      | ShinRa
      | Moogles
      | Vana'diel Chocobo Society

    ''')

  it 'should handle tables with text alignment', ->
    tidyMd('''
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

    tidyMd('''
      Group                     | Domain          | First Appearance
      ------------------------- | :-------------: | :---------------
                         ShinRa | Mako Reactors   | FFVII
                        Moogles |          MogNet | FFIII
      Vana'diel Chocobo Society | Chocobo Raising | FFXI:TOAU
    ''').should.equal('''
      Group                     | Domain          | First Appearance
      ------------------------- | :-------------: | :---------------
      ShinRa                    | Mako Reactors   | FFVII
      Moogles                   | MogNet          | FFIII
      Vana'diel Chocobo Society | Chocobo Raising | FFXI:TOAU

    ''')

describe 'horizontal rules', ->
  it 'should normalize horizontal rules', ->
    tidyMdSnippet('''
      ***

      -------------------------

      _____
    ''').should.equal('''
      --------------------------------------------------------------------------------

      --------------------------------------------------------------------------------

      --------------------------------------------------------------------------------
    ''')

describe 'html', ->
  it 'should let html pass through unharmed', ->
    tidyMdSnippet('''
      <dl>
        <dt>Definition list</dt>
        <dd>Is something people use sometimes.</dd>

        <dt>Markdown in HTML</dt>
        <dd>Does *not* work **very** well. Use HTML <em>tags</em>.</dd>
      </dl>
    ''').should.equal('''
      <dl>
        <dt>Definition list</dt>
        <dd>Is something people use sometimes.</dd>

        <dt>Markdown in HTML</dt>
        <dd>Does *not* work **very** well. Use HTML <em>tags</em>.</dd>
      </dl>
    ''')

describe 'full documents', ->
  it 'should reformat to match expected', ->
    for file in fs.readdirSync('./test/cases')
      try
        tidyMd(
          fs.readFileSync("./test/cases/#{file}", encoding: 'utf8')
        ).should.equal(
          fs.readFileSync("./test/expected/#{file}", encoding: 'utf8')
        )
      catch e
        e.showDiff = false
        throw e
