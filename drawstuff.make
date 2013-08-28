GL_PATH="+glMLite"
#GL_PATH="/home/blue_prawn/Documents/prog/ocaml/GFX/glMLite/SRC"

.PHONY: all
all: drawstuff.cma

ode.cma:
	$(MAKE) ode.cma -f ./Makefile

drawstuff.cma: drawstuff.ml ode.cma
	ocamlc -a -o $@ \
	    -I $(GL_PATH) GL.cma Glu.cma Glut.cma \
	    ode.cma \
	    $<

# native code:
ode.cmxa:
	$(MAKE) ode.cmxa -f ./Makefile

GL.cmx Glu.cmx Glut.cmx:
	(cd $(GL_PATH); $(MAKE) GL.cmx Glu.cmx Glut.cmx)

drawstuff.cmxa: drawstuff.ml ode.cmxa \
                GL.cmx Glu.cmx Glut.cmx
	ocamlopt -a -o $@ \
	    -I $(GL_PATH) GL.cmx Glu.cmx Glut.cmx \
	    ode.cmx \
	    $<

# vim: filetype=make
