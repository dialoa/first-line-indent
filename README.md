First-line Indent
=================

[![GitHub build status][CI badge]][CI workflow]

Smart first-line indents in Quarto and Pandoc for HTML/LaTeX/PDF outputs. 

[See on GitHub](https://github.com/dialoa/first-line-indent/)

[CI badge]: https://img.shields.io/github/actions/workflow/status/dialoa/indentation/ci.yaml?branch=main
[CI workflow]: https://github.com/dialoa/indentation/actions/workflows/ci.yaml

[labelled-list-repo]: https://github.com/dialoa/dialectica-filters
[PDMan-defaults]: https://pandoc.org/MANUAL.html#option--defaults
[PDMan-filters]: https://pandoc.org/MANUAL.html#option--lua-filter
[PDMan-types]: https://pandoc.org/lua-filters.html#type-block
[RMd-book]: https://bookdown.org/yihui/rmarkdown-cookbook/lua-filters.html
[CTAN-latex-classes]: (https://ctan.org/pkg/classes)

Overview
--------

Quarto/Pandoc's support of first-line indents is limited: it's not
available in HTML output and delegated to LaTeX PDF output. This
filter provides a first-line indentation style with smart defaults,
full customization, and manual control for fine-grain adjustments.

Background
----------

Paragraphs are typically separated in either of two ways: by vertical 
whitespace (common on the web) or by indenting their first line (common 
in books). For the latter conventions vary across typographic traditions:
some (French) indent the first-line of every paragraph while
others (English) don't indent paragraphs after section headings
and indented material such as blockquotes or lists. 

First-line indents are commonly 1\ em, going from 0.5\ em in narrow
line width to 3\ em in wide line widths. LaTeX defaults, used by
Pandoc and Quarto in PDF output, are 1.5\ em in the article and memoir
classes, 1\ em in the KOMA classes.

Default Quarto and Pandoc output uses vertical whitespace to separate
paragraphs. In HTML output this cannot be changed. In PDF output, the
first-line indent style can be used by setting the metadata variable
`indent` to `true`. This has some limitations, however:

* English style indentation is applied, whichever language the `lang`
  variable specifies. French, for isntance, indents paragraphs even
  after section headings.
* Every line following a blockquote, list, code block or other block
  element is treated as a new paragraph, hence indented. This is
  typically, though not always, unwanted, as the text following a
  blockquote or list is usually a continuation of the same paragraph.
* The first line under a title or chapter title is indented. This
  LaTeX default isn't good typography: the first paragraph doesn't
  need a separation. 

This filter provides first-line indentation in HTML output and 
improves its handling in both PDF and HTML outputs. 

1) First-line indentation is used to separate paragraphs, unless
   `indent` is set to `false`. 
2) It generates HTML outputs with first-line indent style. That is
  done by appending CSS code in the document's metadata
  `header-includes` field. This can be disabled if you want to provide
  your own CSS.
1) You can keep or remove the indent of specific paragraphs manually,
   by adding `\indent` and `\noindent` at the beginning of the
   paragraph in the markdown source. These are LaTeX commands but will
   work with HTML output too.
2) First-line indentation is not applied certain block elements: by
   default, not after lists, block quotes, code blocks and horizontal
   rules. You can specify which through the filter's options. This can
   be overridden on a per-paragraph basis by inserting `\indent` at
   the beginning of the paragraph. 
3) The width of first-line indentations can be customized.

Installation
------------

### Quarto

Install this filter in a document's folder by running:

```bash
quarto install extension dialoa/first-line-indent
```

on the command line (terminal in RStudio).

Use it by adding `first-line-indent` to the `filters` entry
of your YAML header.

``` yaml
---
filters:
  - first-line-indent
---
```

### Pandoc

Copy the file `first-line-indent.lua` in your document folder. Pass 
the filter to Pandoc via the `--lua-filter` (or `-L`) command
line option.

``` bash
pandoc --lua-filter first-line-indent.lua ...
```

Or specify it in a defaults file (see [Pandoc's manual:
defaults][PDMan-defaults]).

You can place the filter file Pandoc's user data dir, or in an
arbitrary folder (`-L path/to/first-line-indent.lua`). See [Pandoc's
manual:Lua filters][PDMan-filters]. 

### R Markdown

Copy the file `first-line-indent.lua` in your document folder. Use
`pandoc_args` to invoke the filter. See the [R Markdown
Cookbook][RMd-book] for details.

``` yaml
---
output:
  word_document:
    pandoc_args: ['--lua-filter=first-line-indent.lua']
---
```

You can place the filter in another folder, provided you specify its
path:

``` yaml
---
output:
  word_document:
    pandoc_args: ['--lua-filter=../path/to/first-line-indent.lua']
---
```

Basic usage
-----------

See also the [sample input file](https://dialoa.github.io/first-line-indent/#input.md) 
and the resulting [HTML output](https://dialoa.github.io/first-line-indent/#output.html).

### Applying first-line indent to a whole document

To apply first-line indentation to your entire document, set `indent`
to `true` in the YAML header:

```yaml
---
indent: true
---
```

In Quarto, `indent` may also be set per format:

```yaml
---
format:
  html:
    indent: false
  pdf:
    indent: true
---
```

The filter applies some typesetting adjustments, e.g. no first-line
indentation after lists. See [typesetting-background] below for
details. If you're not happy with the adjustments, you can control
them via options and manually apply or remove indents from some
paragraphs.

### Manually add or remove first-line indent on a paragraph

Whether or not first-line indentation is activated for the whole
document, you can manually add or remove it from a particular
paragraph by inserting `\indent` or `\noindent` at the beginning of
the paragraph:

```markdown
> This is a blockquote

\indent This paragraph will have an indent even though it follows a
blockquote.
```

Even though `\indent` and `\noindent` are LaTeX commands, the filter
handles them in HTML output too.

__Warning: citations after `\indent`__. If the paragraph starts
with a square-bracketed citation, `\indent` or `\noindent` must
be marked as a "Raw Inline", as follows:

```
`\indent`{=tex} [@Smith2008] says....
```

That is because Pandoc/Quarto interprets `\indent [@cite]` as a
LaTeX command with a bracketed option rather than a LaTeX command
followed by a citation. 

Advanced usage
--------------

### Filter options

Filter options are specified in the document's YAML header:

```yaml
indent: true
first-line-indent:
  size: 2em
  auto-remove: true
  set-metadata-variable: true
  set-header-includes: true
  remove-after:
    - BlockQuote
    - BulletList
    - CodeBlock
    - DefinitionList
    - HorizontalRule
    - OrderedList
  dont-remove-after: Table
  remove-after-class: 
    - statement
  dont-remove-after-class: 
```

Different options can be provided for different output formats.
Format-specific options override global ones. For instance, to disable
first line indentation in HTML output only:

```yaml
# Format-specific options
format:
  html:
    indent: false
    first-line-indent:
      set-header-includes: false
# Global options
indent: true
first-line-indent:
  size: 2em
```

With Pandoc, options can also be provided in a [default
file][PdM-defaults], placed within
the `metadata` key:

```yaml
metadata:
  indent: true
  first-line-indent:
    size: 
    auto-remove: true
    ...
```

### Options reference

`indent` (default `true`)

: If set to `false`, paragraphs are separated with vertical whitespace
  rather than first line indentation. This essentially deactivates the
  filter, though `\indent` can still be used to add indent to
  individual paragraphs for HTML output as well as PDF.

`size` (default `nil`)

: String specificing size of the first-line indent. Must be in a
  format suitable for all desired outputs. `1.5em`, `2ex`, `.5pc`,
  `10pt`, `25mm`, `2.5cm`, `0.3in`, all work in LaTeX and HTML. `25px`
  only works in HTML. LaTeX commands (`\textheight`) are not
  supported.

`auto-remove` (default `true`)

: Whether the filter automatically removes first line indentation from
  paragraphs that follow blocks of given types, unless they start with
  `\indent`. Set to `false` to disable. Use the `remove-after...` and
  `dont-remove-after...` options below to control which block types
  and Div classes are handled that way. By default first-line
  indentation is removed after Blockquote, lists (DefinitionList,
  BulletList, OrderedList, which include numbered example lists) and
  HorizontalRule blocks.

`set-metadata-variable` (default: `true`): 

: Whether the filter adds the metavariable `indent` with the value `true` when it
  is missing. Without this Pandoc's LaTeX template does not use first-line
  indentation in PDF output. 

`set-header-includes` (default `true`)

: Whether the filter should
  add formatting code to the document's `header-includes` metadata
  field. Set it to `false` if you use a custom template instead.


`remove-after`, `dont-remove-after`

: Whether to remove
  first-line indentations automatically after blocks of a certain type.
  These options can be a single string or a list of strings. The
  strings are case-sensitive and should correspond to [block types in
  Lua filters][PDMan-types]:
  BlockQuote, BulletList, CodeBlock, DefinitionList, Div, Header,
  HorizontalRule, LineBlock, Null, OrderedList, Para, Plain, RawBlock,
  Table. Inactive if `auto-remove` is false.

`remove-after-class`, `dont-remove-after-class`

: Decide whether to
  remove first-line indentation automatically after elements of certain
  classes. For instance, you may use decide that when a block with class
  "continuing" is followed by a paragraph, the latter should not 
  be first-line indented. Useful for Div elements, if you use 
  Divs of certain classes to wrap and typeset
  material that doesn't end a paragraph. Inactive if `auto-remove` is
  false.

To illustrate, suppose you don't want to filter to remove first-line
indent after definition lists. You can add the following lines in the
document's metadata block (if the source is markdown):

```yaml
first-line-indent:
  dont-remove-after: DefinitionList
```

### Styling HTML output

In LaTeX output the filters adds `\noindent` commands at beginning of
paragraphs that shouldn't be indented. These can be controlled in
LaTeX as usual.

In HTML output paragraphs that are explicitly marked to have no
first-line indent are preceded by an empty `div` with class
`no-first-line-indent-after` and those that are explictly marked (with
`\indent` in the markdown source) to have a first-line indent are
preceded by an empty `div` with class `first-line-indent-after`, as
follows:

```html
<ul>
  <li>A bullet</li>
  <li>list</li>
</ul>
<div class="no-first-line-indent-after"></div>
<p>This paragraph should not have first-line indent.</p>
...
<div class="first-line-indent-after"></div>
<p>This paragraph should have first-line indent.</p>
```

These can be styled in CSS as follows:

```css
p {
  text-indent: 1.5em;
  margin: 0;
}
header p {
  text-indent: 0;
  margin: 1em 0;
}
:is(h1, h2, h3, h4, h5, h6) + p {
  text-indent: 0;
}
li > p, li > div > p, li > div > div > p {
  text-indent: 0;
  margin-bottom: 1rem;
}
div.no-first-line-indent-after + p {
  text-indent: 0;
}
div.first-line-indent-after + p {
  text-indent: SIZE;
}      
```

The first four rules provide global first line indentation.

* The `p` rule adds first-line indentation to every paragraph and
  removes the default vertical space between paragraphs. 
* The `header p` rule restores the default whitespace separation
  setting for paragraphs in the `<header>` element.
* The `is(h1, h2, h3, h4, h5, h6) + p` rule removes first-line
  indentation from every paragraph that follows a heading. 
* The `li > p` rule restores the vertical whitespace separation style
  within lists. It only targets paragraphs that are direct child of a
  list (`li > p`) rather that all paragraphs within a list (`li p`) in
  case a list item contains e.g. a block quote that requires first
  line indentation. However in case a list item's paragraphs are
  contained within some Div, we also target paragraphs that are child
  of a Div, or sub-Div, of a list item (`li > div > p` and `li > div >
  div >p`).

The last two rules provide explicit local indentation. The
`div.no-first-line-indent-after) + p` rule removes indent from
paragraphs placed just after a Div with the
`no-first-line-indent-after` class, and the second rule keeps them in
paragraphs that follow a `first-line-indent-after` Div.

The indentation filter adds the following rule:

``` css
div.labelled-lists-list > p {
    text-indent: 0;
}
```

To avoid interference with Dialoa's [labelled-lists filter][labelled-list-repo].

### Block quotations and the LaTeX `quote` environment

The filter applies first line indent style within block quotes, with
no indent on the first line.

To achieve this in PDF output, the LaTeX `quote` environment (used by
Quarto/Pandoc for block quotes) is redefined as follows in
`header-includes`:

``` latex
\renewenvironment{quote}
     {\list{}{\listparindent 1.5em%
              \itemindent \listparindent
              \rightmargin \leftmargin
              \parsep \z@ \@plus \p@}%
            \item\relax}
      {\endlist}
```

Which is the definition of LaTeX's `quotation` environment---see the
[standard classes source][CTAN-latex-classes].

If you redefine the `quote` environment, you should use this code as
basis. 

### Overriding the filter's `header-includes`

The filter adds its commands at the *beginning* of the
`header-includes` field. You can thus use `header-includes` to
override the filter's commands. 

Contributing
------------

Issues and PRs welcome. 

License
------------------------------------------------------------------

Copyright 2021-2023 Julien Dutant. 
License MIT - see license file for details.
