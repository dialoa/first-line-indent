# Name of the filter file, *with* `.lua` file extension.
FILTER_FILE := $(wildcard *.lua)
# Name of the filter, *without* `.lua` file extension
FILTER_NAME = $(patsubst %.lua,%,$(FILTER_FILE))
# Format (as Pandoc option) and extension
# for the sample output in the website
WEBSITE_OUTPUT_FORMAT = html
WEBSITE_OUTPUT_EXT = html

# Allow to use a different Pandoc binary, e.g. when testing,
# or Quarto-embedded pandoc with `quarto pandoc`
PANDOC ?= pandoc
# Allow to use a different Quarto binary
QUARTO = quarto
# Allow to adjust the diff command if necessary
DIFF = diff
# Use a POSIX sed with ERE ('v' is specific to GNU sed)
SED := sed $(shell sed v </dev/null >/dev/null 2>&1 && echo " --posix") -E

# Directory containing the Quarto extension
QUARTO_EXT_DIR = _extensions/$(FILTER_NAME)
# The extension's name. Used in the Quarto extension metadata
EXT_NAME = $(FILTER_NAME)
# Current version, i.e., the latest tag. Used to version the quarto
# extension.
VERSION = $(shell git tag --sort=-version:refname --merged | head -n1 | \
						 sed -e 's/^v//' | tr -d "\n")
ifeq "$(VERSION)" ""
VERSION = 0.0.0
endif

# GitHub repository; used to setup the filter.
REPO_PATH = $(shell git remote get-url origin | sed -e 's%.*github\.com[/:]%%')
REPO_NAME = $(shell git remote get-url origin | sed -e 's%.*/%%')
USER_NAME = $(shell git config user.name)

## Show available targets
# Comments preceding "simple" targets (those which do not use macro
# name or starts with underscore or dot) and introduced by two dashes
# are used as their description.
.PHONY: help
help:
	@tabs 22 ; $(SED) -ne \
	'/^## / h ; /^[^_.$$#][^ ]+:/ { G; s/^(.*):.*##(.*)/\1@\2/; P ; h ; }' \
	$(MAKEFILE_LIST) | tr @ '\t'

#
# Test
#

## Test that running the filter on the sample input yields expected output
# The automatic variable `$<` refers to the first dependency
# (i.e., the filter file).
# let `test` be a PHONY target so that it is run each time it's called.
.PHONY: test
test: test_pandoc test_quarto

test_pandoc: test_pandoc_html test_pandoc_latex

test_pandoc_html: $(FILTER_FILE) input.md test/test.yaml
	$(PANDOC) --defaults test/test.yaml input.md -t html \
		| $(DIFF) test/expected_pandoc.html -

test_pandoc_latex: $(FILTER_FILE) input.md test/test.yaml
	$(PANDOC) --defaults test/test.yaml input.md -t latex \
		| $(DIFF) test/expected_pandoc.tex -

test_quarto: test_quarto_html

test_quarto_html: $(FILTER_FILE) input.md test/test.yaml
	$(QUARTO) render input.md -t html --output=output.html
	$(DIFF) test/expected_quarto.html test/output.html
	rm test/output.html

# Cannot check Quarto's LaTeX as it's not constant between inputs
# line: \ifdefined\Shaded\renewenvironment{Shaded}...
# ...{\begin{tcolorbox}[breakable, etc. 
# the `tcolorbox` options order changes on each run.
#
# test_quarto_latex: $(FILTER_FILE) input.md test/test.yaml
#	$(QUARTO) render input.md -t latex --output=output.tex
#	$(DIFF) test/expected_quarto.tex test/output.tex
#	rm test/output.tex

## Generate expected outputs
# This file **must not** be a dependency of the `test` target, as that
# would cause it to be regenerated on each run, making the test
# pointless.
.PHONY: generate
generate: gen_pandoc gen_quarto

gen_pandoc: test/expected_pandoc.html test/expected_pandoc.tex \
	test/expected_pandoc.pdf

test/expected_pandoc.html: $(FILTER_FILE) input.md test/test.yaml
	$(PANDOC) --defaults test/test.yaml input.md --output=$@

test/expected_pandoc.tex: $(FILTER_FILE) input.md test/test.yaml
	$(PANDOC) --defaults test/test.yaml input.md --output=$@

test/expected_pandoc.pdf: $(FILTER_FILE) input.md test/test.yaml
	$(PANDOC) --defaults test/test.yaml input.md --output=$@

gen_quarto: test/expected_quarto.html test/expected_quarto.tex \
	test/expected_quarto.pdf

test/expected_quarto.html: $(FILTER_FILE) input.md
	$(QUARTO) render input.md -t html --output=expected_quarto.html

test/expected_quarto.tex: $(FILTER_FILE) input.md
	$(QUARTO) render input.md -t latex --output=expected_quarto.tex

test/expected_quarto.pdf: $(FILTER_FILE) input.md
	$(QUARTO) render input.md -t pdf --output=expected_quarto.pdf

#
# Website
#

## Generate website files in _site
.PHONY: website
website: _site/index.html _site/$(FILTER_FILE)

_site/index.html: README.md input.md $(FILTER_FILE) .tools/docs.lua \
		_site/output.$(WEBSITE_OUTPUT_EXT) _site/style.css
	@mkdir -p _site
	$(PANDOC) \
	    --standalone \
	    --lua-filter=.tools/docs.lua \
		--metadata sample-file=input.md \
		--metadata result-file=_site/output.$(WEBSITE_OUTPUT_EXT) \
		--metadata code-file=$(FILTER_FILE) \
	    --css=style.css \
	    --toc \
	    --output=$@ $<

_site/style.css:
	@mkdir -p _site
	curl \
	    --output $@ \
	    'https://cdn.jsdelivr.net/gh/kognise/water.css@latest/dist/light.css'

_site/output.$(WEBSITE_OUTPUT_EXT): $(FILTER_FILE) input.md test/test.yaml
	@mkdir -p _site
	$(PANDOC) \
	    --defaults=test/test.yaml \
		input.md \
	    --to=$(WEBSITE_OUTPUT_EXT) \
	    --output=$@

_site/$(FILTER_FILE): $(FILTER_FILE)
	@mkdir -p _site
	(cd _site && ln -sf ../$< $<)

#
# Quarto extension
#

## Creates or updates the quarto extension
.PHONY: quarto-extension
quarto-extension: $(QUARTO_EXT_DIR)/_extension.yml \
		$(QUARTO_EXT_DIR)/$(FILTER_FILE)

$(QUARTO_EXT_DIR):
	mkdir -p $@

# This may change, so re-create the file every time
.PHONY: $(QUARTO_EXT_DIR)/_extension.yml
$(QUARTO_EXT_DIR)/_extension.yml: _extensions/$(FILTER_NAME)
	@printf 'Creating %s\n' $@
	@printf 'name: %s\n' "$(EXT_NAME)" > $@
	@printf 'author: %s\n' "$(USER_NAME)" >> $@
	@printf 'version: %s\n'  "$(VERSION)" >> $@
	@printf 'contributes:\n  filters:\n    - %s\n' $(FILTER_FILE) >> $@

# The filter file must be below the quarto _extensions folder: a
# symlink in the extension would not work due to the way in which
# quarto installs extensions.
$(QUARTO_EXT_DIR)/$(FILTER_FILE): $(FILTER_FILE) $(QUARTO_EXT_DIR)
	if [ ! -L $(FILTER_FILE) ]; then \
	    mv $(FILTER_FILE) $(QUARTO_EXT_DIR)/$(FILTER_FILE) && \
	    ln -s $(QUARTO_EXT_DIR)/$(FILTER_FILE) $(FILTER_FILE); \
	fi

#
# Release
#

## Sets a new release (uses VERSION macro if defined)
.PHONY: release
release: quarto-extension
	git commit -am "Release $(FILTER_NAME) $(VERSION)"
	git tag v$(VERSION) -m "$(FILTER_NAME) $(VERSION)"
	@echo 'Do not forget to push the tag back to github with `git push --tags`'

#
# Set up (normally used only once)
#

## Update filter name
.PHONY: update-name
update-name:
	sed -i'.bak' -e 's/greetings/$(FILTER_NAME)/g' README.md
	sed -i'.bak' -e 's/greetings/$(FILTER_NAME)/g' test/test.yaml
	rm README.md.bak test/test.yaml.bak

## Set everything up (must be used only once)
.PHONY: setup
setup: update-name
	git mv greetings.lua $(REPO_NAME).lua
	@# Crude method to updates the examples and links; removes the
	@# template instructions from the README.
	sed -i'.bak' \
	    -e 's/greetings/$(REPO_NAME)/g' \
	    -e 's#tarleb/lua-filter-template#$(REPO_PATH)#g' \
      -e '/^\* \*/,/^\* \*/d' \
	    README.md
	sed -i'.bak' -e 's/greetings/$(REPO_NAME)/g' test/test.yaml
	sed -i'.bak' -e 's/Albert Krewinkel/$(USER_NAME)/' LICENSE
	rm README.md.bak test/test.yaml.bak LICENSE.bak
#
# Helpers
#

## Clean regenerables files
.PHONY: clean
clean:
	rm -f _site/output.md _site/index.html _site/style.css
