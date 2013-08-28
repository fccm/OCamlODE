ocamlopt.opt \
  bigarray.cmxa unix.cmxa \
  -I +sdl sdl.cmxa \
  -I +extlib extLib.cmxa \
  -I +lablGL lablgl.cmxa lablglut.cmxa \
  -I +ode -I ./ ode.cmxa \
  katamari.ml \
  -o katamari.opt
