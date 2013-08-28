OCaml bindings for the Open Dynamics Engine (ODE).
Copyright (C) 2005 Richard W.M. Jones <rich@annexia.org>
Copyright (C) 2008 Florent Monnier
Current Maintainer : Florent Monnier <fmonnier@linux-nantes.org>

This is a set of bindings in OCaml for the Open Dynamics Engine (ODE;
http://www.ode.org/).

License
-------

This library is distributed under the GNU Library General Public
License with the special OCaml linking exception.
The Katamari like game is licensed under the GNU GPL.
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

There is no support for attaching arbitrary data to objects (as is
supported by ODE).  There are two reasons for this.  Firstly it would
be unsafe if allowed generally.  Consider the case where you add a
type t1 to an object, but then fetch it as type t2.  It is possible to
work around this in the type system, but only if every type of object
has the same, fixed extension type.  This would be quite limiting.
Secondly it leads to a memory leak.  Consider the case where you
attach an object to a geom contained within a space.  To implement
this you have to call caml_register_global_root on the attached
object.  When the space is freed, the geom gets freed too.  However
there is no way to catch the cleanup and unregister the global root.
Leaked global roots have a serious impact on performance too.

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
