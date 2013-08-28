# OCaml bindings for the Open Dynamics Engine (ODE)
# By Richard W.M. Jones <rich@annexia.org>
# $Id: Makefile,v 1.2 2005/06/26 10:10:09 rich Exp $

PACKAGE := ocamlode
VERSION := 0.5-r2

OCAMLPACKAGES	:= sdl,unix,lablgl,lablgl.glut,extlib
OCAMLCFLAGS	:= -g
OCAMLOPTFLAGS	:=

OCAMLMKLIB	:= ocamlmklib
OCAMLDEP	:= ocamldep

EXTRA_CFLAGS := -O2

CC	:= gcc
CFLAGS	:= -g -fPIC -Wall -Wno-unused $(EXTRA_CFLAGS)
LIBODE	:= -lode

all: ocamlode.cma ocamlode.cmxa katamari.opt

ocamlode.cma: ode.cmo ode_c.o
	$(OCAMLMKLIB) -o ocamlode $(LIBODE) $^
ocamlode.cmxa: ode.cmx ode_c.o
	$(OCAMLMKLIB) -o ocamlode $(LIBODE) $^

katamari.opt: ocamlode.cmxa katamari.cmx
	ocamlfind ocamlopt $(OCAMLOPTFLAGS) \
	-package $(OCAMLPACKAGES) -cclib -L. -linkpkg $^ -o $@

# Build libraries and example with gprof profiling included.
profile: ocamlode_p.cmxa katamari_p.opt

ocamlode_p.cmxa: .profile/ode.cmx .profile/ode_c.o
	$(OCAMLMKLIB) -ccopt -p -ldopt -pg -o ocamlode_p $(LIBODE) $^
.profile/ode.cmx: ode.ml
	ocamlfind ocamlopt -p $(OCAMLOPTFLAGS) -package $(OCAMLPACKAGES) \
	-c $< -o $@
.profile/ode_c.o: ode_c.c
	$(CC) $(CFLAGS) -pg -c $< -o $@

katamari_p.opt: ocamlode_p.cmxa .profile/katamari.cmx
	ocamlfind ocamlopt -p $(OCAMLOPTFLAGS) \
	-package $(OCAMLPACKAGES) -cclib -L. -linkpkg $^ -o $@
.profile/katamari.cmx: katamari.ml
	ocamlfind ocamlopt -p $(OCAMLOPTFLAGS) -package $(OCAMLPACKAGES) \
	-c $< -o $@

# Make clean.

CLEANFILES := core *.bak *~ *.cmi *.cmo *.cma *.a *.o *.cmx *.cmxa *.so *.opt

clean:
	for d in . .profile; do (cd $$d; rm -f $(CLEANFILES)); done

# Standard rules.

%.cmi: %.mli
	ocamlfind ocamlc $(OCAMLCFLAGS) -package $(OCAMLPACKAGES) -c $<

%.cmo: %.ml
	ocamlfind ocamlc $(OCAMLCFLAGS) -package $(OCAMLPACKAGES) -c $<

%.cmx: %.ml
	ocamlfind ocamlopt $(OCAMLOPTFLAGS) -package $(OCAMLPACKAGES) -c $<

.SUFFIXES: .mli .ml .cmi .cmo .cmx

# Build dependencies.

ifeq ($(wildcard .depend),.depend)
include .depend
endif

depend: .depend

.depend: $(wildcard *.mli) $(wildcard *.ml)
	$(OCAMLDEP) $^ > .depend

# Distribution.

dist:
	$(MAKE) check-manifest
	rm -rf $(PACKAGE)-$(VERSION)
	mkdir $(PACKAGE)-$(VERSION)
	tar -cf - -T MANIFEST | tar -C $(PACKAGE)-$(VERSION) -xf -
	tar zcf $(PACKAGE)-$(VERSION).tar.gz $(PACKAGE)-$(VERSION)
	rm -rf $(PACKAGE)-$(VERSION)
	ls -l $(PACKAGE)-$(VERSION).tar.gz

check-manifest:
	@for d in `find -type d -name CVS | grep -v '^\./debian/'`; \
	do \
	b=`dirname $$d`/; \
	awk -F/ '$$1 != "D" {print $$2}' $$d/Entries | \
	sed -e "s|^|$$b|" -e "s|^\./||"; \
	done | sort > .check-manifest; \
	sort MANIFEST > .orig-manifest; \
	diff -u .orig-manifest .check-manifest; rv=$$?; \
	rm -f .orig-manifest .check-manifest; \
	exit $$rv

.PHONY: depend dist check-manifest
