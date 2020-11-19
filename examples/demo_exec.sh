# allows to run this script from any directory
cd `dirname $0`


opam install glMLite

GL_PATH="$(ocamlfind query glMLite)"

ODE_PATH="../src"


# build the libraries
make ode.cma
make drawstuff.cma -f drawstuff.make -e GL_PATH="$GL_PATH"


# usage of the demos
echo "
      - use the mouse to rotate the camera
      - use arrows to move around (ex: up arrow to go forward)
      - use page up/down to go higher / lower
      - escape or 'q' key to quit
"

if [ $# == 0 ]
then  # without any argument this script executes all the demos
      DEMOS="demo_chain2.ml  demo_plane2d.ml  demo_buggy.ml  \
             demo_basket.ml  demo_friction.ml  demo_feedback.ml  \
	     demo_I.ml  demo_boxstack.ml"
else
      # otherwise executes only the requested demos
      DEMOS=$*
fi

for demo in $DEMOS
do    # executes the demos in interpreted mode
      echo "# running '$demo'"
      ocaml \
         -I "$GL_PATH" \
         -I "$ODE_PATH" \
         drawstuff.cma ode.cma \
         $demo
done

