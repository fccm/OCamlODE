OCaml bindings for the Open Dynamics Engine (ODE).
Copyright (C) 2005 Richard W.M. Jones
Copyright (C) 2008 Florent Monnier
Current Maintainer: Florent Monnier
For contact informations run: `ocaml contact.ml`

This is a set of bindings in OCaml for the Open Dynamics Engine (ODE;
http://www.ode.org/).

License
-------

This library is distributed under the Zlib License.
http://opensource.org/licenses/Zlib

Most of the demos that come from the ODE sources can be used either
along the terms of the GNU LGPL or the BSD license.

Impatients
----------

For impatients, just run the script demo_exec.sh, it will compile
everything and will execute the demos.

Notes on the style of bindings
------------------------------

The bindings are currently quite literal.  Most ODE functions are
mapped literally into OCaml.  There is no attempt to use special
features of OCaml, particularly garbage collection, so you must
destroy ODE objects by hand.  It is intended that someone would write
a pleasant modular / object-oriented wrapper around these basic
bindings which would use finalisers to support garbage collection.

The bindings can adapt itself to an ODE library compiled with dDOUBLE
or dSINGLE. But if you compile with dDOUBLE, there is opportunity to
use OCaml structures which are binary-compatible with ODE structures,
which speeds datas exchange.

Debugging
---------

If it crashes (and it may well do so), try turning on type checking
('#define TYPE_CHECKING 1' at the top of ode_c.c).

Make sure that the '-g' flag is being passed in $(CFLAGS), and for
additional safety, make sure optimisation ('-O...') is turned off.

Run the program under gdb and get a stack trace.

Speed
-----

Build the profile target ('make profile') and try running the example
game ('katamari_p.opt').

To view the profile, do 'gprof katamari_p.opt'.
