# Tidy Markdown
[![Build Status](http://img.shields.io/travis/slang800/tidy-markdown.svg?style=flat-square)](https://travis-ci.org/slang800/tidy-markdown) [![NPM version](http://img.shields.io/npm/v/tidy-markdown.svg?style=flat-square)](https://www.npmjs.org/package/tidy-markdown) [![NPM license](http://img.shields.io/npm/l/tidy-markdown.svg?style=flat-square)](https://www.npmjs.org/package/tidy-markdown)

Beautify Markdown, fixing formatting mistakes and converting basic HTML & Unicode into their Markdown equilivants. Based on the conventions in [Carrot Creative's Markdown Styleguide](https://github.com/carrot/markdown-styleguide) and built on [Marked](https://github.com/chjj/marked).

## API
Tidy Markdown only exports one function, that takes one argument (the string of ugly markdown). Here's an example of how it can be used:

```coffee
tidyMarkdown = require 'tidy-markdown'

uglyMarkdown = '''
# some markdown #

Lorem ipsum dolor adipiscing


quis massa lorem
'''

cleanMarkdown = tidyMarkdown(uglyMarkdown)
console.log cleanMarkdown
```

which outputs:

```markdown
# some markdown
Lorem ipsum dolor adipiscing

quis massa lorem
```

## Features
- standardize syntactical elements to use a single way of being written (for example, all unordered lists are formatted to start with hyphens, rather than allowing asterisks and/or addition signs to be mixed in).
- fix numbering - making ordered lists count naturally from 1 to _n_ and reference links do the same (based on first occurance).
- make headers move from h1 to smaller without gaps (like an `h1` followed by an `h4` would be corrected to an `h1` followed by an `h2`).
- decode Unicode characters that have markdown equivalents (like a horizontal ellipsis becomes "..." and an em-dash becomes "--").
- move long or repeated links into the reference links section.
