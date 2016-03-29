# Tidy Markdown

[![Build Status](http://img.shields.io/travis/slang800/tidy-markdown.svg?style=flat-square)](https://travis-ci.org/slang800/tidy-markdown) [![NPM version](http://img.shields.io/npm/v/tidy-markdown.svg?style=flat-square)](https://www.npmjs.org/package/tidy-markdown) [![NPM license](http://img.shields.io/npm/l/tidy-markdown.svg?style=flat-square)](https://www.npmjs.org/package/tidy-markdown)

Beautify Markdown, fixing formatting mistakes and converting basic HTML & Unicode into their Markdown equivalents. Based on the conventions in [Carrot Creative's Markdown Styleguide](https://github.com/carrot/markdown-styleguide) and built on [Marked](https://github.com/chjj/marked).

There is also an [Atom Plugin](https://atom.io/packages/tidy-markdown) to run this entirely within your editor.

## Install

Tidy Markdown is an [npm](http://npmjs.org/package/tidy-markdown) package, so it can be installed like this:

```bash
npm install tidy-markdown -g
```

## CLI

Tidy Markdown includes a simple CLI. It operates entirely over STDIN/STDOUT. For example:

```bash
$ echo "# a header #" | tidy-markdown
# a header
```

Or using a file:

```bash
$ tidy-markdown < ./ugly-markdown
# Some markdown

Lorem ipsum dolor adipiscing

- one
- two
- three
```

And, of course, we can output to a file too:

```bash
$ tidy-markdown < ./ugly-markdown > ./clean-markdown
```

### Docs

The `--help` arg will make it show a usage page:

```
$ tidy-markdown --help
usage: tidy-markdown [-h] [-v] [--no-ensure-first-header-is-h1]

Fix ugly markdown. Unformatted Markdown is read from STDIN, formatted, and
written to STDOUT.

Optional arguments:
  -h, --help            Show this help message and exit.
  -v, --version         Show program's version number and exit.
  --no-ensure-first-header-is-h1
                        Disable fixing the first header when it isn't an H1.
                        This is useful if the markdown you're processing
                        isn't a full document, but rather a piece of a larger
                        document.
```

### Editing In-place

If you want to rewrite a file in-place, you can use `sponge` from [moreutils](https://joeyh.name/code/moreutils/). If you did `tidy-markdown < ./README.md > ./README.md` you'd end up with an empty file.

```bash
$ tidy-markdown < ./README.md | sponge ./README.md
```

## API

Tidy Markdown only exports one function. Here's an example of how it can be used:

```coffee
tidyMarkdown = require 'tidy-markdown'

uglyMarkdown = '''
# Some markdown #

Lorem ipsum dolor adipiscing


- one
*  two
+ three
'''

cleanMarkdown = tidyMarkdown(uglyMarkdown)
console.log cleanMarkdown
```

which outputs:

```markdown
# Some markdown

Lorem ipsum dolor adipiscing

- one
- two
- three
```

You can also pass options through a 2nd arg, like `tidyMarkdown(uglyMarkdown, {ensureFirstHeaderIsH1: false})`. The option `ensureFirstHeaderIsH1` is the only one right now.

## Features

- Standardize syntactical elements to use a single way of being written (for example, all unordered lists are formatted to start with hyphens, rather than allowing asterisks and/or addition signs to be mixed in).
- Fix numbering - making ordered lists count naturally from 1 to _n_ and reference links do the same (based on first occurance).
- Make headers move from `h1` to smaller without gaps (like an `h1` followed by an `h4` would be corrected to an `h1` followed by an `h2`).
- Decode Unicode characters that have markdown equivalents (like a horizontal ellipsis becomes "..." and an em-dash becomes "--").
- Format YAML front-matter and Markdown tables.
- Convert HTML elements into their Markdown equivalents. For example, `<em>text</em>` becomes `_text_`.

## Minimal Configuration

Tidy Markdown works hard to keep configuration to a minimum. The goal is to create a highly readable, canonical representation of Markdown, much like [gofmt](https://golang.org/cmd/gofmt/) has done for Go. Having extra configuration would defeat that purpose and add extra maintenance work.

That's not to say you shouldn't open issues if you find the output ugly, that's encouraged, especially in the [styleguide repo](https://github.com/slang800/markdown-styleguide) because without criticism it won't get better. However, you should provide examples and a good argument to support the change.
