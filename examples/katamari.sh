opam install extlib
opam install ocamlsdl
opam install lablgl

# -I $(ocamlfind query ode)

ocamlopt.opt \
  bigarray.cmxa unix.cmxa \
  -I $(ocamlfind query sdl) sdl.cmxa \
  -I $(ocamlfind query extlib) extLib.cmxa \
  -I $(ocamlfind query lablgl) lablgl.cmxa lablglut.cmxa \
  -I ../src ode.cmxa \
  katamari.ml \
  -o katamari.opt
