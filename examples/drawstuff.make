#GL_PATH="+glMLite"
GL_PATH="$(ocamlfind query glMLite)"

.PHONY: all opt
all: drawstuff.cma
opt: drawstuff.cmxa

drawstuff.cma: drawstuff.ml
	ocamlc -a -o $@ \
	    -I $(GL_PATH) GL.cma Glu.cma Glut.cma \
	    -I ../src ode.cma \
	    $<

drawstuff.cmxa: drawstuff.ml
	ocamlopt -a -o $@ \
	    -I $(GL_PATH) GL.cmx Glu.cmx Glut.cmx \
	    -I ../src ode.cmx \
	    $<

# vim: filetype=make
