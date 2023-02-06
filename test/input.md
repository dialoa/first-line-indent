---
title: "First line indent"
author: Julien Dutant
date: 22 Dec 2022
filter:
- first-line-indent
# Filter options. You do not need to specify any,
# remove all the lines below the filter still 
# separates paragraphs with indentation rather
# than vertical whitespace.
first-line-indent:
  set-metadata-variable: true
  set-header-includes: true
  auto-remove: true
  remove-after: Table
  dont-remove-after:
    - DefinitionList
    - OrderedList
  size: "2em"
  remove-after-class: chuckit
  dont-remove-after-class: keepit
---

This document illustrates first-line indent typesetting. In English
typography, paragraphs just below a section heading aren't indented,
because a heading is enough to separate them from what is before. The
same should apply to the first paragraph of a document with a
title---so this paragraph is not indented.

This paragraph is indented. But after this quote:

> Lorem ipsum dolor sit amet, consectetur adipiscing elit.

the paragraph continues, so there should not be a first-line indent.

We want this quote to end a paragraph:

> Lorem ipsum dolor sit amet, consectetur adipiscing elit.

\indent The text below therefore begins a new paragraph and should
have a first-line indent. We have to manually specify using `\indent`. 

# Basic tests

After a heading (in English typographic style) the paragraph does not
have a first-line indent.

## Manually specifying indentation on certain paragraphs

In the couple of paragraphs that follow the quotes below, we
have manually specified `\noindent` and `\indent` respectively. This
is to check that the filter doesn't add its own commands to those.

> Lorem ipsum dolor sit amet, consectetur adipiscing elit.

\indent Here we've explicitly required  a first line indent.

\noindent Here we've explicitly required *not* to have one.

## Automatic removal of first line indentation

We can also check that indent is removed after lists:

* A bullet
* list

And after code blocks:

```lua
local variable = "value"
```

Or horizontal rules.

---

We check that this behavour is overriden for specified classes. We
created a custom class to preserve indentation after certain elements:

``` {.markdown .keepit}
This code block 
should be followed 
by an indented 
paragraph
```

And another one to remove indents after others:

::: chuckit
This paragraph's Div container should not
be followed by indentation,
:::

as specified in this document's options. 

# Further tests

In this document we added a few custom filter options. 

## Size

The size of first-line indents is 2em instead of the default 1.5em
(Pandoc) or 1em (Quarto). 

## Indent within quotes

Blockquotes first-line indentation:

> Blockquotes should not be indented on their first paragraph but
> otherwise have the same size of ident as the main text.
>
> Hence this second paragraph has a first-line indentation of
> 2em.
 

## Keep or remove indentation after certain types of elements

We also added an option to 
automatically remove indent after tables:

  Right     Left     Center     Default
-------     ------ ----------   -------
     12     12        12            12
    123     123       123          123
      1     1          1             1

Table:  Demonstration of simple table syntax.

So this paragraph's first line is not indented. We added the option
*not* to remove ident after ordered lists and definition lists:

Definition
: This is a definition block.

So this paragraph is indented.

1. An ordered
2. list

And this one is too.

## Recursion and nesting

The paragraphs below are nested within a Div element---actually, two
nested Divs, in order to check that the filter is applied recursively
within Divs.

::: {#div}

::::: {#subdiv}

The first paragraph within a Div is indented normally, but the 
list below

* list item
* list item

should not be followed by a indented paragraph.

The last paragraph within Divs should be indented normally.

:::::

:::

The filter is also applied recursively within blockquotes. A
blockquote's first paragraph shouldn't be indented, but any subsequent
ones should. Within the block quotes, indents should be removed after
special blocks, as in the main text. 

> The first paragraph of this blockquote does not
> have a first line indent.
>
> The subsequent paragraph has one. It's followed:
>
> * by a
> * list
> 
> after which there is no first line indentation.
> 
> This next paragraph is first line indented again..

## List content

Within lists, paragraphs should be separated by vertical whitespace.

* This list item contains multiple paragraphs.

  The second one should not be indented, but separated by vertical 
  whitespace.

