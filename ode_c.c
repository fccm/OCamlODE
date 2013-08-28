/* OCaml bindings for the Open Dynamics Engine (ODE).
 * By Richard W.M. Jones <rich@annexia.org>
 * $Id: ode_c.c,v 1.1 2005/06/24 18:15:29 rich Exp $
 */

#define CAML_NAME_SPACE 1

/* If set, we add some code which does some simple type checking.
 * This has a small amount of overhead.
 */
#define TYPE_CHECKING 1

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include <caml/alloc.h>
#include <caml/callback.h>
#include <caml/custom.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>
#include <caml/printexc.h>

#include <ode/ode.h>

struct voidptr {
  void *data;
};

static int
compare_voidptrs (value v1, value v2)
{
  CAMLparam2 (v1, v2);
  void *data1, *data2;
  data1 = ((struct voidptr *) Data_custom_val (v1))->data;
  data2 = ((struct voidptr *) Data_custom_val (v2))->data;
  CAMLreturn (data1 - data2);
}

static long
hash_voidptr (value v)
{
  CAMLparam1 (v);
  void *data;
  data = ((struct voidptr *) Data_custom_val (v))->data;
  CAMLreturn ((long) data);
}

static struct custom_operations custom_ops = {
  identifier: "ocamlode_voidptr",
  finalize: NULL,
  compare: compare_voidptrs,
  hash: hash_voidptr,
  serialize: custom_serialize_default,
  deserialize: custom_deserialize_default
};

/* Wrap up an arbitrary void pointer in an opaque OCaml object. */
static inline value
Val_voidptr (void *ptr)
{
  CAMLparam0 ();
  CAMLlocal1 (rv);
  rv = caml_alloc_custom (&custom_ops, sizeof (struct voidptr), 0, 1);
  ((struct voidptr *) Data_custom_val (rv))->data = ptr;
  CAMLreturn (rv);
}

/* Unwrap an arbitrary void pointer from an opaque OCaml object. */
static inline void *
_Voidptr_val (value rv)
{
  return ((struct voidptr *) Data_custom_val (rv))->data;
}
#define Voidptr_val(type,rv) ((type) _Voidptr_val ((rv)))

/* This function should be called whenever a C object which was wrapped
 * by a voidptr custom block is destroyed.  It annuls the data pointer,
 * causing future accidental references to cause an immediate and obvious
 * segfault.
 */
static inline void
destroy_voidptr (value rv)
{
  ((struct voidptr *) Data_custom_val (rv))->data = 0;
}

/* Hide ODE types in opaque OCaml objects. */
#define Val_dWorldID(id) (Val_voidptr ((id)))
#define dWorldID_val(idv) (Voidptr_val (dWorldID, (idv)))
#define Val_dBodyID(id) (Val_voidptr ((id)))
#define dBodyID_val(idv) (Voidptr_val (dBodyID, (idv)))
#define Val_dSpaceID(id) (Val_voidptr ((id)))
#define dSpaceID_val(idv) (Voidptr_val (dSpaceID, (idv)))
#define Val_dGeomID(id) (Val_voidptr ((id)))
#define dGeomID_val(idv) (Voidptr_val (dGeomID, (idv)))
#define Val_dJointGroupID(id) (Val_voidptr ((id)))
#define dJointGroupID_val(idv) (Voidptr_val (dJointGroupID, (idv)))
#define Val_dJointID(id) (Val_voidptr ((id)))
#define dJointID_val(idv) (Voidptr_val (dJointID, (idv)))

/* dMass objects are stored in specialised custom blocks. */
static struct custom_operations dMass_custom_ops = {
  identifier: "ocamlode_dMass",
  finalize: NULL,
  compare: custom_compare_default,
  hash: custom_hash_default,
  serialize: custom_serialize_default,
  deserialize: custom_deserialize_default
};

static inline value
copy_dMass (dMass *mass)
{
  CAMLparam0 ();
  CAMLlocal1 (massv);
  massv = caml_alloc_custom (&dMass_custom_ops, sizeof (dMass), 0, 1);
  memcpy (Data_custom_val (massv), mass, sizeof (dMass));
  CAMLreturn (massv);
}

static inline dMass *
dMass_data_custom_val (value massv)
{
  return (dMass *) Data_custom_val (massv);
}

/* Create a vector or matrix from an array of double. */
static value
copy_float_array (const double *a, int n)
{
  CAMLparam0 ();
  CAMLlocal1 (av);
  av = caml_alloc (n * Double_wosize, Double_array_tag);
  int i;
  for (i = 0; i < n; ++i)
    Store_double_field (av, i, a[i]);
  CAMLreturn (av);
}

/* Copy a dVector3 value to a C dVector3.  Note that despite the name this
 * structure actually contains 4 elements.
 */
static void
dVector3_val (value vv, dVector3 v)
{
  CAMLparam1 (vv);
  int i;
#if TYPE_CHECKING
  assert (Wosize_val (vv) == 4 * Double_wosize);
#endif
  for (i = 0; i < 4; ++i)
    v[i] = Double_field (vv, i);
  CAMLreturn0;
}

/* Create a dContactGeom OCaml record from C struct. */
static value
copy_dContactGeom (dContactGeom *c)
{
  CAMLparam0 ();
  CAMLlocal1 (cv);
  cv = caml_alloc (5, 0);
  caml_modify (&Field (cv, 0), copy_float_array (c->pos, 4));
  caml_modify (&Field (cv, 1), copy_float_array (c->normal, 4));
  caml_modify (&Field (cv, 2), caml_copy_double (c->depth));
  assert (c->g1);
  caml_modify (&Field (cv, 3), Val_dGeomID (c->g1));
  assert (c->g2);
  caml_modify (&Field (cv, 4), Val_dGeomID (c->g2));
  CAMLreturn (cv);
}

/* Create a dContactGeom C struct from an OCaml record. */
static void
dContactGeom_val (value geomv, dContactGeom *geom)
{
  CAMLparam1 (geomv);
  CAMLlocal2 (posv, normalv);
#if TYPE_CHECKING
  assert (Wosize_val (geomv) == 5);
#endif
  posv = Field (geomv, 0);
  dVector3_val (posv, geom->pos);
  normalv = Field (geomv, 1);
  dVector3_val (normalv, geom->normal);
  geom->depth = Double_val (Field (geomv, 2));
  geom->g1 = dGeomID_val (Field (geomv, 3));
  geom->g2 = dGeomID_val (Field (geomv, 4));
  CAMLreturn0;
}

static void
dContact_val (value contactv, dContact *contact)
{
  CAMLparam1 (contactv);
  CAMLlocal4 (surfacev, modev, geomv, fdir1v);

#if TYPE_CHECKING
  assert (Wosize_val (contactv) == 3);
#endif

  static int initialized = 0;
  static value hashdContactMu2, hashdContactFDir1, hashdContactBounce,
    hashdContactSoftERP, hashdContactSoftCFM, hashdContactMotion1,
    hashdContactMotion2, hashdContactSlip1, hashdContactSlip2,
    hashdContactApprox1_1, hashdContactApprox1_2, hashdContactApprox1;

  if (!initialized) {
    hashdContactMu2 = caml_hash_variant ("dContactMu2");
    hashdContactFDir1 = caml_hash_variant ("dContactFDir1");
    hashdContactBounce = caml_hash_variant ("dContactBounce");
    hashdContactSoftERP = caml_hash_variant ("dContactSoftERP");
    hashdContactSoftCFM = caml_hash_variant ("dContactSoftCFM");
    hashdContactMotion1 = caml_hash_variant ("dContactMotion1");
    hashdContactMotion2 = caml_hash_variant ("dContactMotion2");
    hashdContactSlip1 = caml_hash_variant ("dContactSlip1");
    hashdContactSlip2 = caml_hash_variant ("dContactSlip2");
    hashdContactApprox1_1 = caml_hash_variant ("dContactApprox1_1");
    hashdContactApprox1_2 = caml_hash_variant ("dContactApprox1_2");
    hashdContactApprox1 = caml_hash_variant ("dContactApprox1");
    initialized = 1;
  }

  surfacev = Field (contactv, 0);
#if TYPE_CHECKING
  assert (Wosize_val (surfacev) == 11);
#endif
  modev = Field (surfacev, 0);
  contact->surface.mode = 0;
  while (modev != Val_int (0))
    {
      value m = Field (modev, 0);
      if (m == hashdContactMu2)
	contact->surface.mode |= dContactMu2;
      else if (m == hashdContactFDir1)
	contact->surface.mode |= dContactFDir1;
      else if (m == hashdContactBounce)
	contact->surface.mode |= dContactBounce;
      else if (m == hashdContactSoftERP)
	contact->surface.mode |= dContactSoftERP;
      else if (m == hashdContactSoftCFM)
	contact->surface.mode |= dContactSoftCFM;
      else if (m == hashdContactMotion1)
	contact->surface.mode |= dContactMotion1;
      else if (m == hashdContactMotion2)
	contact->surface.mode |= dContactMotion2;
      else if (m == hashdContactSlip1)
	contact->surface.mode |= dContactSlip1;
      else if (m == hashdContactSlip2)
	contact->surface.mode |= dContactSlip2;
      else if (m == hashdContactApprox1_1)
	contact->surface.mode |= dContactApprox1_1;
      else if (m == hashdContactApprox1_2)
	contact->surface.mode |= dContactApprox1_2;
      else if (m == hashdContactApprox1)
	contact->surface.mode |= dContactApprox1;
      else abort ();
      modev = Field (modev, 1);
    }
  contact->surface.mu = Double_val (Field (surfacev, 1));
  contact->surface.mu2 = Double_val (Field (surfacev, 2));
  contact->surface.bounce = Double_val (Field (surfacev, 3));
  contact->surface.bounce_vel = Double_val (Field (surfacev, 4));
  contact->surface.soft_erp = Double_val (Field (surfacev, 5));
  contact->surface.soft_cfm = Double_val (Field (surfacev, 6));
  contact->surface.motion1 = Double_val (Field (surfacev, 7));
  contact->surface.motion2 = Double_val (Field (surfacev, 8));
  contact->surface.slip1 = Double_val (Field (surfacev, 9));
  contact->surface.slip2 = Double_val (Field (surfacev, 10));

  geomv = Field (contactv, 1);
  dContactGeom_val (geomv, &contact->geom);

  fdir1v = Field (contactv, 2);
  dVector3_val (fdir1v, contact->fdir1);

  CAMLreturn0;
}

static int
dJointParam_val (value paramv)
{
  CAMLparam1 (paramv);

#if TYPE_CHECKING
  assert (Is_long (paramv));
#endif

  int p;
  switch (Int_val (paramv))
    {
    case 0: p = dParamLoStop;
    case 1: p = dParamHiStop;
    case 2: p = dParamVel;
    case 3: p = dParamFMax;
    case 4: p = dParamFudgeFactor;
    case 5: p = dParamBounce;
    case 6: p = dParamCFM;
    case 7: p = dParamStopERP;
    case 8: p = dParamStopCFM;
    case 9: p = dParamSuspensionERP;
    case 10: p = dParamSuspensionCFM;
    default: abort ();
    }
  CAMLreturn (p);
}

CAMLprim value
ocamlode_dGetInfinity (value unit)
{
  CAMLparam1 (unit);
  CAMLreturn (caml_copy_double (dInfinity));
}

CAMLprim value
ocamlode_dWorldCreate (value unit)
{
  CAMLparam1 (unit);
  dWorldID id = dWorldCreate ();
  CAMLreturn (Val_dWorldID (id));
}

CAMLprim value
ocamlode_dWorldDestroy (value idv)
{
  CAMLparam1 (idv);
  dWorldID id = dWorldID_val (idv);
  dWorldDestroy (id);
  destroy_voidptr (idv);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dWorldSetGravity (value idv, value xv, value yv, value zv)
{
  CAMLparam4 (idv, xv, yv, zv);
  dWorldID id = dWorldID_val (idv);
  double x = Double_val (xv);
  double y = Double_val (yv);
  double z = Double_val (zv);
  dWorldSetGravity (id, x, y, z);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dCloseODE (value unit)
{
  CAMLparam1 (unit);
  dCloseODE ();
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dWorldStep (value idv, value stepsizev)
{
  CAMLparam2 (idv, stepsizev);
  dWorldID id = dWorldID_val (idv);
  float stepsize = Double_val (stepsizev);
  dWorldStep (id, stepsize);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dWorldQuickStep (value idv, value stepsizev)
{
  CAMLparam2 (idv, stepsizev);
  dWorldID id = dWorldID_val (idv);
  float stepsize = Double_val (stepsizev);
  dWorldQuickStep (id, stepsize);
  CAMLreturn (Val_unit);
}


/*
  external dWorldSetQuickStepNumIterations : dWorldID -> int -> unit = "ocamlode_dWorldSetQuickStepNumIterations"
  external dWorldGetQuickStepNumIterations : dWorldID -> int = "ocamlode_dWorldGetQuickStepNumIterations"
*/

CAMLprim value
ocamlode_dBodyCreate (value worldv)
{
  CAMLparam1 (worldv);
  dWorldID world = dWorldID_val (worldv);
  dBodyID id = dBodyCreate (world);
  CAMLreturn (Val_dBodyID (id));
}

CAMLprim value
ocamlode_dBodyDestroy (value idv)
{
  CAMLparam1 (idv);
  dBodyID id = dBodyID_val (idv);
  dBodyDestroy (id);
  destroy_voidptr (idv);
  CAMLreturn (Val_unit);
}

/*
  external dBodySetPosition : dBodyID -> x:float -> y:float -> z:float -> unit = "ocamlode_dBodySetPosition"
  external dBodySetRotation : dBodyID -> dMatrix3 -> unit = "ocamlode_dBodySetRotation"
  external dBodySetQuaternion : dBodyID -> dQuaternion -> unit = "ocamlode_dBodySetQuaternion"
  external dBodySetLinearVel : dBodyID -> x:float -> y:float -> z:float -> unit = "ocamlode_dBodySetLinearVel"
  external dBodySetAngularVel : dBodyID -> x:float -> y:float -> z:float -> unit = "ocamlode_dBodySetAngularVel"
*/

CAMLprim value
ocamlode_dBodyGetPosition (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  const double *r = dBodyGetPosition (id);
  rv = copy_float_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dBodyGetRotation (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  const double *r = dBodyGetRotation (id);
  rv = copy_float_array (r, 12);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dBodyGetQuaternion (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  const dReal *r = dBodyGetQuaternion (id);
  rv = copy_float_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dBodyGetLinearVel (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  const dReal *r = dBodyGetLinearVel (id);
  rv = copy_float_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dBodyGetAngularVel (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  const dReal *r = dBodyGetAngularVel (id);
  rv = copy_float_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dBodySetMass (value idv, value massv)
{
  CAMLparam2 (idv, massv);
  dBodyID id = dBodyID_val (idv);
  dBodySetMass (id, dMass_data_custom_val (massv));
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dBodyGetMass (value idv)
{
  CAMLparam1 (idv);
  dBodyID id = dBodyID_val (idv);
  dMass mass;
  dBodyGetMass (id, &mass);
  CAMLreturn (copy_dMass (&mass));
}

CAMLprim value
ocamlode_dBodyAddForce (value idv, value fxv, value fyv, value fzv)
{
  CAMLparam1 (idv);
  dBodyID id = dBodyID_val (idv);
  dReal fx = Double_val (fxv);
  dReal fy = Double_val (fyv);
  dReal fz = Double_val (fzv);
  dBodyAddForce (id, fx, fy, fz);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dBodyAddTorque (value idv, value fxv, value fyv, value fzv)
{
  CAMLparam1 (idv);
  dBodyID id = dBodyID_val (idv);
  dReal fx = Double_val (fxv);
  dReal fy = Double_val (fyv);
  dReal fz = Double_val (fzv);
  dBodyAddTorque (id, fx, fy, fz);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dBodyAddRelForce (value idv, value fxv, value fyv, value fzv)
{
  CAMLparam1 (idv);
  dBodyID id = dBodyID_val (idv);
  dReal fx = Double_val (fxv);
  dReal fy = Double_val (fyv);
  dReal fz = Double_val (fzv);
  dBodyAddRelForce (id, fx, fy, fz);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dBodyAddRelTorque (value idv, value fxv, value fyv, value fzv)
{
  CAMLparam1 (idv);
  dBodyID id = dBodyID_val (idv);
  dReal fx = Double_val (fxv);
  dReal fy = Double_val (fyv);
  dReal fz = Double_val (fzv);
  dBodyAddRelTorque (id, fx, fy, fz);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dBodyGetRelPointPos (value idv, value pxv, value pyv, value pzv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  dReal px = Double_val (pxv);
  dReal py = Double_val (pyv);
  dReal pz = Double_val (pzv);
  dVector3 r;
  dBodyGetRelPointPos (id, px, py, pz, r);
  rv = copy_float_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dBodyGetPosRelPoint (value idv, value pxv, value pyv, value pzv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  dReal px = Double_val (pxv);
  dReal py = Double_val (pyv);
  dReal pz = Double_val (pzv);
  dVector3 r;
  dBodyGetPosRelPoint (id, px, py, pz, r);
  rv = copy_float_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dBodyEnable (value idv)
{
  CAMLparam1 (idv);
  dBodyID id = dBodyID_val (idv);
  dBodyEnable (id);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dBodyDisable (value idv)
{
  CAMLparam1 (idv);
  dBodyID id = dBodyID_val (idv);
  dBodyDisable (id);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dBodyIsEnabled (value idv)
{
  CAMLparam1 (idv);
  dBodyID id = dBodyID_val (idv);
  int enabled = dBodyIsEnabled (id);
  CAMLreturn (Val_bool (enabled));
}

CAMLprim value
ocamlode_dBodySetAutoDisableFlag (value idv, value flagv)
{
  CAMLparam2 (idv, flagv);
  dBodyID id = dBodyID_val (idv);
  int flag = Bool_val (flagv);
  dBodySetAutoDisableFlag (id, flag);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dBodyGetAutoDisableFlag (value idv)
{
  CAMLparam1 (idv);
  dBodyID id = dBodyID_val (idv);
  int flag = dBodyGetAutoDisableFlag (id);
  CAMLreturn (Val_bool (flag));
}

CAMLprim value
ocamlode_dJointCreateBall (value worldv, value jointgroupv)
{
  CAMLparam2 (worldv, jointgroupv);
  dWorldID world = dWorldID_val (worldv);
  dJointGroupID jointgroup;
  if (jointgroupv == Val_int (0)) /* None */
    jointgroup = 0;
  else				/* Some jointgroup */
    jointgroup = dJointGroupID_val (Field (jointgroupv, 0));
  dJointID id = dJointCreateBall (world, jointgroup);
  CAMLreturn (Val_dJointID (id));
}

CAMLprim value
ocamlode_dJointCreateHinge (value worldv, value jointgroupv)
{
  CAMLparam2 (worldv, jointgroupv);
  dWorldID world = dWorldID_val (worldv);
  dJointGroupID jointgroup;
  if (jointgroupv == Val_int (0)) /* None */
    jointgroup = 0;
  else				/* Some jointgroup */
    jointgroup = dJointGroupID_val (Field (jointgroupv, 0));
  dJointID id = dJointCreateHinge (world, jointgroup);
  CAMLreturn (Val_dJointID (id));
}

CAMLprim value
ocamlode_dJointCreateSlider (value worldv, value jointgroupv)
{
  CAMLparam2 (worldv, jointgroupv);
  dWorldID world = dWorldID_val (worldv);
  dJointGroupID jointgroup;
  if (jointgroupv == Val_int (0)) /* None */
    jointgroup = 0;
  else				/* Some jointgroup */
    jointgroup = dJointGroupID_val (Field (jointgroupv, 0));
  dJointID id = dJointCreateSlider (world, jointgroup);
  CAMLreturn (Val_dJointID (id));
}

CAMLprim value
ocamlode_dJointCreateContact (value worldv, value jointgroupv, value contactv)
{
  CAMLparam3 (worldv, jointgroupv, contactv);
  dWorldID world = dWorldID_val (worldv);
  dJointGroupID jointgroup;
  if (jointgroupv == Val_int (0)) /* None */
    jointgroup = 0;
  else				/* Some jointgroup */
    jointgroup = dJointGroupID_val (Field (jointgroupv, 0));
  dContact contact;
  dContact_val (contactv, &contact);
  dJointID id = dJointCreateContact (world, jointgroup, &contact);
  CAMLreturn (Val_dJointID (id));
}

CAMLprim value
ocamlode_dJointCreateUniversal (value worldv, value jointgroupv)
{
  CAMLparam2 (worldv, jointgroupv);
  dWorldID world = dWorldID_val (worldv);
  dJointGroupID jointgroup;
  if (jointgroupv == Val_int (0)) /* None */
    jointgroup = 0;
  else				/* Some jointgroup */
    jointgroup = dJointGroupID_val (Field (jointgroupv, 0));
  dJointID id = dJointCreateUniversal (world, jointgroup);
  CAMLreturn (Val_dJointID (id));
}

CAMLprim value
ocamlode_dJointCreateHinge2 (value worldv, value jointgroupv)
{
  CAMLparam2 (worldv, jointgroupv);
  dWorldID world = dWorldID_val (worldv);
  dJointGroupID jointgroup;
  if (jointgroupv == Val_int (0)) /* None */
    jointgroup = 0;
  else				/* Some jointgroup */
    jointgroup = dJointGroupID_val (Field (jointgroupv, 0));
  dJointID id = dJointCreateHinge2 (world, jointgroup);
  CAMLreturn (Val_dJointID (id));
}

CAMLprim value
ocamlode_dJointCreateFixed (value worldv, value jointgroupv)
{
  CAMLparam2 (worldv, jointgroupv);
  dWorldID world = dWorldID_val (worldv);
  dJointGroupID jointgroup;
  if (jointgroupv == Val_int (0)) /* None */
    jointgroup = 0;
  else				/* Some jointgroup */
    jointgroup = dJointGroupID_val (Field (jointgroupv, 0));
  dJointID id = dJointCreateFixed (world, jointgroup);
  CAMLreturn (Val_dJointID (id));
}

CAMLprim value
ocamlode_dJointCreateAMotor (value worldv, value jointgroupv)
{
  CAMLparam2 (worldv, jointgroupv);
  dWorldID world = dWorldID_val (worldv);
  dJointGroupID jointgroup;
  if (jointgroupv == Val_int (0)) /* None */
    jointgroup = 0;
  else				/* Some jointgroup */
    jointgroup = dJointGroupID_val (Field (jointgroupv, 0));
  dJointID id = dJointCreateAMotor (world, jointgroup);
  CAMLreturn (Val_dJointID (id));
}

CAMLprim value
ocamlode_dJointDestroy (value idv)
{
  CAMLparam1 (idv);
  dJointID id = dJointID_val (idv);
  dJointDestroy (id);
  destroy_voidptr (idv);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dJointGroupCreate (value unit)
{
  CAMLparam1 (unit);
  dJointGroupID id = dJointGroupCreate (0);
  CAMLreturn (Val_dJointGroupID (id));
}

CAMLprim value
ocamlode_dJointGroupDestroy (value idv)
{
  CAMLparam1 (idv);
  dJointGroupID id = dJointGroupID_val (idv);
  dJointGroupDestroy (id);
  destroy_voidptr (idv);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dJointGroupEmpty (value idv)
{
  CAMLparam1 (idv);
  dJointGroupID id = dJointGroupID_val (idv);
  dJointGroupEmpty (id);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dJointAttach (value idv, value body1v, value body2v)
{
  CAMLparam3 (idv, body1v, body2v);
  dJointID id = dJointID_val (idv);
  dBodyID body1, body2;
  if (body1v == Val_int (0))	/* Get body1 option. */
    body1 = 0;
  else
    body1 = dBodyID_val (Field (body1v, 0));
  if (body2v == Val_int (0))	/* Get body2 option. */
    body2 = 0;
  else
    body2 = dBodyID_val (Field (body2v, 0));
  dJointAttach (id, body1, body2);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dJointSetSliderAxis (value idv, value xv, value yv, value zv)
{
  CAMLparam4 (idv, xv, yv, zv);
  dJointID id = dJointID_val (idv);
  dReal x = Double_val (xv);
  dReal y = Double_val (yv);
  dReal z = Double_val (zv);
  dJointSetSliderAxis (id, x, y, z);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dJointGetSliderAxis (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dJointID id = dJointID_val (idv);
  dVector3 r;
  dJointGetSliderAxis (id, r);
  rv = copy_float_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dJointGetSliderPosition (value idv)
{
  CAMLparam1 (idv);
  dJointID id = dJointID_val (idv);
  dReal r = dJointGetSliderPosition (id);
  CAMLreturn (caml_copy_double (r));
}

CAMLprim value
ocamlode_dJointGetSliderPositionRate (value idv)
{
  CAMLparam1 (idv);
  dJointID id = dJointID_val (idv);
  dReal r = dJointGetSliderPositionRate (id);
  CAMLreturn (caml_copy_double (r));
}

CAMLprim value
ocamlode_dJointSetHingeParam (value idv, value paramv, value vv)
{
  CAMLparam3 (idv, paramv, vv);
  dJointID id = dJointID_val (idv);
  int parameter = dJointParam_val (paramv);
  dReal v = Double_val (vv);
  dJointSetHingeParam (id, parameter, v);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dJointSetSliderParam (value idv, value paramv, value vv)
{
  CAMLparam3 (idv, paramv, vv);
  dJointID id = dJointID_val (idv);
  int parameter = dJointParam_val (paramv);
  dReal v = Double_val (vv);
  dJointSetSliderParam (id, parameter, v);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dJointSetHinge2Param (value idv, value paramv, value vv)
{
  CAMLparam3 (idv, paramv, vv);
  dJointID id = dJointID_val (idv);
  int parameter = dJointParam_val (paramv);
  dReal v = Double_val (vv);
  dJointSetHinge2Param (id, parameter, v);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dJointSetUniversalParam (value idv, value paramv, value vv)
{
  CAMLparam3 (idv, paramv, vv);
  dJointID id = dJointID_val (idv);
  int parameter = dJointParam_val (paramv);
  dReal v = Double_val (vv);
  dJointSetUniversalParam (id, parameter, v);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dJointSetAMotorParam (value idv, value paramv, value vv)
{
  CAMLparam3 (idv, paramv, vv);
  dJointID id = dJointID_val (idv);
  int parameter = dJointParam_val (paramv);
  dReal v = Double_val (vv);
  dJointSetAMotorParam (id, parameter, v);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dJointGetHingeParam (value idv, value paramv)
{
  CAMLparam2 (idv, paramv);
  dJointID id = dJointID_val (idv);
  int parameter = dJointParam_val (paramv);
  dReal r = dJointGetHingeParam (id, parameter);
  CAMLreturn (caml_copy_double (r));
}

CAMLprim value
ocamlode_dJointGetSliderParam (value idv, value paramv)
{
  CAMLparam2 (idv, paramv);
  dJointID id = dJointID_val (idv);
  int parameter = dJointParam_val (paramv);
  dReal r = dJointGetSliderParam (id, parameter);
  CAMLreturn (caml_copy_double (r));
}

CAMLprim value
ocamlode_dJointGetHinge2Param (value idv, value paramv)
{
  CAMLparam2 (idv, paramv);
  dJointID id = dJointID_val (idv);
  int parameter = dJointParam_val (paramv);
  dReal r = dJointGetHinge2Param (id, parameter);
  CAMLreturn (caml_copy_double (r));
}

CAMLprim value
ocamlode_dJointGetUniversalParam (value idv, value paramv)
{
  CAMLparam2 (idv, paramv);
  dJointID id = dJointID_val (idv);
  int parameter = dJointParam_val (paramv);
  dReal r = dJointGetUniversalParam (id, parameter);
  CAMLreturn (caml_copy_double (r));
}

CAMLprim value
ocamlode_dJointGetAMotorParam (value idv, value paramv)
{
  CAMLparam2 (idv, paramv);
  dJointID id = dJointID_val (idv);
  int parameter = dJointParam_val (paramv);
  dReal r = dJointGetAMotorParam (id, parameter);
  CAMLreturn (caml_copy_double (r));
}

CAMLprim value
ocamlode_dGeomDestroy (value idv)
{
  CAMLparam1 (idv);
  dGeomID id = dGeomID_val (idv);
  dGeomDestroy (id);
  destroy_voidptr (idv);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dGeomSetBody (value idv, value bodyv)
{
  CAMLparam2 (idv, bodyv);
  dGeomID id = dGeomID_val (idv);
  dBodyID body;
  if (bodyv == Val_int (0))	/* None */
    body = 0;
  else
    body = dBodyID_val (Field (bodyv, 0));
  dGeomSetBody (id, body);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dGeomGetBody (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (bodyv);
  dGeomID id = dGeomID_val (idv);
  dBodyID body = dGeomGetBody (id);
  if (body) {			/* Some body */
    bodyv = caml_alloc (1, 0);
    caml_modify (&Field (bodyv, 0), Val_dBodyID (body));
  } else
    caml_modify (&bodyv, Val_int (0));	/* None */
  CAMLreturn (bodyv);
}

CAMLprim value
ocamlode_dGeomSetPosition (value idv, value xv, value yv, value zv)
{
  CAMLparam4 (idv, xv, yv, zv);
  dGeomID id = dGeomID_val (idv);
  double x = Double_val (xv);
  double y = Double_val (yv);
  double z = Double_val (zv);
  dGeomSetPosition (id, x, y, z);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dGeomSetRotation (value idv, value matrixv)
{
  CAMLparam2 (idv, matrixv);
  dGeomID id = dGeomID_val (idv);
  dGeomSetRotation (id, (double *) matrixv);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dGeomSetQuaternion (value idv, value quaternionv)
{
  CAMLparam2 (idv, quaternionv);
  dGeomID id = dGeomID_val (idv);
  dGeomSetQuaternion (id, (double *) quaternionv);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dGeomGetPosition (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dGeomID id = dGeomID_val (idv);
  const double *r = dGeomGetPosition (id);
  rv = copy_float_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dGeomGetRotation (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dGeomID id = dGeomID_val (idv);
  const double *r = dGeomGetRotation (id);
  rv = copy_float_array (r, 12);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dGeomGetQuaternion (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dGeomID id = dGeomID_val (idv);
  dQuaternion r;
  dGeomGetQuaternion (id, r);
  rv = copy_float_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dCollide (value geom1v, value geom2v, value maxv)
{
  CAMLparam3 (geom1v, geom2v, maxv);
  CAMLlocal1 (contactsv);
  dGeomID geom1 = dGeomID_val (geom1v);
  dGeomID geom2 = dGeomID_val (geom2v);
  int max = Int_val (maxv);
  unsigned flags = ((unsigned) max) & 0xffff;
  dContactGeom contacts[max];
  int n = dCollide (geom1, geom2, flags, contacts, sizeof (dContactGeom));
  contactsv = caml_alloc (n, 0);
  int i;
  for (i = 0; i < n; ++i)
    caml_modify (&Field (contactsv, i), copy_dContactGeom (&contacts[i]));
  CAMLreturn (contactsv);
}

static void
dSpaceCollide_callback (void *fvpv, dGeomID geom1, dGeomID geom2)
{
  CAMLparam0 ();
  CAMLlocal4 (fv, geom1v, geom2v, rv);
  value *fvp = (value *) fvpv;
  assert (geom1 != geom2);
  geom1v = Val_dGeomID (geom1);
  geom2v = Val_dGeomID (geom2);
  rv = caml_callback2_exn (*fvp, geom1v, geom2v);
  if (Is_exception_result (rv))
    // XXX Can we do better than this?
    fprintf (stderr, "dSpaceCollide: callback raised exception: %s\n",
	     caml_format_exception (Extract_exception (rv)));
  CAMLreturn0;
}

CAMLprim value
ocamlode_dSpaceCollide (value idv, value fv)
{
  CAMLparam2 (idv, fv);
  value *fvp = &fv;
  dSpaceID id = dSpaceID_val (idv);
  dSpaceCollide (id, fvp, dSpaceCollide_callback);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dSimpleSpaceCreate (value parentv)
{
  CAMLparam1 (parentv);
  dSpaceID parent;
  if (parentv == Val_int (0))	/* None */
    parent = 0;
  else				/* Some parent */
    parent = dSpaceID_val (Field (parentv, 0));
  dSpaceID id = dSimpleSpaceCreate (parent);
  CAMLreturn (Val_dSpaceID (id));
}

CAMLprim value
ocamlode_dHashSpaceCreate (value parentv)
{
  CAMLparam1 (parentv);
  dSpaceID parent;
  if (parentv == Val_int (0))	/* None */
    parent = 0;
  else				/* Some parent */
    parent = dSpaceID_val (Field (parentv, 0));
  dSpaceID id = dHashSpaceCreate (parent);
  CAMLreturn (Val_dSpaceID (id));
}

CAMLprim value
ocamlode_dQuadTreeSpaceCreate (value parentv,
			       value centerv, value extentsv, value depthv)
{
  CAMLparam1 (parentv);
  dSpaceID parent;
  if (parentv == Val_int (0))	/* None */
    parent = 0;
  else				/* Some parent */
    parent = dSpaceID_val (Field (parentv, 0));
  dVector3 center, extents;
  dVector3_val (centerv, center);
  dVector3_val (extentsv, extents);
  int depth = Int_val (depthv);
  dSpaceID id = dQuadTreeSpaceCreate (parent, center, extents, depth);
  CAMLreturn (Val_dSpaceID (id));
}

CAMLprim value
ocamlode_dSpaceDestroy (value idv)
{
  CAMLparam1 (idv);
  dSpaceID id = dSpaceID_val (idv);
  dSpaceDestroy (id);
  destroy_voidptr (idv);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dHashSpaceSetLevels (value idv, value minlevelv, value maxlevelv)
{
  CAMLparam3 (idv, minlevelv, maxlevelv);
  dSpaceID id = dSpaceID_val (idv);
  int minlevel = Int_val (minlevelv);
  int maxlevel = Int_val (maxlevelv);
  dHashSpaceSetLevels (id, minlevel, maxlevel);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dHashSpaceGetLevels (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dSpaceID id = dSpaceID_val (idv);
  int minlevel, maxlevel;
  dHashSpaceGetLevels (id, &minlevel, &maxlevel);
  rv = caml_alloc (2, 0);
  caml_modify (&Field (rv, 0), Val_int (minlevel));
  caml_modify (&Field (rv, 1), Val_int (maxlevel));
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dSpaceAdd (value idv, value geomv)
{
  CAMLparam2 (idv, geomv);
  dSpaceID id = dSpaceID_val (idv);
  dGeomID geom = dGeomID_val (geomv);
  dSpaceAdd (id, geom);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dSpaceRemove (value idv, value geomv)
{
  CAMLparam2 (idv, geomv);
  dSpaceID id = dSpaceID_val (idv);
  dGeomID geom = dGeomID_val (geomv);
  dSpaceRemove (id, geom);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dCreateSphere (value parentv, value radiusv)
{
  CAMLparam2 (parentv, radiusv);
  dSpaceID parent;
  if (parentv == Val_int (0))	/* None */
    parent = 0;
  else				/* Some parent */
    parent = dSpaceID_val (Field (parentv, 0));
  double radius = Double_val (radiusv);
  dGeomID id = dCreateSphere (parent, radius);
  CAMLreturn (Val_dGeomID (id));
}

CAMLprim value
ocamlode_dGeomSphereGetRadius (value idv)
{
  CAMLparam1 (idv);
  dGeomID id = dGeomID_val (idv);
  double radius = dGeomSphereGetRadius (id);
  CAMLreturn (caml_copy_double (radius));
}

CAMLprim value
ocamlode_dCreateBox (value parentv, value lxv, value lyv, value lzv)
{
  CAMLparam4 (parentv, lxv, lyv, lzv);
  dSpaceID parent;
  if (parentv == Val_int (0))	/* None */
    parent = 0;
  else				/* Some parent */
    parent = dSpaceID_val (Field (parentv, 0));
  double lx = Double_val (lxv);
  double ly = Double_val (lyv);
  double lz = Double_val (lzv);
  dGeomID id = dCreateBox (parent, lx, ly, lz);
  CAMLreturn (Val_dGeomID (id));
}

CAMLprim value
ocamlode_dGeomBoxGetLengths (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dGeomID id = dGeomID_val (idv);
  dVector3 r;
  dGeomBoxGetLengths (id, r);
  rv = copy_float_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dCreatePlane (value parentv, value av, value bv, value cv, value dv)
{
  CAMLparam5 (parentv, av, bv, cv, dv);
  dSpaceID parent;
  if (parentv == Val_int (0))	/* None */
    parent = 0;
  else				/* Some parent */
    parent = dSpaceID_val (Field (parentv, 0));
  double a = Double_val (av);
  double b = Double_val (bv);
  double c = Double_val (cv);
  double d = Double_val (dv);
  dGeomID id = dCreatePlane (parent, a, b, c, d);
  CAMLreturn (Val_dGeomID (id));
}

CAMLprim value
ocamlode_dCreateGeomTransform (value parentv)
{
  CAMLparam1 (parentv);
  dSpaceID parent;
  if (parentv == Val_int (0))	/* None */
    parent = 0;
  else				/* Some parent */
    parent = dSpaceID_val (Field (parentv, 0));
  dGeomID id = dCreateGeomTransform (parent);
  CAMLreturn (Val_dGeomID (id));
}

CAMLprim value
ocamlode_dGeomTransformSetGeom (value idv, value geomv)
{
  CAMLparam2 (idv, geomv);
  dGeomID id = dGeomID_val (idv);
  dGeomID geom;
  if (geomv == Val_int (0))
    geom = 0;
  else
    geom = dGeomID_val (Field (geomv, 0));
  dGeomTransformSetGeom (id, geom);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dGeomTransformGetGeom (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (geomv);
  dGeomID id = dGeomID_val (idv);
  dGeomID geom = dGeomTransformGetGeom (id);
  if (geom) {			/* Some geom */
    geomv = caml_alloc (1, 0);
    caml_modify (&Field (geomv, 0), Val_dGeomID (geom));
  } else
    caml_modify (&geomv, Val_int (0)); /* None */
  CAMLreturn (geomv);
}

CAMLprim value
ocamlode_dMassCreate (value unit)
{
  CAMLparam1 (unit);
  dMass mass;
  CAMLreturn (copy_dMass (&mass));
}

/*
  external dMass_set_mass : dMass -> float -> unit = "ocamlode_dMass_set_mass"
*/

CAMLprim value
ocamlode_dMass_mass (value massv)
{
  CAMLparam1 (massv);
  CAMLreturn (caml_copy_double (dMass_data_custom_val (massv)->mass));
}

/*
  external dMass_set_c : dMass -> dVector4 -> unit = "ocamlode_dMass_set_c"
  external dMass_c : dMass -> dVector4 = "ocamlode_dMass_c"
  external dMass_set_I : dMass -> dMatrix3 -> unit = "ocamlode_dMass_set_I"
  external dMass_I : dMass -> dMatrix3 = "ocamlode_dMass_I"
*/

CAMLprim value
ocamlode_dMassSetZero (value massv)
{
  CAMLparam1 (massv);
  dMassSetZero (dMass_data_custom_val (massv));
  CAMLreturn (Val_unit);
}

/*
  external dMassSetParameters : dMass -> mass:float -> cgx:float -> cgy:float -> cgz:float -> i11:float -> i22:float -> i33:float -> i12:float -> i13:float -> i23:float -> unit = "ocamlode_dMassSetParameters_bc" "ocamlode_dMassSetParameters"
*/

CAMLprim value
ocamlode_dMassSetSphere (value massv, value densityv, value radiusv)
{
  CAMLparam3 (massv, densityv, radiusv);
  double density = Double_val (densityv);
  double radius = Double_val (radiusv);
  dMassSetSphere (dMass_data_custom_val (massv), density, radius);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassSetSphereTotal (value massv, value total_massv, value radiusv)
{
  CAMLparam3 (massv, total_massv, radiusv);
  double total_mass = Double_val (total_massv);
  double radius = Double_val (radiusv);
  dMassSetSphereTotal (dMass_data_custom_val (massv), total_mass, radius);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassSetBox (value massv, value densityv, value lxv, value lyv, value lzv)
{
  CAMLparam5 (massv, densityv, lxv, lyv, lzv);
  double density = Double_val (densityv);
  double lx = Double_val (lxv);
  double ly = Double_val (lyv);
  double lz = Double_val (lzv);
  dMassSetBox (dMass_data_custom_val (massv), density, lx, ly, lz);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassSetBoxTotal (value massv, value total_massv, value lxv, value lyv, value lzv)
{
  CAMLparam5 (massv, total_massv, lxv, lyv, lzv);
  double total_mass = Double_val (total_massv);
  double lx = Double_val (lxv);
  double ly = Double_val (lyv);
  double lz = Double_val (lzv);
  dMassSetBoxTotal (dMass_data_custom_val (massv), total_mass, lx, ly, lz);
  CAMLreturn (Val_unit);
}


CAMLprim value
ocamlode_dMassAdjust (value massv, value newmassv)
{
  CAMLparam2 (massv, newmassv);
  double newmass = Double_val (newmassv);
  dMassAdjust (dMass_data_custom_val (massv), newmass);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassTranslate (value massv, value xv, value yv, value zv)
{
  CAMLparam4 (massv, xv, yv, zv);
  double x = Double_val (xv);
  double y = Double_val (yv);
  double z = Double_val (zv);
  dMassTranslate (dMass_data_custom_val (massv), x, y, z);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassRotate (value massv, value rv)
{
  CAMLparam2 (massv, rv);
  dMassRotate (dMass_data_custom_val (massv), (void *) rv);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassAdd (value mass1v, value mass2v)
{
  CAMLparam2 (mass1v, mass2v);
  dMassAdd (dMass_data_custom_val (mass1v), dMass_data_custom_val (mass2v));
  CAMLreturn (Val_unit);
}
