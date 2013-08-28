# this file is not used, but kept in case it can be usefull

ODE_VER=`ode-config --version`.0.0.0
REGEX="\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*\).*"
ODE_MAJOR=`echo $ODE_VER | sed "s/$REGEX/\1/"`
ODE_MINOR=`echo $ODE_VER | sed "s/$REGEX/\2/"`
ODE_MICRO=`echo $ODE_VER | sed "s/$REGEX/\3/"`

MAJOR_VERSION="ODE_VERSION_MAJOR=$ODE_MAJOR"
MINOR_VERSION="ODE_VERSION_MINOR=$ODE_MINOR"
MICRO_VERSION="ODE_VERSION_MICRO=$ODE_MICRO"

echo "-D$MAJOR_VERSION -D$MINOR_VERSION -D$MICRO_VERSION"

