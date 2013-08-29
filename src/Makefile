# This file is a build script for the ocaml-ode bindings.
# Copyright (C) 2008 Florent Monnier
#
# This Makefile builds the ocaml-ode bindings.
#
# This Makefile is provided "AS-IS", without any express or implied warranty.
# In no event will the authors be held liable for any damages arising from
# the use of this software.
#
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely.

OCAMLC := ocamlc.opt
OCAMLOPT := ocamlopt.opt
OCAMLDOC := ocamldoc.opt

all: ode.cma ode.cmxa
all: ode.cma

.PHONY: all dist doc uninstall clean clean-doc

#ode_version.exe: ode_version.c 
#        # .exe for cygwin and mingw users
#	gcc $< -o $@
#ode_version.h: ode_version.exe
## if the version can't be parsed automaticaly, ask to the user
#	./$< > $@  ||  ocaml ask_version.ml $@

# another way to get ODE's version (maybe this one is more portable)
ODE_MAJOR := $(shell ocaml ode_version.ml -major)
ODE_MINOR := $(shell ocaml ode_version.ml -minor)
ODE_MICRO := $(shell ocaml ode_version.ml -micro)

MAJOR_VERSION := ODE_VERSION_MAJOR=$(ODE_MAJOR)
MINOR_VERSION := ODE_VERSION_MINOR=$(ODE_MINOR)
MICRO_VERSION := ODE_VERSION_MICRO=$(ODE_MICRO)

ode_c.o: ode_c.c 
#        ode_version.h
	$(OCAMLC) -c -pp 'cpp -D$(MAJOR_VERSION) -D$(MINOR_VERSION) -D$(MICRO_VERSION)' $<

# still another way to get the proper version macros
#	$(OCAMLC) -c -pp 'cpp $(shell sh ode_version.sh)' $<

dll_mlode_stubs.so: ode_c.o
	ocamlmklib -o  _mlode_stubs  $<  \
	    `ode-config --libs`

ode.mli: ode.ml
	$(OCAMLC) -i $< > $@

ode.cmi: ode.mli
	$(OCAMLC) -c $<

ode.cmo: ode.ml ode.cmi
	$(OCAMLC) -c $<

ode.cma:  ode.cmo  dll_mlode_stubs.so
	$(OCAMLC) -a  -custom  -o $@  $<  \
	    -dllib dll_mlode_stubs.so

ode.cmx: ode.ml ode.cmi
	$(OCAMLOPT) -c $<

ode.cmxa ode.a:  ode.cmx  dll_mlode_stubs.so
	$(OCAMLOPT) -a  -o $@  $<  \
	    -cclib -l_mlode_stubs \
	    -cclib "`ode-config --libs`"

doc: ode.ml ode.cmi
	if [ ! -d doc ]; then mkdir doc ; fi
	$(OCAMLDOC) -html -colorize-code -css-style _style.css -d doc $<
	cp _style.css doc/


clean:
	rm -f *.[oa] *.so *.cm[ixoa] *.cmxa *.opt *~

clean-doc:
	rm -f  doc/*.{html,css}
	rmdir  doc/

# install 

PREFIX = "`$(OCAMLC) -where`/ode"

DIST_FILES=\
    ode.cmi       \
    ode.cma       \
    ode.cmxa      \
    ode.cmx       \
    ode.a         \
    lib_mlode_stubs.a

SO_DIST_FILES=\
    dll_mlode_stubs.so


install: $(DIST_FILES)  $(SO_DIST_FILES)
	if [ ! -d $(PREFIX) ]; then install -d $(PREFIX) ; fi

	install -m 0755  \
	        $(SO_DIST_FILES)  \
	        $(PREFIX)/

	install -m 0644        \
	        $(DIST_FILES)  \
	        META           \
	        $(PREFIX)/

uninstall:
	rm -i  $(PREFIX)/*
	rmdir  $(PREFIX)/


# findlib install 

install_findlib:  $(DIST_FILES)  $(SO_DIST_FILES) META
	ocamlfind install ode $^

uninstall_findlib:  $(DIST_FILES)  $(SO_DIST_FILES) META
	ocamlfind remove ode

#EOF
