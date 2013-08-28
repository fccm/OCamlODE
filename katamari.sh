ocamlopt.opt \
  bigarray.cmxa unix.cmxa \
  -I +site-lib/sdl sdl.cmxa \
  -I +site-lib/extlib extLib.cmxa \
  -I +lablGL lablgl.cmxa lablglut.cmxa \
  -I +ode -I ./ ode.cmxa \
  katamari.ml \
  -o katamari.opt
