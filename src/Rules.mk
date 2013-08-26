# Standard things which help keeping track of the current directory
# while include all Rules.mk.
d := $(if $(d),$(d)/,)$(mod)

# Useful directories, to be referenced from other Rules.ml
SRC_DIR := $(d)
PATOLINE_IN_SRC := $(d)/Patoline/patoline
PATOLINE_DIR := $(d)/Patoline
TYPOGRAPHY_DIR := $(d)/Typography
DRIVERS_DIR := $(d)/Drivers
FORMAT_DIR := $(d)/Format
RBUFFER_DIR := $(d)/Rbuffer
CESURE_DIR := $(d)/cesure

# Visit subdirectories
MODULES := Rbuffer Typography Drivers Patoline Pdf cesure Format \
  $(OCAML_BIBI) plot proof plugins
$(foreach mod,$(MODULES),$(eval include $(d)/$$(mod)/Rules.mk))

# Building Patoline's grammar
all: $(d)/DefaultGrammar.txp $(d)/DefaultGrammar.tgx
$(d)/DefaultGrammar.tgx: $(d)/DefaultGrammar.pdf

$(d)/quail.el: $(d)/DefaultGrammar.ttml ;
$(d)/DefaultGrammar_.tml: $(d)/DefaultGrammar.txp $(PATOLINE_IN_SRC)
	$(PATOLINE_IN_SRC) --main-ml --driver Pdf -o $@ $<

$(d)/DefaultGrammar.ttml: $(d)/DefaultGrammar.txp $(PATOLINE_IN_SRC)
	$(PATOLINE_IN_SRC) --ml --driver Pdf -o $@ $<

$(d)/DefaultGrammar.cmx: $(d)/DefaultGrammar.ttml $(TYPOGRAPHY_DIR)/Typography.cmxa $(FORMAT_DIR)/DefaultFormat.cmxa
	$(OCAMLOPT) $(PACK) -I $(FORMAT_DIR) -I $(TYPOGRAPHY_DIR) Typography.cmxa -c -o $@ -impl $<

$(d)/DefaultGrammar.tmx: $(d)/DefaultGrammar_.tml $(d)/DefaultGrammar.cmx \
  $(RBUFFER_DIR)/rbuffer.cmxa $(TYPOGRAPHY_DIR)/Typography.cmxa \
  $(DRIVERS_DIR)/Pdf/Pdf.cmxa $(FORMAT_DIR)/DefaultFormat.cmxa \
  $(TYPOGRAPHY_DIR)/ParseMainArgs.cmx
	$(ECHO) "[OPT]    $< -> $@"
	$(Q)$(OCAMLOPT) $(PACK) -I $(<D) -I $(RBUFFER_DIR) -I $(FORMAT_DIR) -I $(DRIVERS_DIR) -I $(TYPOGRAPHY_DIR) -I $(DRIVERS_DIR)/Pdf rbuffer.cmxa Typography.cmxa DefaultFormat.cmxa Pdf.cmxa -linkpkg -o $@ ParseMainArgs.cmx $(@:.tmx=.cmx) -impl $<

$(d)/DefaultGrammar.pdf: $(d)/DefaultGrammar.tmx $(PATOLINE_IN_SRC) $(HYPHENATION_DIR)/hyph-en-us.hdict
	$< --extra-fonts-dir $(FONTS_DIR) --extra-hyph-dir $(HYPHENATION_DIR)

CLEAN += $(d)/DefaultGrammar.tgx $(d)/DefaultGrammar_.tml $(d)/DefaultGrammar.ttml \
	 $(d)/DefaultGrammar.pdf $(d)/DefaultGrammar.tdx  $(d)/DefaultGrammar.tmx \
	 $(d)/DefaultGrammar.cmi $(d)/DefaultGrammar.cmx $(d)/DefaultGrammar.o \
	 $(d)/DefaultGrammar_.cmi $(d)/DefaultGrammar_.cmx $(d)/DefaultGrammar_.o \
	 $(d)/quail.el

# Installing
install: install-grammars
.PHONY: install-grammars

install-grammars: $(d)/DefaultGrammar.txp $(d)/DefaultGrammar.tgx
	install -p -m 755 -d $(DESTDIR)/$(INSTALL_GRAMMARS_DIR)
	install -p -m 644 $(SRC_DIR)/DefaultGrammar.txp $(DESTDIR)/$(INSTALL_GRAMMARS_DIR)/
	install -p -m 644 $(SRC_DIR)/DefaultGrammar.tgx $(DESTDIR)/$(INSTALL_GRAMMARS_DIR)/

# Rolling back changes made at the top
d := $(patsubst %/,%,$(dir $(d)))
