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

all:

.PHONY: all demo clean

DEMO = katamari

demo: $(DEMO)
$(DEMO): $(DEMO).ml ode.cmxa
	$(OCAMLOPT) -I ../src ode.cmxa $< -o $@

clean:
	$(RM) *.[oa] *.so *.cm[ixoa] *.cmxa *.opt *~

#EOF
