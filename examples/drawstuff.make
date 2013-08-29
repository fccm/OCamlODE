GL_PATH="+glMLite"
#GL_PATH="/home/blue_prawn/Documents/prog/ocaml/GFX/glMLite/SRC"

.PHONY: all opt
all: drawstuff.cma
opt: drawstuff.cmxa

drawstuff.cma: drawstuff.ml
	ocamlc -a -o $@ \
	    -I $(GL_PATH) GL.cma Glu.cma Glut.cma \
	    -I ../src ode.cma \
	    $<

GL.cmx Glu.cmx Glut.cmx:
	(cd $(GL_PATH); $(MAKE) GL.cmx Glu.cmx Glut.cmx)

drawstuff.cmxa: drawstuff.ml
	ocamlopt -a -o $@ \
	    -I $(GL_PATH) GL.cmx Glu.cmx Glut.cmx \
	    -I ../src ode.cmx \
	    $<

# vim: filetype=make
