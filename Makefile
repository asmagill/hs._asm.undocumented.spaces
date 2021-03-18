mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))

# Universal build info mostly from
#     https://developer.apple.com/documentation/xcode/building_a_universal_macos_binary
# Insight on Universal dSYM from
#     https://lists.apple.com/archives/xcode-users/2009/Apr/msg00034.html

MODULE := $(lastword $(subst ., ,$(current_dir)))
PREFIX ?= ~/.hammerspoon
MODPATH = hs/_asm/undocumented
VERSION ?= 0.x
HS_APPLICATION ?= /Applications

# get from https://github.com/asmagill/hammerspoon-config/blob/master/utils/docmaker.lua
# if you want to generate a readme file similar to the ones I generally use. Adjust the copyright in the file and adjust
# this variable to match where you save docmaker.lua relative to your hammerspoon configuration directory
# (usually ~/.hammerspoon)
MARKDOWNMAKER = utils/docmaker.lua

OBJCFILES = ${wildcard *.m}
LUAFILES  = ${wildcard *.lua}
HEADERS   = ${wildcard *.h}

# for compiling each source file into a separate library
#     (see also obj_x86_64/%.s and obj_arm64/%.s below)
SOFILES  := $(OBJCFILES:.m=.so)

# for compiling all source files into one library
#     (see also obj_x86_64/%.s and obj_arm64/%.s below)
# SOFILES  := internal.so

SOFILES_x86_64   := $(addprefix obj_x86_64/,$(SOFILES))
SOFILES_arm64    := $(addprefix obj_arm64/,$(SOFILES))
SOFILES_univeral := $(addprefix obj_universal/,$(SOFILES))

DEBUG_CFLAGS ?= -g

# special vars for uninstall
space :=
space +=
comma := ,
ALLFILES := $(LUAFILES)
ALLFILES += $(SOFILES)

# CC=clang
CC=@clang
WARNINGS ?= -Weverything -Wno-objc-missing-property-synthesis -Wno-implicit-atomic-properties -Wno-direct-ivar-access -Wno-cstring-format-directive -Wno-padded -Wno-covered-switch-default -Wno-missing-prototypes -Werror-implicit-function-declaration -Wno-documentation-unknown-command -Wno-poison-system-directories
EXTRA_CFLAGS ?= -F$(HS_APPLICATION)/Hammerspoon.app/Contents/Frameworks -DSOURCE_PATH="$(mkfile_path)"
MIN_intel_VERSION ?= -mmacosx-version-min=10.13
MIN_arm64_VERSION ?= -mmacosx-version-min=11

CFLAGS  += $(DEBUG_CFLAGS) -fmodules -fobjc-arc -DHS_EXTERNAL_MODULE $(WARNINGS) $(EXTRA_CFLAGS)
release: CFLAGS  += -DRELEASE_VERSION=$(VERSION)
releaseWithDocs: CFLAGS  += -DRELEASE_VERSION=$(VERSION)
LDFLAGS += -dynamiclib -undefined dynamic_lookup $(EXTRA_LDFLAGS)

all: verify $(shell uname -m)

x86_64: $(SOFILES_x86_64)

arm64: $(SOFILES_arm64)

universal: verify x86_64 arm64 $(SOFILES_univeral)

# for compiling each source file into a separate library
#     (see also SOFILES above)

obj_x86_64/%.so: %.m $(HEADERS)
	$(CC) $< $(CFLAGS) $(MIN_intel_VERSION) $(LDFLAGS) -target x86_64-apple-macos10.13 -o $@

obj_arm64/%.so: %.m $(HEADERS)
	$(CC) $< $(CFLAGS) $(MIN_arm64_VERSION) $(LDFLAGS) -target arm64-apple-macos11 -o $@

# for compiling all source files into one library
#     (see also SOFILES above)

# obj_x86_64/%.so: $(OBJCFILES) $(HEADERS)
# 	$(CC) $(OBJCFILES) $(CFLAGS) $(MIN_intel_VERSION) $(LDFLAGS) -target x86_64-apple-macos10.13 -o $@
#
# obj_arm64/%.so: $(OBJCFILES) $(HEADERS)
# 	$(CC) $(OBJCFILES) $(CFLAGS) $(MIN_arm64_VERSION) $(LDFLAGS) -target arm64-apple-macos11 -o $@

# creating the universal dSYM bundle is a total hack because I haven't found a better
# way yet... suggestions welcome
obj_universal/%.so: $(SOFILES_x86_64) $(SOFILES_arm64)
	lipo -create -output $@ $(subst universal/,x86_64/,$@) $(subst universal/,arm64/,$@)
	mkdir -p $@.dSYM/Contents/Resources/DWARF/
	cp $(subst universal/,x86_64/,$@).dSYM/Contents/Info.plist $@.dSYM/Contents
	lipo -create -output $@.dSYM/Contents/Resources/DWARF/$(subst obj_universal/,,$@) $(subst universal/,x86_64/,$@).dSYM/Contents/Resources/DWARF/$(subst obj_universal/,,$@) $(subst universal/,arm64/,$@).dSYM/Contents/Resources/DWARF/$(subst obj_universal/,,$@)

$(SOFILES_x86_64): | obj_x86_64

$(SOFILES_arm64): | obj_arm64

$(SOFILES_univeral): | obj_universal

obj_x86_64:
	mkdir obj_x86_64

obj_arm64:
	mkdir obj_arm64

obj_universal:
	mkdir obj_universal

verify: $(LUAFILES)
	@if $$(hash lua >& /dev/null); then (luac -p $(LUAFILES) && echo "Lua Compile Verification Passed"); else echo "Skipping Lua Compile Verification"; fi

install: install-$(shell uname -m)

install-lua: $(LUAFILES)
	mkdir -p $(PREFIX)/$(MODPATH)/$(MODULE)
	install -m 0644 $(LUAFILES) $(PREFIX)/$(MODPATH)/$(MODULE)
	test -f docs.json && install -m 0644 docs.json $(PREFIX)/$(MODPATH)/$(MODULE) || echo "No docs.json file to install"

install-x86_64: verify install-lua $(SOFILES_x86_64)
	mkdir -p $(PREFIX)/$(MODPATH)/$(MODULE)
	install -m 0644 $(SOFILES_x86_64) $(PREFIX)/$(MODPATH)/$(MODULE)
	cp -vpR $(SOFILES_x86_64:.so=.so.dSYM) $(PREFIX)/$(MODPATH)/$(MODULE)

install-arm64: verify install-lua $(SOFILES_arm64)
	mkdir -p $(PREFIX)/$(MODPATH)/$(MODULE)
	install -m 0644 $(SOFILES_arm64) $(PREFIX)/$(MODPATH)/$(MODULE)
	cp -vpR $(SOFILES_arm64:.so=.so.dSYM) $(PREFIX)/$(MODPATH)/$(MODULE)

install-universal: verify install-lua $(SOFILES_univeral)
	mkdir -p $(PREFIX)/$(MODPATH)/$(MODULE)
	install -m 0644 $(SOFILES_univeral) $(PREFIX)/$(MODPATH)/$(MODULE)
	cp -vpR $(SOFILES_univeral:.so=.so.dSYM) $(PREFIX)/$(MODPATH)/$(MODULE)

uninstall:
	rm -v -f $(PREFIX)/$(MODPATH)/$(MODULE)/{$(subst $(space),$(comma),$(ALLFILES))}
	(pushd $(PREFIX)/$(MODPATH)/$(MODULE)/ ; rm -v -fr $(SOFILES:.so=.so.dSYM) ; popd)
	rm -v -f $(PREFIX)/$(MODPATH)/$(MODULE)/docs.json
	rmdir -p $(PREFIX)/$(MODPATH)/$(MODULE) ; exit 0

clean:
	rm -rf obj_x86_64 obj_arm64 obj_universal tmp docs.json

docs:
	hs -c "require(\"hs.doc\").builder.genJSON(\"$(dir $(mkfile_path))\")" > docs.json

markdown:
	hs -c "dofile(\"$(MARKDOWNMAKER)\").genMarkdown([[$(dir $(mkfile_path))]])" > README.tmp.md

markdownWithTOC:
	hs -c "dofile(\"$(MARKDOWNMAKER)\").genMarkdown([[$(dir $(mkfile_path))]], true)" > README.tmp.md

release: clean all
	HS_APPLICATION=$(HS_APPLICATION) PREFIX=tmp make install-universal ; cd tmp ; tar -cf ../$(MODULE)-v$(VERSION).tar hs ; cd .. ; gzip $(MODULE)-v$(VERSION).tar

releaseWithDocs: clean all docs
	HS_APPLICATION=$(HS_APPLICATION) PREFIX=tmp make install-universal ; cd tmp ; tar -cf ../$(MODULE)-v$(VERSION).tar hs ; cd .. ; gzip $(MODULE)-v$(VERSION).tar

.PHONY: all clean verify install install-lua install-x86_64 install-arm64 install-universal docs markdown markdownWithTOC release releaseWithDocs
