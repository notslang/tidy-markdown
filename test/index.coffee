fs = require 'fs'
should = require 'should'
tidyMd = require '../lib'

# tidyMd without the trailing newline
tidyMdSnippet = (text, options) -> tidyMd(text, options).trimRight()

describe 'headings', ->
  it 'should convert header tags', ->
    tidyMdSnippet('<h1>test</h1>').should.equal('# test')
    tidyMdSnippet('<h1> test </h1>').should.equal('# test')

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

  it 'should fix the first header level', ->
    tidyMdSnippet('''
      ### test
      #### test
      ### test
      #### test
    ''').should.equal('''
      # test

      ## test

      # test

      ## test
    ''')

  it 'should optionally allow the first header level to be > h1', ->
    tidyMdSnippet(
      '''
      ### test
      #### test
      ### test
      #### test
      '''
      ensureFirstHeaderIsH1: false
    ).should.equal('''
      ### test

      #### test

      ### test

      #### test
    ''')

    tidyMdSnippet(
      '''
      ### test
      #### test
      # test
      ## test
      '''
      ensureFirstHeaderIsH1: false
    ).should.equal('''
      ### test

      #### test

      ### test

      #### test
    ''')

  it 'should strip trailing whitespace', ->
    tidyMdSnippet('#test ').should.equal('# test')

  it 'should strip excessive whitespace', ->
    tidyMdSnippet('#test   header').should.equal('# test header')

describe 'paragraphs', ->
  it 'should get rid of mid-paragraph linebreaks', ->
    tidyMdSnippet(
      'Lorem ipsum dolor adipiscing\nquis massa lorem'
    ).should.equal(
      'Lorem ipsum dolor adipiscing quis massa lorem'
    )

  it 'should get rid of mid-paragraph linebreaks in inline code', ->
    tidyMdSnippet(
      'Lorem ipsum dolor `node test\n--fix` quis massa lorem'
    ).should.equal(
      'Lorem ipsum dolor `node test --fix` quis massa lorem'
    )

  it 'should handle real linebreaks', ->
    tidyMdSnippet(
      'Lorem ipsum dolor adipiscing  \nquis massa lorem'
    ).should.equal('''
      Lorem ipsum dolor adipiscing<br>
      quis massa lorem
    ''')

  it 'should handle real linebreaks (2)', ->
    tidyMdSnippet(
      'Lorem ipsum dolor adipiscing <br/> quis massa lorem'
    ).should.equal('''
      Lorem ipsum dolor adipiscing<br>
      quis massa lorem
    ''')

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

  it 'should normalize blockquotes with nested tags', ->
    tidyMdSnippet('''
      > # header
      > this is a paragraph containing `some code`.
    ''').should.equal('''
      > # header

      > this is a paragraph containing `some code`.
    ''')

  it 'should normalize nested blockquotes', ->
    tidyMdSnippet('''
      > start
      >> two

      > end
    ''').should.equal('''
      > start

      > > two

      > end
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

  it 'should normalize unordered nested lists (2)', ->
    tidyMdSnippet('''
      + adas
        - asdas
        - sdas

      + sdfsdas
          - sddfasdfdfs
          - sdfafasdfsa
      + asdfads
    ''').should.equal('''
      - adas

        - asdas
        - sdas

      - sdfsdas

        - sddfasdfdfs
        - sdfafasdfsa

      - asdfads
    ''')

  it 'should normalize ordered lists', ->
    tidyMdSnippet('''
      # H1 header
      1. blah
      2. blah
      3. blah

      # another H1 header
      1. blah
      2. blah
    ''').should.equal('''
      # H1 header

      1. blah
      2. blah
      3. blah

      # another H1 header

      1. blah
      2. blah
    ''')

  it 'should normalize ordered nested lists', ->
    tidyMdSnippet('''
      1. item
      2. another item

        1. sub-list item
        2. sub-list another item
        3. sub-list last item

      3. last item
    ''').should.equal('''
      1. item
      2. another item

        1. sub-list item
        2. sub-list another item
        3. sub-list last item

      3. last item
    ''')


describe 'code blocks', ->
  it 'should handle fenced code', ->
    tidyMdSnippet('''
      # H1 header
      ```
      this is some code
      ```

      # another H1 header
      <pre>

      this is some indented code w/ a trailing & leading newline

      </pre>
    ''').should.equal('''
      # H1 header

      ```
      this is some code
      ```

      # another H1 header

      ```

      this is some indented code w/ a trailing & leading newline

      ```
    ''')

  it 'should handle fenced code with a specified language', ->
    tidyMdSnippet('''
      ```javascript
      function () {this.isSomeJavaScript()}
      ```
    ''').should.equal('''
      ```javascript
      function () {this.isSomeJavaScript()}
      ```
    ''')

  it 'should allow code to have excessive linebreaks', ->
    tidyMdSnippet('''
      ```
      this is some code...



      ...with several linebreaks in it
      ```
    ''').should.equal('''
      ```
      this is some code...



      ...with several linebreaks in it
      ```
    ''')

describe 'inline grammar', ->
  it 'should handle special characters', ->
    tidyMdSnippet('2 < 4').should.equal('2 < 4')
    tidyMdSnippet('5 > 4').should.equal('5 > 4')

  it 'should handle bold text', ->
    tidyMdSnippet('**bold**').should.equal('**bold**')
    tidyMdSnippet('__bold__').should.equal('**bold**')

  it 'should convert <em> tags', ->
    tidyMdSnippet(
      'some <em>italic</em> text'
    ).should.equal(
      'some _italic_ text'
    )
    tidyMdSnippet(
      'some <em> italic </em> text'
    ).should.equal(
      'some _italic_ text'
    )

  it 'should handle italic text', ->
    tidyMdSnippet('*italic*').should.equal('_italic_')
    tidyMdSnippet('_italic_').should.equal('_italic_')

  it 'should convert code tags', ->
    tidyMdSnippet('<code>code</code>').should.equal('`code`')

  it 'should handle code', ->
    tidyMdSnippet('`code`').should.equal('`code`')
    tidyMdSnippet('the `<del>` tag').should.equal('the `<del>` tag')

  it 'should remove whitespace surrounding inline code', ->
    tidyMdSnippet('` code `').should.equal('`code`')

  it 'should handle code containing backticks', ->
    tidyMdSnippet('```blah` ``').should.equal('`` `blah` ``')
    tidyMdSnippet('` ``blah`` `').should.equal('` ``blah`` `')

  it 'should convert strikethrough tags', ->
    tidyMdSnippet('<del>code</del>').should.equal('~~code~~')

  it 'should handle strikethrough', ->
    tidyMdSnippet('~~code~~').should.equal('~~code~~')

  it 'should handle links', ->
    tidyMdSnippet('[text](#anchor)').should.equal('[text](#anchor)')
    tidyMdSnippet('[text]( #anchor )').should.equal('[text](#anchor)')
    tidyMdSnippet('[](#anchor)').should.equal('[](#anchor)')
    tidyMdSnippet('[](#anchor "Title")').should.equal('[](#anchor "Title")')
    tidyMdSnippet('[1]() [2]()').should.equal('[1]() [2]()')
    tidyMdSnippet('[1]() [ 2 ]()').should.equal('[1]() [2]()')
    tidyMdSnippet('[1]()[ 2 ]()').should.equal('[1]() [2]()')
    tidyMdSnippet('[1]()[2]()').should.equal('[1]()[2]()')
    tidyMdSnippet('[1]()\n[2]()').should.equal('[1]() [2]()')

  it 'should handle empty links', ->
    tidyMdSnippet('[]()').should.equal('[]()')

  it 'should handle unmarked links', ->
    tidyMdSnippet(
      'https://github.com/slang800/tidy-markdown'
    ).should.equal(
      '<https://github.com/slang800/tidy-markdown>'
    )

  it 'should handle shorthand links', ->
    tidyMdSnippet(
      '<https://github.com/slang800/tidy-markdown>'
    ).should.equal(
      '<https://github.com/slang800/tidy-markdown>'
    )

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

  it 'should normalize quotes', ->
    tidyMdSnippet(
      'highly “opinionated” guide'
    ).should.equal(
      'highly "opinionated" guide'
    )

describe 'tables', ->
  it 'should handle tables', ->
    tidyMd('''
      Group                     | Domain                   | First Appearance
      ------------------------- | ------------------------ | ----------------
      `ShinRa`                  | Mako Reactors            | FFVII
      Moogles                   | [MogNet](http://mog.net) | FFIII
      Vana'diel Chocobo Society | Chocobo Raising          | FFXI:TOAU
    ''').should.equal('''
      Group                     | Domain                   | First Appearance
      ------------------------- | ------------------------ | ----------------
      `ShinRa`                  | Mako Reactors            | FFVII
      Moogles                   | [MogNet](http://mog.net) | FFIII
      Vana'diel Chocobo Society | Chocobo Raising          | FFXI:TOAU

    ''')

  it 'should handle tables with blank values', ->
    tidyMd('''
      0,0 | 0,1 | 0,2
      --- | --- | ---
      1,0 |     | 1,2
          | 2,1 |

    ''').should.equal('''
      0,0 | 0,1 | 0,2
      --- | --- | ---
      1,0 |     | 1,2
          | 2,1 |

    ''')

  it 'should handle tables with missing values', ->
    tidyMd('''
      Name |  Type |  Description | Choices
      -----| ------|  -------------| -------
      creator_license_id |  unknown | License which...

    ''').should.equal('''
      Name               | Type    | Description      | Choices
      ------------------ | ------- | ---------------- | -------
      creator_license_id | unknown | License which...

    ''')

  it 'should handle tables with missing values (2)', ->
    tidyMd('''
      Name |  Type |  Description | Choices
      :----| :----: |  ------------- | ------:
      0,0 |  0,1 | 0,2
          |  1,1 | 1,2 |     | |
      2,0 |  2,1 |     | 2,3

    ''').should.equal('''
      Name | Type | Description | Choices
      :--- | :--: | ----------- | ------:
      0,0  | 0,1  | 0,2
           | 1,1  | 1,2         |         |  |
      2,0  | 2,1  |             |     2,3

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
                          Group |     Domain      | First Appearance
      ------------------------: | :-------------: | :---------------
                         ShinRa |  Mako Reactors  | FFVII
                        Moogles |     MogNet      | FFIII
      Vana'diel Chocobo Society | Chocobo Raising | FFXI:TOAU

    ''')

    tidyMd('''
      Group                     | Domain          | First Appearance
      ------------------------- | :-------------: | :---------------
                         ShinRa | Mako Reactors   | FFVII
                        Moogles |          MogNet | FFIII
      Vana'diel Chocobo Society | Chocobo Raising | FFXI:TOAU
    ''').should.equal('''
      Group                     |     Domain      | First Appearance
      ------------------------- | :-------------: | :---------------
      ShinRa                    |  Mako Reactors  | FFVII
      Moogles                   |     MogNet      | FFIII
      Vana'diel Chocobo Society | Chocobo Raising | FFXI:TOAU

    ''')

  it 'should handle tables surrounded by text', ->
    tidyMd('''
      # a header

      this is a table:

      | Group
      | ------
      | value & whatnot

      ...and that table was pretty great, right?
    ''').should.equal('''
      # a header

      this is a table:

      | Group
      | ---------------
      | value & whatnot

      ...and that table was pretty great, right?

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
        <dd>Does *not* work well. Use HTML <em>tags</em>.</dd>
      </dl>
    ''').should.equal('''
      <dl>
        <dt>Definition list</dt>
        <dd>Is something people use sometimes.</dd>
        <dt>Markdown in HTML</dt>
        <dd>Does <em>not</em> work well. Use HTML <em>tags</em>.</dd>
      </dl>
    ''')

describe 'front-matter', ->
  it 'should handle front-matter', ->
    tidyMdSnippet('''
      ---
      title: "Awesome markdown file"
      ---
      My content
    ''').should.equal('''
      ---
      title: Awesome markdown file
      ---

      My content
    ''')

describe 'README.md', ->
  it 'should be formatted correctly', ->
    readmeContents = fs.readFileSync(
      "#{__dirname}/../README.md"
      encoding: 'utf8'
    )
    tidyMd(readmeContents).should.equal(readmeContents)

describe 'full documents', ->
  it 'should reformat to match expected', ->
    for file in fs.readdirSync('./test/cases')
      tidyMd(
        fs.readFileSync("./test/cases/#{file}", encoding: 'utf8')
      ).should.equal(
        fs.readFileSync("./test/expected/#{file}", encoding: 'utf8')
      )
