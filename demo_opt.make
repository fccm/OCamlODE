GL_PATH="+glMLite"
DEMO=demo_buggy.ml

.PHONY: demo all
all: demo

ode.cmxa: ode.ml ode_c.c
	make ode.cmxa -f Makefile

drawstuff.cmxa: drawstuff.ml
	make \
	   drawstuff.cmxa \
	   -f drawstuff.make \
	   -e GL_PATH=$(GL_PATH)

demo: ode.cmxa  drawstuff.cmxa
	ocamlopt -ccopt -g \
	   -I $(GL_PATH) GL.cmxa Glu.cmxa Glut.cmxa \
	   -I . -cclib -l_mlode_stubs ode.cmxa drawstuff.cmxa \
	   $(DEMO) -o `basename $(DEMO) .ml`.opt

# vim: filetype=make
