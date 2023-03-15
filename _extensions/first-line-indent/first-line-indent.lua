--[[# first-line-indent.lua – First line indentation filter

Copyright: © 2021–2023 Contributors
License: MIT – see LICENSE for details

@TODO latex_quote should use options.size (or better, a specific option)
@TODO option for leaving indents after headings (French style)
@TODO smart setting of the post-heading style based on `lang`
@TODO option to leave indent at the beginning of the document

]]

PANDOC_VERSION:must_be_at_least '2.17'
stringify = pandoc.utils.stringify
equals = pandoc.utils.equals
pandoctype = pandoc.utils.type

-- # Options

---@class Options Options map with default values.
---@field format string|nil output format (currently: 'html' or 'latex')
---@field indent boolean whether to use first line indentation globally
---@field set_metadata_variable boolean whether to set the `indent`
--    metadata variable.
---@field set_header_includes boolean whether to provide formatting code in
--    header-includes.
---@field auto_remove_indents boolean whether to automatically remove
--    indents after specific block types.
---@field remove_after table list of strings, Pandoc AST block types
--    after which first-line indents should be automatically removed.
---@field remove_after_class table list of strings, classes of elements
--    after which first-line indents should be automatically removed.
---@field dont_remove_after_class table list of strings, classes of elements
--    after which first-line indents should not be removed. Prevails
--    over remove_after.
---@field size string|nil a CSS / LaTeX specification of the first line
--    indent length
---@field recursive table<string, options> Pandoc Block types to
---     which the filter is recursively applied, with options map.
---     The option `dont_indent_first` controls whether indentation
---     is removed on the first paragraph.
local Options = {
  format = nil,
  indent = true,
  set_metadata_variable = true,
  set_header_includes = true,
  auto_remove = true,
  remove_after = pandoc.List({
    'BlockQuote',
    'BulletList',
    'CodeBlock',
    'DefinitionList',
    'HorizontalRule',
    'OrderedList',
  }),
  remove_after_class = pandoc.List({
    'statement',
  }),
  dont_remove_after_class = pandoc.List:new(),
  size = nil, -- default let LaTeX decide
  size_default = '1.5em', -- default value for HTML
  recursive = {
    Div = {dont_indent_first = false},
    BlockQuote = {dont_indent_first = true},
  }
}

-- # Filter global variables

---@class code map pandoc objects for indent/noindent Raw code.
local code = {
  tex = {
    indent = pandoc.RawInline('tex', '\\indent '),
    noindent = pandoc.RawInline('tex', '\\noindent '),
  },
  latex = {
    indent = pandoc.RawInline('latex', '\\indent '),
    noindent = pandoc.RawInline('latex', '\\noindent '),
  },
  html = {
    indent = pandoc.RawBlock('html',
      '<div class="first-line-indent-after"></div>'),
    noindent = pandoc.RawBlock('html',
      '<div class="no-first-line-indent-after"></div>'),
  }
}


---LATEX_QUOTE_ENV: LaTeX's definition of the quote environement
---used to define HeaderIncludes.
---a \setlength{\parindent}{<size>} will be appended
---@type string
local LATEX_QUOTE_ENV = [[\makeatletter
  \renewenvironment{quote}
     {\list{}{\listparindent 1.5em%
              \itemindent \listparindent
              \rightmargin \leftmargin
              \parsep \z@ \@plus \p@}%
            \item\noindent\relax}
      {\endlist}
  \makeatother
]]

---@class HeaderIncludes map of functions to produce
---header-includes code given a size parameter (string|nil),
--- either for global or for local indentation markup.
--- optionally wrap the constructed global header markup (e.g. <style> tags).
--- glob = {html : function, latex: function}
--- wrap = {html : function, latex: function}
--- loc = {html : function, latex: function}
HeaderIncludes = {
  glob = {
    html = function(size)
      size = size or Options.size_default
      local code = [[  p {
    text-indent: SIZE;
    margin: 0;
  }
  header p {
    text-indent: 0;
    margin: 1em 0;
  }
  :is(h1, h2, h3, h4, h5, h6) + p {
    text-indent: 0;
  }
  li > p, li > div p {
    text-indent: 0;
    margin-bottom: 1rem;
  }
]]
      return code:gsub("SIZE", size)
    end,
    latex = function(size)
      local size_code = size and '\\setlength{\\parindent}{'..size..'}\n'
                        or ''
      return LATEX_QUOTE_ENV .. size_code
    end,
  },
  wrap = {
    html = function(header_str)
      return "<style>\n/* first-line indent styles */\n" .. header_str
        .. "/* end of first-line indent styles */\n</style>"
    end,
    latex = function(str) return str end,
  },
  loc = {
    html = function(size)
      size = size or Options.size_default
      local code = [[  div.no-first-line-indent-after + p {
    text-indent: 0;
  }
  div.first-line-indent-after + p {
    text-indent: SIZE;
  }
]]
      return code:gsub("SIZE", size)
    end,
    latex = function(_) return '' end,
  }
}

-- # encapsulate Quarto/Pandoc variants

---format_match: whether format matches a string pattern
---ex: format_match('html5'), format_match('html*')
---in Quarto we try removing non-alphabetical chars
---@param pattern string
---@return boolean
local function format_match(pattern)
  return quarto and (quarto.doc.is_format(pattern)
      or quarto.doc.is_format(pattern:gsub('%A',''))
    )
    or FORMAT:match(pattern)
end

---add_header_includes: add a block to the document's header-includes
---meta-data field.
---@param meta pandoc.Meta the document's metadata block
---@param blocks pandoc.Blocks list of Pandoc block elements (e.g. RawBlock or Para)
---   to be added to the header-includes of meta
---@return pandoc.Meta meta the modified metadata block
local function add_header_includes(meta, blocks)

  -- Pandoc
  local function pandoc_add_headinc(meta,blocks)

    local header_includes = pandoc.MetaList( { pandoc.MetaBlocks(blocks) })

    -- add any exisiting meta['header-includes']
    -- it can be MetaInlines, MetaBlocks or MetaList
    if meta['header-includes'] then
      if pandoctype(meta['header-includes']) == 'List' then
        header_includes:extend(meta['header-includes'])
      else
        header_includes:insert(meta['header-includes'])
      end
    end

    meta['header-includes'] = header_includes

    return meta

  end

  -- Quarto
  local function quarto_add_headinc(blocks)
    quarto.doc.include_text('in-header', stringify(blocks))
  end

  return quarto and quarto_add_headinc(blocks)
    or pandoc_add_headinc(meta,blocks)

end


-- # Helper functions

-- ensure_list: turns Inlines and Blocks meta values into list
local function ensure_list(elem)
  if elem and (pandoctype(elem) == 'Inlines'
    or pandoctype(elem) == 'Blocks')  then
    elem = pandoc.List:new(elem)
  end
  return elem
end


--- classes_include: check if one of an element's class is in a given
-- list. Returns true if match, nil if no match or the element doesn't
-- have classes.
---@param elem table pandoc AST element
---@param classes table pandoc List of strings
local function classes_include(elem,classes)

  if elem.classes then

    for _,class in ipairs(classes) do
      if elem.classes:includes(class) then return true end
    end

  end

end

--- is_indent_cmd: check if an element is a LaTeX indent command
---@param elem pandoc.Inline
---@return string|nil 'indent', 'noindent' or nil
-- local function is_indent_cmd(elem)
--   return (equals(elem, code.latex.indent)
--     or equals(elem, code.tex.indent)) and 'indent'
--     or (equals(elem, code.latex.noindent)
--     or equals(elem, code.tex.noindent)) and 'noindent'
--     or nil
-- end
local function is_indent_cmd(elem)
  return elem.text and (
      elem.text:match('^%s*\\indent%s*$') and 'indent'
      or elem.text:match('^%s*\\noindent%s*$') and 'noindent'
    )
    or nil
end

-- # Filter functions

--- Add format-specific explicit indent markup to a paragraph.
--- Returns a list of blocks containing a single paragraph
--- or a rawblock followed by a paragraph, depending on format.
---@param type string 'indent' or 'noindent', type of markup to add
---@param elem pandoc.Para
---@return pandoc.Blocks
local function indent_markup(type, elem)
  local result = pandoc.List:new()

  if not (type == 'indent' or type == 'noindent') then

    result:insert(elem)

  elseif format_match('latex') then

    -- in LaTeX, replace any `\indent` or `\noindent`
    -- at the beginning of the paragraph with
    -- with the one corresponding to `type`

    if elem.content[1] and is_indent_cmd(elem.content[1]) then
      elem.content[1] = code.tex[type]
    else
      elem.content:insert(1, code.tex[type])
    end
    result:insert(elem)


  elseif format_match('html') then

    result:extend({ code.html[type], elem })

  end

  return result

end

--- process_blocks: process indentations in a list of blocks.
-- Adds output code for explicitly specified first-line indents,
-- automatically removes first-line indents after blocks of the
-- designed types unless otherwise specified.
---@param blocks pandoc.Blocks element (list of blocks)
---@param dont_indent_first boolean whether to indent the first paragraph
local function process_blocks(blocks, dont_indent_first)
  dont_indent_first = dont_indent_first or false
  -- tag for the first element
  local is_first_block = true -- tags the doc's first element
  -- tag to trigger indentation auto-removal on the next element
  local dont_indent_next_block = false
  local result = pandoc.List:new()

  for _,elem in pairs(blocks) do

    -- Paragraphs: if they have explicit LaTeX indent markup
    -- reproduce it in the output format, otherwise
    -- remove indentation if needed, provided `auto_remove` is on.
    if elem.t == "Para" then

      if elem.content[1] and is_indent_cmd(elem.content[1]) then

        -- 'indent' or 'noindent' ?
        local type = is_indent_cmd(elem.content[1])

        result:extend(indent_markup(type, elem))

      elseif is_first_block and dont_indent_first then

          result:extend(indent_markup('noindent', elem))

      elseif dont_indent_next_block and Options.auto_remove then

        result:extend(indent_markup('noindent', elem))

      else

        result:insert(elem)

      end

      dont_indent_next_block = false

    -- Non-Paragraphs: check first whether it's an element after
    -- which indentation must be removed. Next insert it, applying
    -- this function recursively within the element if needed.
    else

      if Options.auto_remove then

        if Options.remove_after:includes(elem.t) and
            not classes_include(elem, Options.dont_remove_after_class) then

          dont_indent_next_block = true

        elseif elem.classes and
            classes_include(elem, Options.remove_after_class) then

          dont_indent_next_block = true

        else

          dont_indent_next_block = false

        end

      end

      -- recursively process the element if needed
      if Options.recursive[elem.t] then

        local dif = Options.recursive[elem.t].dont_indent_first
        elem.content = process_blocks(elem.content, dif)

      end

      -- insert
      result:insert(elem)

    end

    -- ensure `is_first_block` turns to false
    -- even if the first block wasn't a paragraph
    -- or if it had explicit indent marking
    is_first_block = false

  end

  return result

end

--- process_doc: Process indents in the document's body text.
-- Adds output code for explicitly specified first-line indents,
-- automatically removes first-line indents after blocks of the
-- designed types unless otherwise specified.
local function process_doc(doc)
  local dont_indent_first = false

  -- if no output format, do nothing
  if not Options.format then return end

  -- if the doc has a title, do not indent first paragraph
  if doc.meta.title then
    dont_indent_first = true
  end

  doc.blocks = process_blocks(doc.blocks, dont_indent_first)

  return doc

end


--- read_user_options: read user options from meta element.
-- in Quarto options may be under format/pdf or format/html
-- the latter override root ones.
local function read_user_options(meta)
  local user_options = {}

  if meta.indent == false then
    Options.indent = false
  end

  if meta['first-line-indent'] then
    user_options = meta['first-line-indent']
  end

  local formats = {'pdf', 'html', 'latex'}
  if meta.format then
    for format in ipairs(formats) do
      if format_match(format) and meta.format[format] then
        for k,v in meta.format[format] do
          user_options[k] = v
        end
      end
    end
  end

  if user_options['set-metadata-variable'] == false then
    Options.set_metadata_variable = false
  end

  if user_options['set-header-includes'] == false then
    Options.set_header_includes = false
  end

  -- size
  -- @todo using stringify means that LaTeX commands in
  -- size are erased. But it ensures that the filter gets
  -- a string. Improvement: check that we have a string
  -- and throw a warning otherwise
  if user_options.size and pandoctype(user_options.size == 'Inlines') then

    Options.size = stringify(user_options.size)

  end

  if user_options['auto-remove'] == false then
    Options.auto_remove = false
  end

  -- autoremove elements and classes
  -- for elements we only need a whitelist, remove_after
  -- for classes we need both a whitelist (remove_after_class)
  -- and a blacklist (dont_remove_after_class).

  -- first insert user values in `remove_after`, `remove_after_class`
  -- and `dont_remove_after_class`.
  for optname, metakey in pairs({
    remove_after = 'remove-after',
    remove_after_class = 'remove-after-class',
    dont_remove_after_class = 'dont-remove-after-class',
  }) do

    local user_value = ensure_list(user_options[metakey])

    if user_value and pandoctype(user_value) == 'List' then

        for _,item in ipairs(user_value) do

          Options[optname]:insert(stringify(item))

        end

    end

  end

  -- then remove blacklisted entries from `remove_after`
  -- and `remove_after_class`.
  for optname, metakey in pairs({
    remove_after = 'dont-remove-after',
    remove_after_class = 'dont-remove-after-class'
  }) do

    local user_value = ensure_list(user_options[metakey])

    if user_value and pandoctype(user_value) == 'List' then

      -- stringify the list
      for i,v in ipairs(user_value) do
        user_value[i] = stringify(v)
      end

      -- filter to that returns true iff an item isn't blacklisted
      local predicate = function (str)
        return not(user_value:includes(str))
      end

      -- apply the filter to the whitelist
      Options[optname] = Options[optname]:filter(predicate)

    end

  end

end

--- set_meta: insert options in doc's meta
--- Sets `indent` and extends `header-includes` if needed.
---@param meta pandoc.Meta
---@return pandoc.Meta|nil meta nil if no changes
local function set_meta(meta)
  local changes = false -- only return if changes are made
  local header_code = nil
  local format = Options.format

  -- set the `indent` metadata variable unless otherwise specified or
  -- already set to false
  if Options.set_metadata_variable and not(meta.indent == false) then
    meta.indent = true
    changes = true
  end

  -- set the `header-includes` metadata variable
  if Options.set_header_includes and Options.indent then

    -- do we apply first line indentation globally?
    if Options.indent then
      header_code = HeaderIncludes.glob[format](Options.size)
    end
    -- provide local explicit indentation styles
    header_code = header_code .. HeaderIncludes.loc[format](Options.size)
    -- wrap the header if needed
    header_code = HeaderIncludes.wrap[format](header_code)
    
    -- insert if not empty
    if header_code ~= '' then
      add_header_includes(meta, { pandoc.RawBlock(format, header_code)})
      changes = true
    end

  end

  return changes and meta or nil

end

--- process_metadata: process user options.
-- read user options, set the `indent` metadata variable,
-- add formatting code to `header-includes`.
local function process_metadata(meta)
  local changes = false -- only return if changes are made
  local header_code = nil
  local format = format_match('html') and 'html'
                or (format_match('latex') and 'latex')

  if not format then
    return nil
  else
    Options.format = format
  end

  read_user_options(meta) -- places values in global `options`

  return set_meta(meta)

end

--- Main code
-- Returns the filters in the desired order of execution
return {
  {
    Meta = process_metadata
  },
  {
    Pandoc = process_doc
  }
}
