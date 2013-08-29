/* OCaml bindings for the Open Dynamics Engine (ODE).
 * Originally written by Richard W.M. Jones
 * Maintained by: Florent Monnier
 */
/* This file is part of the ocaml-ode bindings.
 *
 * This software is provided "AS-IS", without any express or implied warranty.
 * In no event will the authors be held liable for any damages arising from
 * the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely.
 */

/* If set, we add some code which does some simple type checking.
 * This has a small amount of overhead.
 */
#define TYPE_CHECKING 1

/* {{{ Headers */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#define CAML_NAME_SPACE 1

#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/callback.h>
#include <caml/custom.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/printexc.h>

/* usable generated macro for versioning */
//#include "ode_version.h"

/* dirty hack to work around that both ocaml and ode define int32 type */
#define int32 _int32
#define uint32 _uint32

#include <ode/ode.h>

#undef int32
#undef uint32

/* }}} */

/* NOTE: Some OCaml structures are binary-compatible with the ODE definitions,
   provided that the ODE library was compiled with dDOUBLE.
   Otherwise the OCaml datas are copied to the appropriate C type.

   Please notice that the risk of a bug is higher while sharing memory
   between OCaml and C, so you may be willing to set MEM_CPY even if you
   have compiled ODE with --enable-double-precision if you wish the safer code.
*/
#if defined(dDOUBLE)
  #define MEM_SHARE
#else
  #define MEM_CPY
#endif

/* {{{ Types convertions */

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

#define Val_dTriMeshDataID(id) (Val_voidptr ((id)))
#define dTriMeshDataID_val(idv) (Voidptr_val (dTriMeshDataID, (idv)))


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
_dMass_data_custom_val (const value massv)
{
  return (dMass *) Data_custom_val (massv);
}

#define dMass_data_custom_val(massv) \
  ((dMass *) Data_custom_val (massv))


/* Create a vector or matrix from an array of dReal. */
static value
copy_dReal_array (const dReal *a, int n)
{
  CAMLparam0 ();
  CAMLlocal1 (av);
  av = caml_alloc (n * Double_wosize, Double_array_tag);
#if defined(MEM_CPY) // dSINGLE
  int i;
  for (i = 0; i < n; ++i)
    Store_double_field (av, i, a[i]);
#else // dDOUBLE
  memcpy ((void *)av, a, n * sizeof (dReal));
#endif
  CAMLreturn (av);
}

#define copy_dVector4(v)  (copy_dReal_array(v, 4))
#define copy_dVector3(v)  (copy_dReal_array(v, 4))
#define copy_dMatrix3(m)  (copy_dReal_array(m, 4*3))
#define copy_dQuaternion(v)  (copy_dReal_array(v, 4))


#if defined(MEM_CPY) // dSINGLE
  #define  dMatrix3_val(rv,r) \
    {int i; \
      for (i=0; i<12; ++i) r[i] = Double_field(rv,i); \
    }
#else // dDOUBLE
  #define  dMatrix3_val(rv,r) \
    memcpy (r, (void *)rv, sizeof (dMatrix3));
#endif


/* Copy a dVector3 value to a C dVector3.  Note that despite the name this
 * structure actually contains 4 elements.
 */
static void
dVector3_val (value vv, dVector3 v)
{
  CAMLparam1 (vv);
#if TYPE_CHECKING
  assert (Wosize_val (vv) == 4 * Double_wosize);
#endif
#if defined(MEM_CPY) // dSINGLE
  int i;
  for (i = 0; i < 4; ++i)
    v[i] = Double_field (vv, i);
#else // dDOUBLE
  memcpy (v, (double *) vv, 4 * sizeof (dReal));
#endif
  CAMLreturn0;
}

#define dVector4_val dVector3_val
#define dQuaternion_val dVector3_val

/* Create a dContactGeom OCaml record from C struct. */
static value
copy_dContactGeom (dContactGeom *c)
{
  CAMLparam0 ();
  CAMLlocal1 (cv);
  cv = caml_alloc (5, 0);
  caml_modify (&Field (cv, 0), copy_dReal_array (c->pos, 4));
  caml_modify (&Field (cv, 1), copy_dReal_array (c->normal, 4));
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
  if (Wosize_val (geomv) != 5)
    printf ("Wosize_val (geomv) = %ld\n", Wosize_val (geomv));
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
  static int hashdContactMu2, hashdContactFDir1, hashdContactBounce,
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
    //hashdContactApprox0 = caml_hash_variant ("dContactApprox0");
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
      int m = Field (modev, 0);
      /*
      switch (m)
        {
        case hashdContactMu2:       contact->surface.mode |= dContactMu2; break;
        case hashdContactFDir1:     contact->surface.mode |= dContactFDir1; break;
        case hashdContactBounce:    contact->surface.mode |= dContactBounce; break;
        case hashdContactSoftERP:   contact->surface.mode |= dContactSoftERP; break;
        case hashdContactSoftCFM:   contact->surface.mode |= dContactSoftCFM; break;
        case hashdContactMotion1:   contact->surface.mode |= dContactMotion1; break;
        case hashdContactMotion2:   contact->surface.mode |= dContactMotion2; break;
        case hashdContactSlip1:     contact->surface.mode |= dContactSlip1; break;
        case hashdContactSlip2:     contact->surface.mode |= dContactSlip2; break;
        //case hashdContactApprox0:   contact->surface.mode |= dContactApprox0; break;
        case hashdContactApprox1_1: contact->surface.mode |= dContactApprox1_1; break;
        case hashdContactApprox1_2: contact->surface.mode |= dContactApprox1_2; break;
        case hashdContactApprox1:   contact->surface.mode |= dContactApprox1; break;
        default: abort ();
        }
      */
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

static const int joint_param_table[] = {
  dParamLoStop,
  dParamHiStop,
  dParamVel,
  dParamFMax,
  dParamFudgeFactor,
  dParamBounce,
  dParamCFM,
  dParamStopERP,
  dParamStopCFM,
  dParamSuspensionERP,
  dParamSuspensionCFM,
  dParamERP,

  dParamLoStop2,
  dParamHiStop2,
  dParamVel2,
  dParamFMax2,
  dParamFudgeFactor2,
  dParamBounce2,
  dParamCFM2,
  dParamStopERP2,
  dParamStopCFM2,
  dParamSuspensionERP2,
  dParamSuspensionCFM2,
  dParamERP2,

  dParamLoStop3,
  dParamHiStop3,
  dParamVel3,
  dParamFMax3,
  dParamFudgeFactor3,
  dParamBounce3,
  dParamCFM3,
  dParamStopERP3,
  dParamStopCFM3,
  dParamSuspensionERP3,
  dParamSuspensionCFM3,
  dParamERP3,

  dParamGroup
};

static inline int
dJointParam_val (value paramv)
{
  return joint_param_table[Long_val(paramv)];
}

#define Val_dGeomClass(ret, geom_class) \
  switch (geom_class) \
  { \
    case dSphereClass:        ret = Val_int(0); break;  \
    case dBoxClass:           ret = Val_int(1); break;  \
    case dCapsuleClass:       ret = Val_int(2); break;  \
    case dCylinderClass:      ret = Val_int(3); break;  \
    case dPlaneClass:         ret = Val_int(4); break;  \
    case dRayClass:           ret = Val_int(5); break;  \
    case dConvexClass:        ret = Val_int(6); break;  \
    case dGeomTransformClass: ret = Val_int(7); break;  \
    case dTriMeshClass:       ret = Val_int(8); break;  \
    case dHeightfieldClass:   ret = Val_int(9); break;  \
    case dSimpleSpaceClass:   ret = Val_int(10); break; \
    case dHashSpaceClass:     ret = Val_int(11); break; \
    case dQuadTreeSpaceClass: ret = Val_int(12); break; \
    case dFirstUserClass:     ret = Val_int(13); break; \
    case dLastUserClass:      ret = Val_int(14); break; \
    default: caml_failwith("unhandled geom class"); \
  }
/* DEBUG:
    default: \
      { char strbuf[64]; \
        snprintf(strbuf, 64, "unhandled geom class: '%d'", geom_class); \
        caml_failwith(strbuf); \
      } \
*/

static const int geom_class_table[] = {
  dSphereClass,
  dBoxClass,
  dCapsuleClass,
  dCylinderClass,
  dPlaneClass,
  dRayClass,
  dConvexClass,
  dGeomTransformClass,
  dTriMeshClass,
  dHeightfieldClass,
  dSimpleSpaceClass,
  dHashSpaceClass,
  dQuadTreeSpaceClass,
  dFirstUserClass,
  dLastUserClass,
};

#define dGeomClass_val(ret, geomclassv) \
  ret = geom_class_table[ Long_val(geomclassv) ]


/* joint_type */

static const int joint_type_table[] = {
  dJointTypeNone,
  dJointTypeBall,
  dJointTypeHinge,
  dJointTypeSlider,
  dJointTypeContact,
  dJointTypeUniversal,
  dJointTypeHinge2,
  dJointTypeFixed,
  dJointTypeNull,
  dJointTypeAMotor,
  dJointTypeLMotor,
  dJointTypePlane2D,
  dJointTypePR,
};

#define joint_type_val(joint_type_i)   (joint_type_table[Long_val(joint_type_i)])

// Assumes joint types are given in the same order in OCaml
// than in the ode header
#define Val_joint_type(joint_type)  Val_long(joint_type)

// in case of a problem, use this one:
value inline __Val_joint_type (int joint_type)
{
  switch (joint_type)
  {
    case dJointTypeNone:      return Val_long(0); break;
    case dJointTypeBall:      return Val_long(1); break;
    case dJointTypeHinge:     return Val_long(2); break;
    case dJointTypeSlider:    return Val_long(3); break;
    case dJointTypeContact:   return Val_long(4); break;
    case dJointTypeUniversal: return Val_long(5); break;
    case dJointTypeHinge2:    return Val_long(6); break;
    case dJointTypeFixed:     return Val_long(7); break;
    case dJointTypeNull:      return Val_long(8); break;
    case dJointTypeAMotor:    return Val_long(9); break;
    case dJointTypeLMotor:    return Val_long(10); break;
    case dJointTypePlane2D:   return Val_long(11); break;
    case dJointTypePR:        return Val_long(12); break;
    default: caml_failwith ("unhandled joint type");
  }
}

/* }}} */
/* {{{ TriMesh Type handling */

// XXX Alpha, needs to be more tested

struct voidptr2 {
  void *data;
  void *data2;  // handles the indices allocated in
};

void finalize_voidptrs2 (value v)
{
  void *data, *data2;
  data =  ((struct voidptr2 *) Data_custom_val (v))->data;
  data2 = ((struct voidptr2 *) Data_custom_val (v))->data2;

  if (data2 != NULL) {
    free (data2);
    data2 = NULL;
  }

  if (data != NULL) {
    /*
    dTriMeshDataID id = dTriMeshDataID_val(v);
    dGeomTriMeshDataDestroy (id);
    */
    // It's up to the user to destroy this,
    // while if the destroy function is not called by the user
    // (with hope that destroying only the world will free everything),
    // this can be finalised while ODE still uses the trimesh.
  }
}

static struct custom_operations custom_ops2 = {
  identifier: "ocamlode_voidptr2",
  finalize: finalize_voidptrs2,  // a finaliser for the associated data
  compare: compare_voidptrs,
  hash: hash_voidptr,
  serialize: custom_serialize_default,
  deserialize: custom_deserialize_default
};

static inline value
Val_voidptr2 (void *ptr, void *ptr2)
{
  CAMLparam0 ();
  CAMLlocal1 (rv);
  rv = caml_alloc_custom (&custom_ops2, sizeof (struct voidptr2), 0, 1);
  ((struct voidptr2 *) Data_custom_val (rv))->data = ptr;
  ((struct voidptr2 *) Data_custom_val (rv))->data2 = ptr2;
  CAMLreturn (rv);
}

static inline void
set_data2 (value rv, void * data2)
{
  void *_data2 = (((struct voidptr2 *) Data_custom_val (rv))->data2);
  if ( _data2 != NULL )
  {
    free (_data2);
  }
  ((struct voidptr2 *) Data_custom_val (rv))->data2 = data2;
}

#define Val_dTriMeshDataID_2(id, data) (Val_voidptr2 ((id), (data)))

/* }}} */

/* {{{ Global */

CAMLprim value
ocamlode_dGetInfinity (value unit)
{
  CAMLparam1 (unit);
  CAMLreturn (caml_copy_double (dInfinity));
}

CAMLprim value
ocamlode_dInitODE (value u)
{
  CAMLparam1 (u);
  dInitODE();
  CAMLreturn (Val_unit);
}

static const unsigned int dInitODEFlags_table[] = {
#if ( (ODE_VERSION_MAJOR == 0) && (ODE_VERSION_MINOR >= 10) ) || (ODE_VERSION_MAJOR > 0)
  dInitFlagManualThreadCleanup,
#else
  0,
#endif
};

CAMLprim value
ocamlode_dInitODE2 (value uiInitFlagsv)
{
  CAMLparam1 (uiInitFlagsv);
#if ( (ODE_VERSION_MAJOR == 0) && (ODE_VERSION_MINOR >= 10) ) || (ODE_VERSION_MAJOR > 0)
  unsigned int uiInitFlags = dInitODEFlags_table[Long_val(uiInitFlagsv)];
  int success = dInitODE2 (uiInitFlags);
  if (!success)
    caml_failwith("dInitODE2");
#else
  caml_failwith("dInitODE2: function available since ODE version 0.10.0");
#endif
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dCloseODE (value unit)
{
  CAMLparam1 (unit);
  dCloseODE ();
  CAMLreturn (Val_unit);
}

/* }}} */
/* {{{ World */

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
  dReal x = Double_val (xv);
  dReal y = Double_val (yv);
  dReal z = Double_val (zv);
  dWorldSetGravity (id, x, y, z);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dWorldGetGravity (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dWorldID id = dWorldID_val (idv);
  dVector3 gravity;
  dWorldGetGravity (id, gravity);
  rv = copy_dReal_array (gravity, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dWorldSetERP (value idv, value erp)
{
  dWorldID id = dWorldID_val (idv);
  dWorldSetERP (id, Double_val(erp));
  return Val_unit;
}

CAMLprim value
ocamlode_dWorldGetERP (value idv)
{
  dWorldID id = dWorldID_val (idv);
  dReal r = dWorldGetERP (id);
  return caml_copy_double (r);
}

CAMLprim value
ocamlode_dWorldSetCFM (value idv, value cfmv)
{
  CAMLparam2 (idv, cfmv);
  dWorldID id = dWorldID_val (idv);
  dReal cfm = Double_val (cfmv);
  dWorldSetCFM (id, cfm);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dWorldGetCFM (value idv)
{
  dWorldID id = dWorldID_val (idv);
  dReal r = dWorldGetCFM( id );
  return caml_copy_double (r);
}

CAMLprim value
ocamlode_dWorldStep (value idv, value stepsizev)
{
  CAMLparam2 (idv, stepsizev);
  dWorldID id = dWorldID_val (idv);
  dReal stepsize = Double_val (stepsizev);
  dWorldStep (id, stepsize);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dWorldQuickStep (value idv, value stepsizev)
{
  CAMLparam2 (idv, stepsizev);
  dWorldID id = dWorldID_val (idv);
  dReal stepsize = Double_val (stepsizev);
  dWorldQuickStep (id, stepsize);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dWorldStepFast1 (value idv, value stepsize, value maxiterations)
{
  dWorldStepFast1 (dWorldID_val (idv), Double_val (stepsize), Int_val (maxiterations));
  return Val_unit;
}

CAMLprim value
ocamlode_dWorldSetAutoEnableDepthSF1 (value world, value autodepth)
{
  dWorldSetAutoEnableDepthSF1 (dWorldID_val (world), Int_val (autodepth));
  return Val_unit;
}

CAMLprim value
ocamlode_dWorldGetAutoEnableDepthSF1 (value world)
{
  return Val_int (dWorldGetAutoEnableDepthSF1(dWorldID_val (world)));
}

CAMLprim value
ocamlode_dWorldSetQuickStepNumIterations( value worldv, value num )
{
  CAMLparam2 (worldv, num);
  dWorldID world = dWorldID_val (worldv);
  dWorldSetQuickStepNumIterations( world, Int_val(num) );
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dWorldGetQuickStepNumIterations( value worldv )
{
  CAMLparam1 (worldv);
  int _ret;
  dWorldID world = dWorldID_val (worldv);
  _ret = dWorldGetQuickStepNumIterations (world);
  CAMLreturn (Val_int (_ret));
}

CAMLprim value
ocamlode_dWorldSetContactSurfaceLayer (value world, value depth)
{
  dWorldSetContactSurfaceLayer (dWorldID_val (world), Double_val (depth));
  return Val_unit;
}

CAMLprim value
ocamlode_dWorldGetContactSurfaceLayer (value world)
{
  return caml_copy_double (dWorldGetContactSurfaceLayer (dWorldID_val (world)));
}

CAMLprim value
ocamlode_dWorldSetAutoDisableLinearThreshold (value world, value linear_threshold)
{
  dWorldSetAutoDisableLinearThreshold (dWorldID_val (world), Double_val (linear_threshold));
  return Val_unit;
}

CAMLprim value
ocamlode_dWorldGetAutoDisableLinearThreshold (value world)
{
  return caml_copy_double (dWorldGetAutoDisableLinearThreshold (dWorldID_val (world)));
}

CAMLprim value
ocamlode_dWorldSetAutoDisableAngularThreshold (value world, value angular_threshold)
{
  dWorldSetAutoDisableAngularThreshold (dWorldID_val (world), Double_val (angular_threshold));
  return Val_unit;
}

CAMLprim value
ocamlode_dWorldGetAutoDisableAngularThreshold (value world)
{
  return caml_copy_double (dWorldGetAutoDisableAngularThreshold (dWorldID_val (world)));
}

/*
CAMLprim value
ocamlode_dWorldSetAutoDisableLinearAverageThreshold (value world, value linear_average_threshold)
{
  dWorldSetAutoDisableLinearAverageThreshold (dWorldID_val(world), Double_val (linear_average_threshold));
  return Val_unit;
}

CAMLprim value
ocamlode_dWorldGetAutoDisableLinearAverageThreshold (value world)
{
  return caml_copy_double (dWorldGetAutoDisableLinearAverageThreshold (dWorldID_val(world)));
}

CAMLprim value
ocamlode_dWorldSetAutoDisableAngularAverageThreshold (value world, value angular_average_threshold)
{
  dWorldSetAutoDisableAngularAverageThreshold (dWorldID_val(world), Double_val (angular_average_threshold));
  return Val_unit;
}

CAMLprim value
ocamlode_dWorldGetAutoDisableAngularAverageThreshold (value world)
{
  return caml_copy_double (dWorldGetAutoDisableAngularAverageThreshold (dWorldID_val (world)));
}
*/

CAMLprim value
ocamlode_dWorldSetAutoDisableAverageSamplesCount (value world, value average_samples_count)
{
  dWorldSetAutoDisableAverageSamplesCount (dWorldID_val (world), Int_val (average_samples_count));
  return Val_unit;
}

CAMLprim value
ocamlode_dWorldGetAutoDisableAverageSamplesCount (value world)
{
  return Val_int (dWorldGetAutoDisableAverageSamplesCount (dWorldID_val (world)));
}

CAMLprim value
ocamlode_dWorldSetAutoDisableSteps (value world, value steps)
{
  dWorldSetAutoDisableSteps (dWorldID_val (world), Int_val (steps));
  return Val_unit;
}

CAMLprim value
ocamlode_dWorldGetAutoDisableSteps (value world)
{
  return Val_int (dWorldGetAutoDisableSteps (dWorldID_val (world)));
}

CAMLprim value
ocamlode_dWorldSetAutoDisableTime (value world, value time)
{
  dWorldSetAutoDisableTime (dWorldID_val (world), Double_val (time));
  return Val_unit;
}

CAMLprim value
ocamlode_dWorldGetAutoDisableTime (value world)
{
  return caml_copy_double (dWorldGetAutoDisableTime (dWorldID_val (world)));
}

CAMLprim value
ocamlode_dWorldSetAutoDisableFlag (value world, value do_auto_disable)
{
  dWorldSetAutoDisableFlag (dWorldID_val (world), Int_val (do_auto_disable));
  return Val_unit;
}

CAMLprim value
ocamlode_dWorldGetAutoDisableFlag (value world)
{
  return Val_bool (dWorldGetAutoDisableFlag (dWorldID_val (world)));
}

CAMLprim value
ocamlode_dWorldSetQuickStepW (value world, value over_relaxation)
{
  dWorldSetQuickStepW (dWorldID_val (world), Double_val (over_relaxation));
  return Val_unit;
}

CAMLprim value
ocamlode_dWorldGetQuickStepW (value world)
{
  return caml_copy_double (dWorldGetQuickStepW (dWorldID_val (world)));
}

CAMLprim value
ocamlode_dWorldSetContactMaxCorrectingVel (value world, value vel)
{
  dWorldSetContactMaxCorrectingVel (dWorldID_val (world), Double_val (vel));
  return Val_unit;
}

CAMLprim value
ocamlode_dWorldGetContactMaxCorrectingVel (value world)
{
  return caml_copy_double (dWorldGetContactMaxCorrectingVel (dWorldID_val (world)));
}

/* }}} */
/* {{{ Bodies */

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

CAMLprim value
ocamlode_dBodyGetWorld( value idv )
{
  dWorldID wid;
  dBodyID id = dBodyID_val (idv);
  wid = dBodyGetWorld( id );
  return Val_dWorldID (wid);
}

CAMLprim value
ocamlode_dBodySetPosition (value idv, value xv, value yv, value zv)
{
  CAMLparam4 (idv, xv, yv, zv);
  dBodyID id = dBodyID_val (idv);
  dReal x = Double_val (xv);
  dReal y = Double_val (yv);
  dReal z = Double_val (zv);
  dBodySetPosition (id, x, y, z);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dBodySetRotation( value idv, value mv )
{
  dBodyID id = dBodyID_val (idv);
#if defined(MEM_CPY) // dSINGLE
  dMatrix3 m;
  int i;
  for (i=0; i<12; ++i)
    m[i] = Double_field(mv,i);
  dBodySetRotation( id, m );
#else // dDOUBLE
  dBodySetRotation (id, (double *) mv);
#endif
  return Val_unit;
}

CAMLprim value
ocamlode_dBodySetQuaternion( value idv, value qv )
{
  dBodyID id = dBodyID_val (idv);
#if defined(MEM_CPY) // dSINGLE
  dQuaternion q;
  int i;
  for (i=0; i<4; ++i)
    q[i] = Double_field(qv,i);
  dBodySetQuaternion (id, q);
#else // dDOUBLE
  dBodySetQuaternion (id, (double *) qv);
#endif
  return Val_unit;
}

CAMLprim value
ocamlode_dBodySetLinearVel( value idv, value x, value y, value z )
{
  dBodyID id = dBodyID_val (idv);
  dBodySetLinearVel( id, Double_val(x), Double_val(y), Double_val(z) );
  return Val_unit;
}

CAMLprim value
ocamlode_dBodySetAngularVel( value idv, value x, value y, value z )
{
  dBodyID id = dBodyID_val (idv);
  dBodySetAngularVel( id, Double_val(x), Double_val(y), Double_val(z) );
  return Val_unit;
}

CAMLprim value
ocamlode_dBodyGetPosition (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  const dReal *r = dBodyGetPosition (id);
  rv = copy_dReal_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dBodyGetRotation (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  const dReal *r = dBodyGetRotation (id);
  rv = copy_dReal_array (r, 12);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dBodyGetQuaternion (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  const dReal *r = dBodyGetQuaternion (id);
  rv = copy_dReal_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dBodyGetLinearVel (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  const dReal *r = dBodyGetLinearVel (id);
  rv = copy_dReal_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dBodyGetAngularVel (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  const dReal *r = dBodyGetAngularVel (id);
  rv = copy_dReal_array (r, 4);
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
  CAMLparam4 (idv, fxv, fyv, fzv);
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
  CAMLparam4 (idv, fxv, fyv, fzv);
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
  CAMLparam4 (idv, fxv, fyv, fzv);
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
  CAMLparam4 (idv, fxv, fyv, fzv);
  dBodyID id = dBodyID_val (idv);
  dReal fx = Double_val (fxv);
  dReal fy = Double_val (fyv);
  dReal fz = Double_val (fzv);
  dBodyAddRelTorque (id, fx, fy, fz);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dBodyAddForceAtPos (value body, value fx, value fy, value fz,
                                         value px, value py, value pz)
{
  dBodyAddForceAtPos (dBodyID_val (body), Double_val(fx), Double_val(fy), Double_val(fz),
                                          Double_val(px), Double_val(py), Double_val(pz));
  return Val_unit;
}
CAMLprim value
ocamlode_dBodyAddForceAtPos_bc (value * argv, int argn)
{
  return ocamlode_dBodyAddForceAtPos(
    argv[0], argv[1], argv[2], argv[3], argv[4], argv[5], argv[6] );
}

CAMLprim value
ocamlode_dBodyAddForceAtRelPos (value body, value fx, value fy, value fz,
                                            value px, value py, value pz)
{
  dBodyAddForceAtRelPos (dBodyID_val (body), Double_val(fx), Double_val(fy), Double_val(fz),
                                             Double_val(px), Double_val(py), Double_val(pz));
  return Val_unit;
}
CAMLprim value
ocamlode_dBodyAddForceAtRelPos_bc (value * argv, int argn)
{
  return ocamlode_dBodyAddForceAtRelPos(
    argv[0], argv[1], argv[2], argv[3], argv[4], argv[5], argv[6] );
}

CAMLprim value
ocamlode_dBodyAddRelForceAtPos (value body, value fx, value fy, value fz,
                                            value px, value py, value pz)
{
  dBodyAddRelForceAtPos (dBodyID_val (body), Double_val(fx), Double_val(fy), Double_val(fz),
                                             Double_val(px), Double_val(py), Double_val(pz));
  return Val_unit;
}
CAMLprim value
ocamlode_dBodyAddRelForceAtPos_bc (value * argv, int argn)
{
  return ocamlode_dBodyAddRelForceAtPos(
    argv[0], argv[1], argv[2], argv[3], argv[4], argv[5], argv[6] );
}

CAMLprim value
ocamlode_dBodyAddRelForceAtRelPos (value body, value fx, value fy, value fz,
                                               value px, value py, value pz)
{
  dBodyAddRelForceAtRelPos (dBodyID_val (body), Double_val(fx), Double_val(fy), Double_val(fz),
                                                Double_val(px), Double_val(py), Double_val(pz));
  return Val_unit;
}
CAMLprim value
ocamlode_dBodyAddRelForceAtRelPos_bc (value * argv, int argn)
{
  return ocamlode_dBodyAddRelForceAtRelPos(
    argv[0], argv[1], argv[2], argv[3], argv[4], argv[5], argv[6] );
}

CAMLprim value
ocamlode_dBodySetForce (value body, value x, value y, value z)
{
  dBodySetForce (dBodyID_val (body), Double_val(x), Double_val(y), Double_val(z));
  return Val_unit;
}

CAMLprim value
ocamlode_dBodySetTorque (value body, value x, value y, value z)
{
  dBodySetTorque (dBodyID_val (body) , Double_val(x), Double_val(y), Double_val(z));
  return Val_unit;
}

CAMLprim value
ocamlode_dBodyGetForce (value body)
{
  const dReal * f = dBodyGetForce (dBodyID_val (body));
  return copy_dReal_array (f, 4);
}

CAMLprim value
ocamlode_dBodyGetTorque (value body)
{
  const dReal * t = dBodyGetTorque (dBodyID_val (body));
  return copy_dReal_array (t, 4);
}

CAMLprim value
ocamlode_dBodyGetRelPointPos (value idv, value pxv, value pyv, value pzv)
{
  CAMLparam4 (idv, pxv, pyv, pzv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  dReal px = Double_val (pxv);
  dReal py = Double_val (pyv);
  dReal pz = Double_val (pzv);
  dVector3 r;
  dBodyGetRelPointPos (id, px, py, pz, r);
  rv = copy_dReal_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dBodyGetPosRelPoint (value idv, value pxv, value pyv, value pzv)
{
  CAMLparam4 (idv, pxv, pyv, pzv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  dReal px = Double_val (pxv);
  dReal py = Double_val (pyv);
  dReal pz = Double_val (pzv);
  dVector3 r;
  dBodyGetPosRelPoint (id, px, py, pz, r);
  rv = copy_dReal_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dBodyGetRelPointVel (value idv, value pxv, value pyv, value pzv)
{
  CAMLparam4 (idv, pxv, pyv, pzv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  dReal px = Double_val (pxv);
  dReal py = Double_val (pyv);
  dReal pz = Double_val (pzv);
  dVector3 r;
  dBodyGetRelPointVel (id, px, py, pz, r);
  rv = copy_dReal_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dBodyGetPointVel (value idv, value pxv, value pyv, value pzv)
{
  CAMLparam4 (idv, pxv, pyv, pzv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  dReal px = Double_val (pxv);
  dReal py = Double_val (pyv);
  dReal pz = Double_val (pzv);
  dVector3 r;
  dBodyGetPointVel (id, px, py, pz, r);
  rv = copy_dReal_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dBodyVectorToWorld (value idv, value pxv, value pyv, value pzv)
{
  CAMLparam4 (idv, pxv, pyv, pzv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  dReal px = Double_val (pxv);
  dReal py = Double_val (pyv);
  dReal pz = Double_val (pzv);
  dVector3 r;
  dBodyVectorToWorld (id, px, py, pz, r);
  rv = copy_dReal_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dBodyVectorFromWorld (value idv, value pxv, value pyv, value pzv)
{
  CAMLparam4 (idv, pxv, pyv, pzv);
  CAMLlocal1 (rv);
  dBodyID id = dBodyID_val (idv);
  dReal px = Double_val (pxv);
  dReal py = Double_val (pyv);
  dReal pz = Double_val (pzv);
  dVector3 r;
  dBodyVectorFromWorld (id, px, py, pz, r);
  rv = copy_dReal_array (r, 4);
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
ocamlode_dBodySetAutoDisableSteps (value idv, value steps)
{
  CAMLparam1 (idv);
  dBodyID id = dBodyID_val (idv);
  dBodySetAutoDisableSteps (id, Int_val(steps));
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dBodyGetAutoDisableSteps (value idv)
{
  dBodyID id = dBodyID_val (idv);
  return Val_int (dBodyGetAutoDisableSteps (id));
}

CAMLprim value
ocamlode_dBodySetAutoDisableTime (value idv, value timev)
{
  CAMLparam1 (idv);
  dBodyID id = dBodyID_val (idv);
  dReal time = Double_val (timev);
  dBodySetAutoDisableTime (id, time);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dBodyGetAutoDisableTime (value idv)
{
  CAMLparam1 (idv);
  dBodyID id = dBodyID_val (idv);
  dReal r = dBodyGetAutoDisableTime (id);
  CAMLreturn (caml_copy_double (r));
}

CAMLprim value
ocamlode_dAreConnected (value idav, value idbv)
{
  CAMLparam2 (idav, idbv);
  dBodyID ida = dBodyID_val (idav);
  dBodyID idb = dBodyID_val (idbv);
  int conn = dAreConnected (ida, idb);
  CAMLreturn (Val_bool (conn));
}

CAMLprim value
ocamlode_dAreConnectedExcluding (value body1, value body2, value joint_type_v)
{
  int joint_type = joint_type_val (joint_type_v);
  int ret = dAreConnectedExcluding (dBodyID_val (body1), dBodyID_val (body2), joint_type);
  return Val_bool (ret);
}

CAMLprim value
ocamlode_dBodySetGravityMode (value b, value mode)
{
  dBodySetGravityMode (dBodyID_val (b), Bool_val (mode));
  return Val_unit;
}

CAMLprim value
ocamlode_dBodyGetGravityMode (value b)
{
  return Val_bool (dBodyGetGravityMode (dBodyID_val (b)));
}

CAMLprim value
ocamlode_dBodySetFiniteRotationMode (value body, value mode)
{
  dBodySetFiniteRotationMode (dBodyID_val (body), Bool_val(mode));
  return Val_unit;
}

CAMLprim value
ocamlode_dBodyGetFiniteRotationMode (value body)
{
  int ret = dBodyGetFiniteRotationMode (dBodyID_val (body));
  return Val_bool (ret);
}

CAMLprim value
ocamlode_dBodySetFiniteRotationAxis (value body, value x, value y, value z)
{
  dBodySetFiniteRotationAxis (dBodyID_val (body), Double_val(x), Double_val(y), Double_val(z));
  return Val_unit;
}

CAMLprim value
ocamlode_dBodyGetFiniteRotationAxis (value body)
{
  dVector3 result;
  dBodyGetFiniteRotationAxis (dBodyID_val (body), result);
  return copy_dVector3 (result);
}

CAMLprim value
ocamlode_dBodySetAutoDisableLinearThreshold (value body, value linear_average_threshold)
{
  dBodySetAutoDisableLinearThreshold (dBodyID_val (body), Double_val (linear_average_threshold));
  return Val_unit;
}

CAMLprim value
ocamlode_dBodyGetAutoDisableLinearThreshold (value body)
{
  return caml_copy_double (dBodyGetAutoDisableLinearThreshold (dBodyID_val (body)));
}

CAMLprim value
ocamlode_dBodySetAutoDisableAngularThreshold (value body, value angular_average_threshold)
{
  dBodySetAutoDisableAngularThreshold (dBodyID_val (body), Double_val (angular_average_threshold));
  return Val_unit;
}

CAMLprim value
ocamlode_dBodyGetAutoDisableAngularThreshold (value body)
{
  return caml_copy_double (dBodyGetAutoDisableAngularThreshold (dBodyID_val (body)));
}

CAMLprim value
ocamlode_dBodySetAutoDisableAverageSamplesCount (value body, value average_samples_count)
{
  dBodySetAutoDisableAverageSamplesCount (dBodyID_val (body), Int_val (average_samples_count));
  return Val_unit;
}

CAMLprim value
ocamlode_dBodyGetAutoDisableAverageSamplesCount (value body)
{
  int ret = dBodyGetAutoDisableAverageSamplesCount (dBodyID_val (body));
  if (ret > Max_long)
    caml_failwith("dBodyGetAutoDisableAverageSamplesCount: integer overflow");
  return Val_int(ret);
}

/* OCaml integers are unboxed,
 * here it is set, and get back without convertions
 */
CAMLprim value
ocamlode_dBodySetData (value body, value data)
{
  dBodySetData (dBodyID_val (body), (void*) data);
  return Val_unit;
}

CAMLprim value
ocamlode_dBodyGetData (value body)
{
  return ((value) dBodyGetData (dBodyID_val (body)));
}

/*
 void dBodySetAutoDisableDefaults (dBodyID);
*/

/* }}} */
/* {{{ Joints */

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
ocamlode_dJointCreateLMotor (value worldv, value jointgroupv)
{
  CAMLparam2 (worldv, jointgroupv);
  dWorldID world = dWorldID_val (worldv);
  dJointGroupID jointgroup;
  if (jointgroupv == Val_int (0)) /* None */
    jointgroup = 0;
  else				/* Some jointgroup */
    jointgroup = dJointGroupID_val (Field (jointgroupv, 0));
  dJointID id = dJointCreateLMotor (world, jointgroup);
  CAMLreturn (Val_dJointID (id));
}

/*
 dJointID dJointCreatePR (dWorldID, dJointGroupID);
 dJointID dJointCreateNull (dWorldID, dJointGroupID);
*/

CAMLprim value
ocamlode_dJointCreatePlane2D (value worldv, value jointgroupv)
{
  CAMLparam2 (worldv, jointgroupv);
  dWorldID world = dWorldID_val (worldv);
  dJointGroupID jointgroup;
  if (jointgroupv == Val_int (0)) /* None */
    jointgroup = 0;
  else				/* Some jointgroup */
    jointgroup = dJointGroupID_val (Field (jointgroupv, 0));
  dJointID id = dJointCreatePlane2D (world, jointgroup);
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
  rv = copy_dReal_array (r, 4);
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
ocamlode_dJointSetLMotorParam (value idv, value paramv, value vv)
{
  CAMLparam3 (idv, paramv, vv);
  dJointID id = dJointID_val (idv);
  int parameter = dJointParam_val (paramv);
  dReal v = Double_val (vv);
  dJointSetLMotorParam (id, parameter, v);
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
ocamlode_dJointGetLMotorParam (value idv, value paramv)
{
  CAMLparam2 (idv, paramv);
  dJointID id = dJointID_val (idv);
  int parameter = dJointParam_val (paramv);
  dReal r = dJointGetLMotorParam (id, parameter);
  CAMLreturn (caml_copy_double (r));
}

CAMLprim value
ocamlode_dJointSetBallAnchor (value idv, value xv, value yv, value zv)
{
  CAMLparam4 (idv, xv, yv, zv);
  dJointID id = dJointID_val (idv);
  dReal x = Double_val (xv);
  dReal y = Double_val (yv);
  dReal z = Double_val (zv);
  dJointSetBallAnchor (id, x, y, z);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dJointSetBallAnchor2 (value idv, value xv, value yv, value zv)
{
  CAMLparam4 (idv, xv, yv, zv);
  dJointID id = dJointID_val (idv);
  dReal x = Double_val (xv);
  dReal y = Double_val (yv);
  dReal z = Double_val (zv);
  dJointSetBallAnchor2 (id, x, y, z);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dJointSetHingeAnchor (value joint, value x, value y, value z)
{
  dJointSetHingeAnchor (dJointID_val (joint), Double_val (x), Double_val (y), Double_val (z));
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetHingeAnchorDelta (value joint, value x, value y, value z, value ax, value ay, value az)
{
  dJointSetHingeAnchorDelta (dJointID_val (joint), Double_val (x), Double_val (y), Double_val (z),
                             Double_val (ax), Double_val (ay), Double_val (az));
  return Val_unit;
}
CAMLprim value
ocamlode_dJointSetHingeAnchorDelta_bytecode (value * argv, int argn)
{
  return ocamlode_dJointSetHingeAnchorDelta (argv[0], argv[1], argv[2],
                                             argv[3], argv[4], argv[5], argv[6]);
}

CAMLprim value
ocamlode_dJointSetHingeAxis (value joint, value x, value y, value z)
{
  dJointSetHingeAxis (dJointID_val (joint), Double_val (x), Double_val (y), Double_val (z));
  return Val_unit;
}

CAMLprim value
ocamlode_dJointAddHingeTorque (value joint, value torque)
{
  dJointAddHingeTorque (dJointID_val (joint), Double_val (torque));
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetSliderAxisDelta (value joint, value x, value y, value z, value ax, value ay, value az)
{
  dJointSetSliderAxisDelta (dJointID_val (joint), Double_val (x), Double_val (y), Double_val (z),
                            Double_val (ax), Double_val (ay), Double_val (az));
  return Val_unit;
}
CAMLprim value
ocamlode_dJointSetSliderAxisDelta_bytecode (value * argv, int argn)
{
  return ocamlode_dJointSetSliderAxisDelta (argv[0], argv[1], argv[2],
                                            argv[3], argv[4], argv[5], argv[6]);
}

CAMLprim value
ocamlode_dJointAddSliderForce (value joint, value force)
{
  dJointAddSliderForce (dJointID_val (joint), Double_val (force));
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetHinge2Anchor (value joint, value x, value y, value z)
{
  dJointSetHinge2Anchor (dJointID_val (joint), Double_val (x), Double_val (y), Double_val (z));
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetHinge2Axis1 (value joint, value x, value y, value z)
{
  dJointSetHinge2Axis1 (dJointID_val (joint), Double_val (x), Double_val (y), Double_val (z));
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetHinge2Axis2 (value joint, value x, value y, value z)
{
  dJointSetHinge2Axis2 (dJointID_val (joint), Double_val (x), Double_val (y), Double_val (z));
  return Val_unit;
}

CAMLprim value
ocamlode_dJointAddHinge2Torques (value joint, value torque1, value torque2)
{
  dJointAddHinge2Torques (dJointID_val (joint), Double_val (torque1), Double_val (torque2));
  return Val_unit;
}

/* {{{ generated code needing to be tested */

CAMLprim value
ocamlode_dJointSetUniversalAnchor( value pv, value x, value y, value z )
{
  dJointID p = dJointID_val (pv);
  dJointSetUniversalAnchor( p, Double_val(x), Double_val(y), Double_val(z) );
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetUniversalAxis1( value pv, value x, value y, value z )
{
  dJointID p = dJointID_val (pv);
  dJointSetUniversalAxis1( p, Double_val(x), Double_val(y), Double_val(z) );
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetUniversalAxis2( value pv, value x, value y, value z )
{
  dJointID p = dJointID_val (pv);
  dJointSetUniversalAxis2( p, Double_val(x), Double_val(y), Double_val(z) );
  return Val_unit;
}

CAMLprim value
ocamlode_dJointAddUniversalTorques( value jointv, value torque1, value torque2 )
{
  dJointID joint = dJointID_val (jointv);
  dJointAddUniversalTorques( joint, Double_val(torque1), Double_val(torque2) );
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetPRAnchor( value pv, value x, value y, value z )
{
  dJointID p = dJointID_val (pv);
  dJointSetPRAnchor( p, Double_val(x), Double_val(y), Double_val(z) );
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetPRAxis1( value pv, value x, value y, value z )
{
  dJointID p = dJointID_val (pv);
  dJointSetPRAxis1( p, Double_val(x), Double_val(y), Double_val(z) );
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetPRAxis2( value pv, value x, value y, value z )
{
  dJointID p = dJointID_val (pv);
  dJointSetPRAxis2( p, Double_val(x), Double_val(y), Double_val(z) );
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetPRParam( value pv, value parameter, value value )
{
  dJointID p = dJointID_val (pv);
  dJointSetPRParam( p, Int_val(parameter), Double_val(value) );
  return Val_unit;
}

CAMLprim value
ocamlode_dJointAddPRTorque( value jv, value torque )
{
  dJointID j = dJointID_val (jv);
  dJointAddPRTorque( j, Double_val(torque) );
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetFixed( value pv )
{
  dJointID p = dJointID_val (pv);
  dJointSetFixed( p );
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetAMotorNumAxes( value pv, value num )
{
  dJointID p = dJointID_val (pv);
  dJointSetAMotorNumAxes( p, Int_val(num) );
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetAMotorAxis( value pv, value anum, value rel, value x, value y, value z )
{
  dJointID p = dJointID_val (pv);
  dJointSetAMotorAxis( p, Int_val(anum), Int_val(rel), Double_val(x), Double_val(y), Double_val(z) );
  return Val_unit;
}
CAMLprim value
ocamlode_dJointSetAMotorAxis_bc(value * argv, int argn)
{
  return ocamlode_dJointSetAMotorAxis(
    argv[0], argv[1], argv[2], argv[3], argv[4], argv[5] );
}

CAMLprim value
ocamlode_dJointSetAMotorAngle( value pv, value anum, value angle )
{
  dJointID p = dJointID_val (pv);
  dJointSetAMotorAngle( p, Int_val(anum), Double_val(angle) );
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetAMotorMode( value pv, value mode )
{
  dJointID p = dJointID_val (pv);
  dJointSetAMotorMode( p, Int_val(mode) );
  return Val_unit;
}

CAMLprim value
ocamlode_dJointAddAMotorTorques( value pv, value torque1, value torque2, value torque3 )
{
  dJointID p = dJointID_val (pv);
  dJointAddAMotorTorques( p, Double_val(torque1), Double_val(torque2), Double_val(torque3) );
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetLMotorNumAxes( value pv, value num )
{
  dJointID p = dJointID_val (pv);
  dJointSetLMotorNumAxes( p, Int_val(num) );
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetLMotorAxis( value pv, value anum, value rel, value x, value y, value z )
{
  dJointID p = dJointID_val (pv);
  dJointSetLMotorAxis( p, Int_val(anum), Int_val(rel), Double_val(x), Double_val(y), Double_val(z) );
  return Val_unit;
}
CAMLprim value
ocamlode_dJointSetLMotorAxis_bc(value * argv, int argn)
{
  return ocamlode_dJointSetLMotorAxis(
    argv[0], argv[1], argv[2], argv[3], argv[4], argv[5] );
}

/* }}} */

CAMLprim value
ocamlode_dJointSetPlane2DXParam (value joint, value paramv, value val)
{
  int param = dJointParam_val (paramv);
  dJointSetPlane2DXParam (dJointID_val (joint), param, Double_val (val));
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetPlane2DYParam (value joint, value paramv, value val)
{
  int param = dJointParam_val (paramv);
  dJointSetPlane2DYParam (dJointID_val (joint), param, Double_val (val));
  return Val_unit;
}

CAMLprim value
ocamlode_dJointSetPlane2DAngleParam (value joint, value paramv, value val)
{
  int param = dJointParam_val (paramv);
  dJointSetPlane2DAngleParam (dJointID_val (joint), param, Double_val (val));
  return Val_unit;
}

CAMLprim value
ocamlode_dJointGetBallAnchor (value joint)
{
  dVector3 result;
  dJointGetBallAnchor (dJointID_val (joint), result);
  return copy_dVector3 (result);
}

CAMLprim value
ocamlode_dJointGetBallAnchor2 (value joint)
{
  dVector3 result;
  dJointGetBallAnchor2 (dJointID_val (joint), result);
  return copy_dVector3 (result);
}

CAMLprim value
ocamlode_dJointGetHingeAnchor (value joint)
{
  dVector3 result;
  dJointGetHingeAnchor (dJointID_val (joint), result);
  return copy_dVector3 (result);
}

CAMLprim value
ocamlode_dJointGetHingeAnchor2 (value joint)
{
  dVector3 result;
  dJointGetHingeAnchor2 (dJointID_val (joint), result);
  return copy_dVector3 (result);
}

CAMLprim value
ocamlode_dJointGetHingeAxis (value joint)
{
  dVector3 result;
  dJointGetHingeAxis (dJointID_val (joint), result);
  return copy_dVector3 (result);
}

CAMLprim value
ocamlode_dJointGetHingeAngle (value joint)
{
  return caml_copy_double (dJointGetHingeAngle (dJointID_val (joint)));
}

CAMLprim value
ocamlode_dJointGetHingeAngleRate (value joint)
{
  return caml_copy_double (dJointGetHingeAngleRate (dJointID_val (joint)));
}

CAMLprim value
ocamlode_dJointGetHinge2Anchor (value joint)
{
  dVector3 result;
  dJointGetHinge2Anchor (dJointID_val (joint), result);
  return copy_dVector3 (result);
}

CAMLprim value
ocamlode_dJointGetHinge2Anchor2 (value joint)
{
  dVector3 result;
  dJointGetHinge2Anchor2 (dJointID_val (joint), result);
  return copy_dVector3 (result);
}

CAMLprim value
ocamlode_dJointGetHinge2Axis1 (value joint)
{
  dVector3 result;
  dJointGetHinge2Axis1 (dJointID_val (joint), result);
  return copy_dVector3 (result);
}

CAMLprim value
ocamlode_dJointGetHinge2Axis2 (value joint)
{
  dVector3 result;
  dJointGetHinge2Axis2 (dJointID_val (joint), result);
  return copy_dVector3 (result);
}

CAMLprim value
ocamlode_dJointGetHinge2Angle1 (value joint)
{
  return caml_copy_double (dJointGetHinge2Angle1 (dJointID_val (joint)));
}

CAMLprim value
ocamlode_dJointGetHinge2Angle1Rate (value joint)
{
  return caml_copy_double (dJointGetHinge2Angle1Rate (dJointID_val (joint)));
}

CAMLprim value
ocamlode_dJointGetHinge2Angle2Rate (value joint)
{
  return caml_copy_double (dJointGetHinge2Angle2Rate (dJointID_val (joint)));
}

CAMLprim value
ocamlode_dJointGetUniversalAnchor (value joint)
{
  dVector3 result;
  dJointGetUniversalAnchor (dJointID_val (joint), result);
  return copy_dVector3 (result);
}

CAMLprim value
ocamlode_dJointGetUniversalAnchor2 (value joint)
{
  dVector3 result;
  dJointGetUniversalAnchor2 (dJointID_val (joint), result);
  return copy_dVector3 (result);
}

CAMLprim value
ocamlode_dJointGetUniversalAxis1 (value joint)
{
  dVector3 result;
  dJointGetUniversalAxis1 (dJointID_val (joint), result);
  return copy_dVector3 (result);
}

CAMLprim value
ocamlode_dJointGetUniversalAxis2 (value joint)
{
  dVector3 result;
  dJointGetUniversalAxis2 (dJointID_val (joint), result);
  return copy_dVector3 (result);
}

/*
 void dJointGetUniversalAngles (dJointID, dReal *angle1, dReal *angle2);
 dReal dJointGetUniversalAngle1 (dJointID);
 dReal dJointGetUniversalAngle2 (dJointID);
 dReal dJointGetUniversalAngle1Rate (dJointID);
 dReal dJointGetUniversalAngle2Rate (dJointID);

 void dJointGetPRAnchor (dJointID, dVector3 result);

 dReal dJointGetPRPosition (dJointID);
 dReal dJointGetPRPositionRate (dJointID);
 void dJointGetPRAxis1 (dJointID, dVector3 result);
 void dJointGetPRAxis2 (dJointID, dVector3 result);
 dReal dJointGetPRParam (dJointID, int parameter);

 int dJointGetAMotorNumAxes (dJointID);
 void dJointGetAMotorAxis (dJointID, int anum, dVector3 result);
 int dJointGetAMotorAxisRel (dJointID, int anum);
 dReal dJointGetAMotorAngle (dJointID, int anum);
 dReal dJointGetAMotorAngleRate (dJointID, int anum);
 int dJointGetAMotorMode (dJointID);

 int dJointGetLMotorNumAxes (dJointID);
 void dJointGetLMotorAxis (dJointID, int anum, dVector3 result);
*/

CAMLprim value
ocamlode_dBodyGetNumJoints (value body)
{
  return Val_int (dBodyGetNumJoints (dBodyID_val (body)));
}

CAMLprim value
ocamlode_dBodyGetJoint (value body, value index)
{
  dJointID joint = dBodyGetJoint (dBodyID_val (body), Int_val (index));
  return Val_dJointID (joint);
}

CAMLprim value
ocamlode_dConnectingJoint (value b1, value b2)
{
  dJointID joint = dConnectingJoint (dBodyID_val (b1), dBodyID_val (b2));
  return Val_dJointID (joint);
}

CAMLprim value
ocamlode_dConnectingJointList (value b1, value b2)
{
  CAMLparam2 (b1, b2);
  CAMLlocal1 (rv);

  dJointID* jlist = NULL;
  int i;
  int n = dConnectingJointList (dBodyID_val (b1), dBodyID_val (b2), jlist);

  rv = caml_alloc(n, 0);
  for (i=0; i<n; ++i) {
    Store_field (rv, i, Val_dJointID (jlist[i]) );
  }
  CAMLreturn (rv);
}

/* OCaml integers are unboxed,
 * here it is set, and get back without convertions
 */
CAMLprim value
ocamlode_dJointSetData (value joint, value data)
{
  dJointSetData (dJointID_val (joint), (void *) data);
  return Val_unit;
}

CAMLprim value
ocamlode_dJointGetData (value joint)
{
  return ((value) dJointGetData (dJointID_val (joint)));
}

CAMLprim value
ocamlode_dJointGetType (value joint)
{
  return Val_joint_type (dJointGetType (dJointID_val (joint)));
}

CAMLprim value
ocamlode_dJointGetBody (value joint, value index)
{
  dBodyID b = dJointGetBody (dJointID_val (joint), Int_val (index));
  if (!b) caml_failwith("dJointGetBody: connection with the static environment");
  return Val_dBodyID (b);
}

static struct custom_operations dJointFeedback_custom_ops = {
  identifier: "ocamlode_dJointFeedback",
  finalize:    custom_finalize_default,
  compare:     custom_compare_default,
  hash:        custom_hash_default,
  serialize:   custom_serialize_default,
  deserialize: custom_deserialize_default
};

static inline value copy_dJointFeedback (dJointFeedback *some_obj)
{
  CAMLparam0 ();
  CAMLlocal1 (v);
  v = caml_alloc_custom (&dJointFeedback_custom_ops, sizeof(dJointFeedback), 0, 1);
  memcpy (Data_custom_val(v), some_obj, sizeof(dJointFeedback));
  CAMLreturn (v);
}
/*
define value alloc_dJointFeedback \
  caml_alloc_custom (&dJointFeedback_custom_ops, sizeof(dJointFeedback), 0, 1)
*/
CAMLprim value
_ocamlode_dJointSetFeedback ( value joint )
{
  CAMLparam1 (joint);
  CAMLlocal1 (ml_jfb);
  ml_jfb = caml_alloc_custom (&dJointFeedback_custom_ops, sizeof(dJointFeedback), 0, 1);
  dJointSetFeedback (dJointID_val (joint), (dJointFeedback *) Data_custom_val(ml_jfb));
  CAMLreturn (ml_jfb);
}

CAMLprim value
ocamlode_dJointSetFeedback ( value joint )
{
  CAMLparam1 (joint);
  dJointFeedback * jfb;
  jfb = malloc (sizeof(dJointFeedback));
  if (jfb==NULL) caml_failwith("Out of memory");
  dJointSetFeedback (dJointID_val (joint), jfb);
  CAMLreturn ( (value) jfb );
}

CAMLprim value
ocamlode_dJointFeedbackBufferDestroy (value b)
{
  dJointFeedback * f = (dJointFeedback *) b;
  free (f);
  return Val_unit;
}

CAMLprim value
ocamlode_dJointGetFeedback (value joint)
{
  CAMLparam1 (joint);
  CAMLlocal1 (rv);
  dJointFeedback *f = dJointGetFeedback (dJointID_val (joint));
  rv = caml_alloc (4, 0);
  caml_modify (&Field (rv, 0), copy_dVector3 (f->f1));
  caml_modify (&Field (rv, 1), copy_dVector3 (f->t1));
  caml_modify (&Field (rv, 2), copy_dVector3 (f->f2));
  caml_modify (&Field (rv, 3), copy_dVector3 (f->t2));
  CAMLreturn (rv);
}

CAMLprim value
_ocamlode_dJointFeedback_of_buffer (value b)
{
  CAMLparam1 (b);
  CAMLlocal1 (rv);
  dJointFeedback * f = (dJointFeedback *) Data_custom_val(b);
  rv = caml_alloc (4, 0);
  caml_modify (&Field (rv, 0), copy_dVector3 (f->f1));
  caml_modify (&Field (rv, 1), copy_dVector3 (f->t1));
  caml_modify (&Field (rv, 2), copy_dVector3 (f->f2));
  caml_modify (&Field (rv, 3), copy_dVector3 (f->t2));
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dJointFeedback_of_buffer (value b)
{
  CAMLparam1 (b);
  CAMLlocal1 (rv);
  dJointFeedback * f = (dJointFeedback *) b;
  rv = caml_alloc (4, 0);
  caml_modify (&Field (rv, 0), copy_dVector3 (f->f1));
  caml_modify (&Field (rv, 1), copy_dVector3 (f->t1));
  caml_modify (&Field (rv, 2), copy_dVector3 (f->f2));
  caml_modify (&Field (rv, 3), copy_dVector3 (f->t2));
  CAMLreturn (rv);
}

/* }}} */
/* {{{ Space */

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
  CAMLparam4 (parentv, centerv, extentsv, depthv);
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
  if (Is_exception_result (rv)) {
    // XXX Can we do better than this?
    fprintf (stderr, "dSpaceCollide: callback raised exception: %s\n",
             caml_format_exception (Extract_exception (rv)));
    fflush (stderr);
  }
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
ocamlode_dSpaceCollide2 (value o1, value o2, value fv)
{
  CAMLparam3 (o1, o2, fv);
  value *fvp = &fv;
  dSpaceCollide2 (dGeomID_val (o1), dGeomID_val (o2), fvp, dSpaceCollide_callback);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dSpaceSetCleanup (value space, value mode)
{
  dSpaceSetCleanup (dSpaceID_val (space), Bool_val (mode));
  return Val_unit;
}

CAMLprim value
ocamlode_dSpaceGetCleanup (value space)
{
  return Val_bool (dSpaceGetCleanup (dSpaceID_val (space)));
}

CAMLprim value
ocamlode_dSpaceClean (value space)
{
  dSpaceClean (dSpaceID_val (space));
  return Val_unit;
}

CAMLprim value
ocamlode_dSpaceQuery (value space, value geom)
{
  return Val_bool (dSpaceQuery (dSpaceID_val (space), dGeomID_val (geom)));
}

CAMLprim value
ocamlode_dSpaceGetNumGeoms (value space)
{
  int num = dSpaceGetNumGeoms (dSpaceID_val (space));
  return Val_int (num);
}

CAMLprim value
ocamlode_dSpaceGetGeom (value space, value i)
{
  CAMLparam2 (space, i);
  dGeomID id = dSpaceGetGeom (dSpaceID_val (space), Int_val (i));
  CAMLreturn (Val_dGeomID (id));
}

CAMLprim value
ocamlode_dSpaceGetGeomsArray (value spacev)
{
  CAMLparam1 (spacev);
  CAMLlocal1 (ar);

  dSpaceID space = dSpaceID_val (spacev);
  int i;
  int num = dSpaceGetNumGeoms (space);

  ar = caml_alloc(num, 0);

  for (i=0; i<num; ++i)
  {
    dGeomID id = dSpaceGetGeom (space, i);
    Store_field (ar, i, Val_dGeomID (id));
  }

  CAMLreturn (ar);
}

/* }}} */
/* {{{ Geometry */

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
#if 0
  if (n == 0)
    caml_failwith("dCollide: no contacts");
#endif
  contactsv = caml_alloc (n, 0);
  int i;
  for (i = 0; i < n; ++i)
    caml_modify (&Field (contactsv, i), copy_dContactGeom (&contacts[i]));
  CAMLreturn (contactsv);
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
  dReal x = Double_val (xv);
  dReal y = Double_val (yv);
  dReal z = Double_val (zv);
  dGeomSetPosition (id, x, y, z);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dGeomSetRotation (value idv, value matrixv)
{
  CAMLparam2 (idv, matrixv);
  dGeomID id = dGeomID_val (idv);
#if defined(MEM_CPY) // dSINGLE
  dMatrix3 m;
  int i;
  for (i=0; i<12; ++i)
    m[i] = Double_field(matrixv,i);
  dGeomSetRotation (id, m);
#else // dDOUBLE
  dGeomSetRotation (id, (double *) matrixv);
#endif
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dGeomSetQuaternion (value idv, value quaternionv)
{
  CAMLparam2 (idv, quaternionv);
  dGeomID id = dGeomID_val (idv);
#if defined(MEM_CPY) // dSINGLE
  dQuaternion q;
  int i;
  for (i=0; i<4; ++i)
    q[i] = Double_field(quaternionv,i);
  dGeomSetQuaternion (id, q);
#else // dDOUBLE
  dGeomSetQuaternion (id, (double *) quaternionv);
#endif
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dGeomGetPosition (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dGeomID id = dGeomID_val (idv);
  const dReal *r = dGeomGetPosition (id);
  rv = copy_dReal_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dGeomGetRotation (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dGeomID id = dGeomID_val (idv);
  const dReal *r = dGeomGetRotation (id);
  rv = copy_dReal_array (r, 12);
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
  rv = copy_dReal_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dGeomGetAABB (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (aabbv);
  dGeomID id = dGeomID_val (idv);
  dReal aabb[6];
  dGeomGetAABB (id, aabb);
  aabbv = copy_dReal_array (aabb, 6);
  CAMLreturn (aabbv);
}

CAMLprim value
ocamlode_dInfiniteAABB (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (aabbv);
  dGeomID id = dGeomID_val (idv);
  dReal aabb[6];
  dInfiniteAABB (id, aabb);
  aabbv = copy_dReal_array (aabb, 6);
  CAMLreturn (aabbv);
}

/* Geometry Shapes */

CAMLprim value
ocamlode_dGeomGetClass (value geom)
{
  int geom_class = dGeomGetClass (dGeomID_val (geom));
  value ret;
  Val_dGeomClass(ret, geom_class);
  return ret;
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
  dReal radius = Double_val (radiusv);
  dGeomID id = dCreateSphere (parent, radius);
  CAMLreturn (Val_dGeomID (id));
}

CAMLprim value
ocamlode_dGeomSphereGetRadius (value idv)
{
  CAMLparam1 (idv);
  dGeomID id = dGeomID_val (idv);
  dReal radius = dGeomSphereGetRadius (id);
  CAMLreturn (caml_copy_double (radius));
}

CAMLprim value
ocamlode_dGeomSphereSetRadius (value idv, value radiusv)
{
  CAMLparam2 (idv, radiusv);
  dGeomID id = dGeomID_val (idv);
  dReal radius = Double_val (radiusv);
  dGeomSphereSetRadius (id, radius);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dGeomSpherePointDepth (value idv, value xv, value yv, value zv)
{
  CAMLparam4 (idv, xv, yv, zv);
  dGeomID id = dGeomID_val (idv);
  dReal x = Double_val (xv);
  dReal y = Double_val (yv);
  dReal z = Double_val (zv);
  dReal d =  dGeomSpherePointDepth (id, x, y, z);
  CAMLreturn (caml_copy_double (d));
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
  dReal lx = Double_val (lxv);
  dReal ly = Double_val (lyv);
  dReal lz = Double_val (lzv);
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
  rv = copy_dReal_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dGeomBoxSetLengths (value idv, value lxv, value lyv, value lzv)
{
  CAMLparam4 (idv, lxv, lyv, lzv);
  dGeomID id = dGeomID_val (idv);
  dReal lx = Double_val (lxv);
  dReal ly = Double_val (lyv);
  dReal lz = Double_val (lzv);
  dGeomBoxSetLengths (id, lx, ly, lz);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dGeomBoxPointDepth (value idv, value xv, value yv, value zv)
{
  CAMLparam4 (idv, xv, yv, zv);
  dGeomID id = dGeomID_val (idv);
  dReal x = Double_val (xv);
  dReal y = Double_val (yv);
  dReal z = Double_val (zv);
  dReal d = dGeomBoxPointDepth (id, x, y, z);
  CAMLreturn (caml_copy_double (d));
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
  dReal a = Double_val (av);
  dReal b = Double_val (bv);
  dReal c = Double_val (cv);
  dReal d = Double_val (dv);
  dGeomID id = dCreatePlane (parent, a, b, c, d);
  CAMLreturn (Val_dGeomID (id));
}

CAMLprim value
ocamlode_dGeomPlaneGetParams (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dGeomID id = dGeomID_val (idv);
  dVector4 r;
  dGeomPlaneGetParams (id, r);
  rv = copy_dReal_array (r, 4);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dGeomPlaneSetParams (value idv, value av, value bv, value cv, value dv)
{
  CAMLparam5 (idv, av, bv, cv, dv);
  dGeomID id = dGeomID_val (idv);
  dReal a = Double_val (av);
  dReal b = Double_val (bv);
  dReal c = Double_val (cv);
  dReal d = Double_val (dv);
  dGeomPlaneSetParams (id, a, b, c, d);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dGeomPlanePointDepth (value idv, value xv, value yv, value zv)
{
  CAMLparam4 (idv, xv, yv, zv);
  dGeomID id = dGeomID_val (idv);
  dReal x = Double_val (xv);
  dReal y = Double_val (yv);
  dReal z = Double_val (zv);
  dReal d = dGeomPlanePointDepth (id, x, y, z);
  CAMLreturn (caml_copy_double (d));
}

CAMLprim value
ocamlode_dCreateCapsule (value parentv, value radiusv, value lengthv)
{
  CAMLparam3 (parentv, radiusv, lengthv);
  dSpaceID parent;
  if (parentv == Val_int (0))	/* None */
    parent = 0;
  else				/* Some parent */
    parent = dSpaceID_val (Field (parentv, 0));
  dReal radius = Double_val (radiusv);
  dReal length = Double_val (lengthv);
  dGeomID id = dCreateCapsule (parent, radius, length);
  CAMLreturn (Val_dGeomID (id));
}

CAMLprim value
ocamlode_dGeomCapsuleGetParams (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dGeomID id = dGeomID_val (idv);
  dReal radius, length;
  dGeomCapsuleGetParams (id, &radius, &length);
  rv = caml_alloc(2, 0);
  Store_field (rv, 0, caml_copy_double (radius) );
  Store_field (rv, 1, caml_copy_double (length) );
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dGeomCapsuleSetParams (value idv, value radiusv, value lengthv)
{
  CAMLparam3 (idv, radiusv, lengthv);
  dGeomID id = dGeomID_val (idv);
  dReal radius = Double_val (radiusv);
  dReal length = Double_val (lengthv);
  dGeomCapsuleSetParams (id, radius, length);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dGeomCapsulePointDepth (value idv, value xv, value yv, value zv)
{
  CAMLparam4 (idv, xv, yv, zv);
  dGeomID id = dGeomID_val (idv);
  dReal x = Double_val (xv);
  dReal y = Double_val (yv);
  dReal z = Double_val (zv);
  dReal d = dGeomCapsulePointDepth (id, x, y, z);
  CAMLreturn (caml_copy_double (d));
}

CAMLprim value
ocamlode_dCreateCylinder (value parentv, value radiusv, value lengthv)
{
  CAMLparam3 (parentv, radiusv, lengthv);
  dSpaceID parent;
  if (parentv == Val_int (0))	/* None */
    parent = 0;
  else				/* Some parent */
    parent = dSpaceID_val (Field (parentv, 0));
  dReal radius = Double_val (radiusv);
  dReal length = Double_val (lengthv);
  dGeomID id = dCreateCylinder (parent, radius, length);
  CAMLreturn (Val_dGeomID (id));
}

CAMLprim value
ocamlode_dGeomCylinderGetParams (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dGeomID id = dGeomID_val (idv);
  dReal radius, length;
  dGeomCylinderGetParams (id, &radius, &length);
  rv = caml_alloc(2, 0);
  Store_field (rv, 0, caml_copy_double (radius) );
  Store_field (rv, 1, caml_copy_double (length) );
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dGeomCylinderSetParams (value idv, value radiusv, value lengthv)
{
  CAMLparam3 (idv, radiusv, lengthv);
  dGeomID id = dGeomID_val (idv);
  dReal radius = Double_val (radiusv);
  dReal length = Double_val (lengthv);
  dGeomCylinderSetParams (id, radius, length);
  CAMLreturn (Val_unit);
}


CAMLprim value
ocamlode_dCreateRay (value parentv, value lengthv)
{
  CAMLparam2 (parentv, lengthv);
  dSpaceID parent;
  if (parentv == Val_int (0))	/* None */
    parent = 0;
  else				/* Some parent */
    parent = dSpaceID_val (Field (parentv, 0));
  dReal length = Double_val (lengthv);
  dGeomID id = dCreateRay (parent, length);
  CAMLreturn (Val_dGeomID (id));
}

CAMLprim value
ocamlode_dGeomRaySetLength (value idv, value lengthv)
{
  CAMLparam2 (idv, lengthv);
  dGeomID id = dGeomID_val (idv);
  dReal length = Double_val (lengthv);
  dGeomRaySetLength (id, length);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dGeomRayGetLength (value idv)
{
  CAMLparam1 (idv);
  dGeomID id = dGeomID_val (idv);
  dReal length = dGeomRayGetLength (id);
  CAMLreturn (caml_copy_double (length));
}

CAMLprim value
ocamlode_dGeomRaySet_native (value ray, value px, value py, value pz, value dx, value dy, value dz)
{
  dGeomRaySet (dGeomID_val (ray), Double_val (px), Double_val (py), Double_val (pz),
                                  Double_val (dx), Double_val (dy), Double_val (dz));
  return Val_unit;
}
CAMLprim value
ocamlode_dGeomRaySet_bytecode (value * argv, int argn)
{
  return ocamlode_dGeomRaySet_native (argv[0], argv[1], argv[2],
                                      argv[3], argv[4], argv[5], argv[6]);
}

CAMLprim value
ocamlode_dGeomRayGet (value ray)
{
  CAMLparam1 (ray);
  CAMLlocal1 (rv);
  dVector3 start, dir;
  dGeomRayGet (dGeomID_val (ray), start, dir);
  rv = caml_alloc(2, 0);
  Store_field (rv, 0, copy_dVector3 (start));
  Store_field (rv, 1, copy_dVector3 (dir));
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dGeomRaySetParams (value idv, value FirstContact, value BackfaceCull)
{
  dGeomRaySetParams (dGeomID_val (idv), Bool_val (FirstContact), Bool_val (BackfaceCull));
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomRayGetParams (value idv)
{
  CAMLparam1 (idv);
  CAMLlocal1 (rv);
  dGeomID id = dGeomID_val (idv);
  int FirstContact, BackfaceCull;
  dGeomRayGetParams (id, &FirstContact, &BackfaceCull);
  rv = caml_alloc(2, 0);
  Store_field (rv, 0, Val_bool (FirstContact) );
  Store_field (rv, 1, Val_bool (BackfaceCull) );
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dGeomRaySetClosestHit (value idv, value closestHit)
{
  dGeomRaySetClosestHit (dGeomID_val (idv), Bool_val (closestHit));
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomRayGetClosestHit (value idv)
{
  return Val_bool (dGeomRayGetClosestHit (dGeomID_val (idv)));
}

/* TriMesh */

CAMLprim value
ocamlode_dGeomTriMeshDataCreate (value unit)
{
  CAMLparam0 ();
  dTriMeshDataID id = dGeomTriMeshDataCreate();
  /*
  CAMLreturn (Val_dTriMeshDataID (id));
  */
  CAMLreturn (Val_dTriMeshDataID_2 (id, NULL));
}

CAMLprim value
ocamlode_dGeomTriMeshDataDestroy (value idv)
{
  dTriMeshDataID id = dTriMeshDataID_val(idv);
  dGeomTriMeshDataDestroy (id);
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomTriMeshDataPreprocess (value idv)
{
  dTriMeshDataID id = dTriMeshDataID_val(idv);
  dGeomTriMeshDataPreprocess (id);
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomTriMeshSetData (value geom, value data)
{
  dGeomTriMeshSetData (dGeomID_val (geom), dTriMeshDataID_val (data));
  return Val_unit;
}

// TODO: what is the difference between 
//       dGeomTriMeshGetData() and dGeomTriMeshGetTriMeshDataID() ?

CAMLprim value
ocamlode_dGeomTriMeshGetData (value geom)
{
  CAMLparam1 (geom);
  dTriMeshDataID id = dGeomTriMeshGetData (dGeomID_val (geom));
  CAMLreturn (Val_dTriMeshDataID (id));
}

CAMLprim value
ocamlode_dGeomTriMeshGetTriMeshDataID (value geom)
{
  CAMLparam1 (geom);
  dTriMeshDataID id = dGeomTriMeshGetTriMeshDataID (dGeomID_val (geom));
  CAMLreturn (Val_dTriMeshDataID (id));
}

CAMLprim value
ocamlode_dGeomTriMeshDataUpdate (value idv)
{
  dTriMeshDataID id = dTriMeshDataID_val(idv);
  dGeomTriMeshDataUpdate (id);
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomTriMeshDataBuildDouble (value idv, value vertices, value indicesv)
{
  int *indices;
  int i, lenv, leni;
  dTriMeshDataID id = dTriMeshDataID_val(idv);

  lenv = Wosize_val(vertices) / Double_wosize;
  if ( (lenv % 3) != 0 )
    caml_invalid_argument ("vertices array length not multiple of 3");

  leni = Wosize_val (indicesv);
  if ( (leni % 3) != 0 )
    caml_invalid_argument ("indices array length not multiple of 3");

  indices = malloc (leni * sizeof(int));
  if (indices == NULL) caml_failwith("Out of memory");
  for (i=0; i < leni; i++)
  {
    indices[i] = Long_val(Field(indicesv, i));
  }

  dGeomTriMeshDataBuildDouble (id,
      (double *) vertices,
      3 * sizeof(double), 
      lenv / 3,
      indices,
      leni, 
      3 * sizeof(int) );

  // XXX ODE doesn't copy the datas but just keep a pointer to it,
  // so, the memory pointed by 'indices' have to be freed at some point.
  set_data2 (idv, indices);

  return Val_unit;
}

CAMLprim value
ocamlode_dCreateTriMesh_native (value parentv, value idv, value tri_cb, value arr_cb, value ray_cb, value unit)
{
  CAMLparam5 (parentv, idv, tri_cb, arr_cb, ray_cb);
  dSpaceID parent;
  if (parentv == Val_int (0))	/* None */
    parent = 0;
  else				/* Some parent */
    parent = dSpaceID_val (Field (parentv, 0));

  dTriMeshDataID data_id = dTriMeshDataID_val(idv);

  if (Is_block(tri_cb) || Is_block(arr_cb) || Is_block(ray_cb))
    caml_failwith("dCreateTriMesh: callbacks not yet implemented");

  dGeomID id = dCreateTriMesh (parent, data_id,
               0, 0, 0);
  /* TODO:     dTriCallback * Callback,
               dTriArrayCallback * ArrayCallback,
               dTriRayCallback * RayCallback); */

  CAMLreturn (Val_dGeomID (id));
}
CAMLprim value
ocamlode_dCreateTriMesh_bytecode (value * argv, int argn)
{
    return ocamlode_dCreateTriMesh_native (argv[0], argv[1], argv[2],
                                           argv[3], argv[4], argv[5]);
}
 
CAMLprim value
ocamlode_dGeomTriMeshEnableTC (value geom, value geomclassv, value enable)
{
  int geomClass;
  dGeomClass_val(geomClass, geomclassv);
  dGeomTriMeshEnableTC (dGeomID_val (geom), geomClass, Bool_val (enable));
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomTriMeshIsTCEnabled (value geom, value geomclassv)
{
  int geomClass;
  dGeomClass_val(geomClass, geomclassv);
  int ret = dGeomTriMeshIsTCEnabled (dGeomID_val (geom), geomClass);
  return Val_int (ret);
}

CAMLprim value
ocamlode_dGeomTriMeshClearTCCache (value geom)
{
  dGeomTriMeshClearTCCache (dGeomID_val (geom));
  return Val_unit;
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
ocamlode_dGeomTransformSetCleanup (value geom, value mode)
{
  dGeomTransformSetCleanup (dGeomID_val (geom), Long_val (mode));
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomTransformGetCleanup (value geom)
{
  return Val_bool (dGeomTransformGetCleanup (dGeomID_val (geom)));
}

CAMLprim value
ocamlode_dGeomTransformSetInfo (value geom, value mode)
{
  dGeomTransformSetInfo (dGeomID_val (geom), Long_val (mode));
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomTransformGetInfo (value geom)
{
  return Val_bool (dGeomTransformGetInfo (dGeomID_val (geom)));
}


/* Convex Geom */

typedef struct _dConvexDataID {
  unsigned int planecount;
  unsigned int pointcount;
  dReal *planes;
  dReal *points;
  unsigned int *polygons;
} dConvexDataID;

/*
 * The memory management of convex datas needs to be more tested
 * (until now no bugs found)
 */

void finalize_convexdata (value v)
{
  dReal *planes, *points;
  unsigned int *polygs;
  planes = ((dConvexDataID *) Data_custom_val (v))->planes;
  points = ((dConvexDataID *) Data_custom_val (v))->points;
  polygs = ((dConvexDataID *) Data_custom_val (v))->polygons;
  if (planes != NULL) { free (planes); planes = NULL; }
  if (points != NULL) { free (points); points = NULL; }
  if (polygs != NULL) { free (polygs); polygs = NULL; }
  fflush(stdout);
}

CAMLprim value
ocamlode_free_dConvexDataID (value v)
{
  finalize_convexdata (v);
  return Val_unit;
}

static struct custom_operations convexdata_custom_ops = {
  identifier: "ocamlode_dConvexDataID",
  finalize:  finalize_convexdata,
  compare:     custom_compare_default,
  hash:        custom_hash_default,
  serialize:   custom_serialize_default,
  deserialize: custom_deserialize_default
};


CAMLprim value
ocamlode_get_dConvexDataID (value planesv, value pointsv, value polygonesv)
{
  CAMLparam3 (planesv, pointsv, polygonesv);
  CAMLlocal1 (v);

  int i;
  unsigned int _planecount, _pointcount, polyscount;

  _planecount = Wosize_val(planesv) / Double_wosize;
  _pointcount = Wosize_val(pointsv) / Double_wosize;
  polyscount = Wosize_val(polygonesv);

  if (polyscount != (_planecount/4) * 5)
    caml_invalid_argument("dCreateConvex: wrong polygones number");

  dReal *_planes;
  dReal *_points;
  unsigned int *_polygons;

  _planes = malloc(_planecount * sizeof(dReal));
  if (_planes == NULL) {
    caml_failwith("Out of memory");
  }

  _points = malloc(_pointcount * sizeof(dReal));
  if (_points == NULL) {
    free (_planes);
    caml_failwith("Out of memory");
  }

  _polygons = malloc(polyscount * sizeof(int));
  if (_polygons == NULL) {
    free (_planes);
    free (_points);
    caml_failwith("Out of memory");
  }

  if (!_planes || !_points || !_polygons)
    caml_failwith("dCreateConvex: allocation error");

  for (i=0; i<_planecount; ++i) {
    _planes[i] = Double_field(planesv, i);
  }
  for (i=0; i<_pointcount; ++i) {
    _points[i] = Double_field(pointsv, i);
  }

  for (i=0; i<polyscount; ++i) {
    _polygons[i] = (unsigned int) (Long_val(Field(polygonesv, i)));
  }

  dConvexDataID d;
  d.planecount = _planecount / 4;
  d.pointcount = _pointcount / 3;
  d.planes = _planes;
  d.points = _points;
  d.polygons = _polygons;

  v = caml_alloc_custom (&convexdata_custom_ops, sizeof(dConvexDataID), 0, 1);
  memcpy (Data_custom_val(v), &d, sizeof(dConvexDataID));

  CAMLreturn (v);
}

CAMLprim value
ocamlode_dCreateConvex (value parentv, value convex_data)
{
  CAMLparam2 (parentv, convex_data);
  dSpaceID parent;
  if (parentv == Val_int (0))	/* None */
    parent = 0;
  else				/* Some parent */
    parent = dSpaceID_val (Field (parentv, 0));

  dConvexDataID * d = ((dConvexDataID *) Data_custom_val (convex_data));

  dGeomID id = dCreateConvex (parent,
                          d->planes, d->planecount,
                          d->points, d->pointcount,
                          d->polygons);

  CAMLreturn (Val_dGeomID (id));
}

CAMLprim value
ocamlode_dGeomSetConvex (value geom, value convex_data)
{
  CAMLparam2 (geom, convex_data);

  dConvexDataID * d = ((dConvexDataID *) Data_custom_val (convex_data));

  dGeomSetConvex (dGeomID_val (geom),
                    d->planes, d->planecount,
                    d->points, d->pointcount,
                    d->polygons);

  CAMLreturn (Val_unit);
}

#if 0
{{{ old version of dCreateConvex 

CAMLprim value
ocamlode_dCreateConvex (value parentv, value planesv, value pointsv, value polygonesv)
{
  CAMLparam4 (parentv, planesv, pointsv, polygonesv);
  dSpaceID parent;
  if (parentv == Val_int (0))	/* None */
    parent = 0;
  else				/* Some parent */
    parent = dSpaceID_val (Field (parentv, 0));

  int i;
  unsigned int planecount, pointcount, polyscount;

  planecount = Wosize_val(planesv) / Double_wosize;
  pointcount = Wosize_val(pointsv) / Double_wosize;
  polyscount = Wosize_val(polygonesv);

  if (polyscount != (planecount/4) * 5)
    caml_invalid_argument("dCreateConvex: wrong polygones number");

  dReal *_planes;
  dReal *_points;
  unsigned int *_polygons;

  _planes = malloc(planecount * sizeof(dReal));
  _points = malloc(pointcount * sizeof(dReal));
  _polygons = malloc(polyscount * sizeof(int));

  if (!_planes || !_points || !_polygons)
    caml_failwith("dCreateConvex: allocation error");

  for (i=0; i<planecount; ++i) {
    _planes[i] = Double_field(planesv, i);
  }
  for (i=0; i<pointcount; ++i) {
    _points[i] = Double_field(pointsv, i);
  }

  for (i=0; i<polyscount; ++i) {
    _polygons[i] = (unsigned int) (Long_val(Field(polygonesv, i)));
  }

  dGeomID id = dCreateConvex (parent,
                          _planes, (planecount/4),
                          _points, (pointcount/3),
                          _polygons);

  CAMLreturn (Val_dGeomID (id));
}
}}}
#endif

/*
 dGeomID dCreateConvex (dSpaceID space,
          dReal *_planes, unsigned int _planecount,
          dReal *_points, unsigned int _pointcount, unsigned int *_polygons);

 void dGeomSetConvex (dGeomID g,
        dReal *_planes, unsigned int _count,
        dReal *_points, unsigned int _pointcount,unsigned int *_polygons);
*/


/* Heightfield */

#define dHeightfieldDataID_val(v) ((dHeightfieldDataID)(v))
#define Val_dHeightfieldDataID(d) ((value)(d))

CAMLprim value
ocamlode_dGeomHeightfieldDataCreate(value u)
{
  dHeightfieldDataID d = dGeomHeightfieldDataCreate();
  return Val_dHeightfieldDataID(d);
}

CAMLprim value
ocamlode_dGeomHeightfieldDataDestroy(value hf_data_id)
{
  dGeomHeightfieldDataDestroy( dHeightfieldDataID_val(hf_data_id) );
  return Val_unit;
}

CAMLprim value
ocamlode_dCreateHeightfield(value parentv, value data, value placeable)
{
  CAMLparam3 (parentv, data, placeable);
  dSpaceID parent;
  if (parentv == Val_int (0))	/* None */
    parent = 0;
  else				/* Some parent */
    parent = dSpaceID_val (Field (parentv, 0));

  dGeomID id = dCreateHeightfield(parent, dHeightfieldDataID_val(data), Int_val(placeable));
  CAMLreturn (Val_dGeomID (id));
}

CAMLprim value
ocamlode_dGeomHeightfieldDataBuild(
          value hf_data_id,
          value pHeightDatav,
          value width, value depth,
          value widthSamples, value depthSamples,
          value scale, value offset, value thickness,
          value wrap )
{
  double* pHeightData;
#if defined(MEM_CPY)
  int i, len;
  len = Wosize_val(pHeightDatav) / Double_wosize;
  pHeightData = malloc( len * sizeof(double));
  for (i=0; i < len; i++)
    pHeightData[i] = Double_field(pHeightDatav, i);
#else
  pHeightData = (double *) pHeightDatav;
#endif
  dGeomHeightfieldDataBuildDouble(
                  dHeightfieldDataID_val(hf_data_id),
                  pHeightData,
                  1, // bCopyHeightData
                  Double_val(width), Double_val(depth),
                  Int_val(widthSamples), Int_val(depthSamples),
                  Double_val(scale), Double_val(offset), Double_val(thickness),
                  Int_val(wrap) );
#if defined(MEM_CPY)
  free(pHeightData);
#endif
  return Val_unit;
}
CAMLprim value
ocamlode_dGeomHeightfieldDataBuild_bytecode (value * argv, int argn)
{
  return ocamlode_dGeomHeightfieldDataBuild (argv[0], argv[1], argv[2],
                                             argv[3], argv[4], argv[5], argv[6], argv[7], argv[8], argv[9]);
}



/* OCaml integers are unboxed,
 * here it is set, and get back without convertions
 */
CAMLprim value
ocamlode_dGeomSetData (value geom, value data)
{
  dGeomSetData (dGeomID_val (geom), (void*) data);
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomGetData (value geom)
{
  return ((value) dGeomGetData (dGeomID_val (geom)));
}

CAMLprim value
ocamlode_dGeomIsSpace (value geom)
{
  return Val_bool (dGeomIsSpace (dGeomID_val (geom)));
}

CAMLprim value
ocamlode_dGeomGetSpace (value geom)
{
  dSpaceID id = dGeomGetSpace (dGeomID_val (geom));
  return Val_dSpaceID (id);
}

CAMLprim value
ocamlode_dGeomSetCategoryBits (value geom, value bits)
{
  dGeomSetCategoryBits (dGeomID_val (geom), Long_val (bits));
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomSetCollideBits (value geom, value bits)
{
  dGeomSetCollideBits (dGeomID_val (geom), Long_val (bits));
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomGetCategoryBits (value geom)
{
  return Val_long (dGeomGetCategoryBits (dGeomID_val (geom)));
}

CAMLprim value
ocamlode_dGeomGetCollideBits (value geom)
{
  return Val_long (dGeomGetCollideBits (dGeomID_val (geom)));
}

CAMLprim value
ocamlode_dGeomEnable (value geom)
{
  dGeomEnable (dGeomID_val (geom));
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomDisable (value geom)
{
  dGeomDisable (dGeomID_val (geom));
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomIsEnabled (value geom)
{
  return Val_bool (dGeomIsEnabled (dGeomID_val (geom)));
}

CAMLprim value
ocamlode_dGeomSetOffsetPosition (value geom, value x, value y, value z)
{
  dGeomSetOffsetPosition (dGeomID_val (geom), Double_val (x), Double_val (y), Double_val (z));
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomSetOffsetRotation (value geom, value matrixv)
{
  CAMLparam2 (geom, matrixv);
#if defined(MEM_CPY) // dSINGLE
  dMatrix3 m;
  int i;
  for (i=0; i<12; ++i)
    m[i] = Double_field(matrixv,i);
  dGeomSetOffsetRotation (dGeomID_val (geom), m);
#else // dDOUBLE
  dGeomSetOffsetRotation (dGeomID_val (geom), (double *) matrixv);
#endif
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dGeomSetOffsetQuaternion (value geomv, value Qv)
{
  dGeomID geom = dGeomID_val (geomv);
#if defined(MEM_CPY) // dSINGLE
  dQuaternion Q;
  int i;
  for (i=0; i<4; ++i)
    Q[i] = Double_field(Qv,i);
#else // dDOUBLE
  dReal * Q = (double *) Qv;
#endif
  dGeomSetOffsetQuaternion (geom, Q);
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomGetOffsetQuaternion (value geom)
{
  dQuaternion result;
  dGeomGetOffsetQuaternion (dGeomID_val (geom), result);
  return copy_dQuaternion (result);
}

CAMLprim value
ocamlode_dGeomSetOffsetWorldPosition (value geomv, value x, value y, value z)
{
  dGeomID geom = dGeomID_val (geomv);
  dGeomSetOffsetWorldPosition (geom, Double_val(x), Double_val(y), Double_val(z));
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomSetOffsetWorldRotation (value geomv, value Rv)
{
  dGeomID geom = dGeomID_val (geomv);
#if defined(MEM_CPY) // dSINGLE
  dMatrix3 R;
  int i;
  for (i=0; i<12; ++i)
    R[i] = Double_field(Rv,i);
#else // dDOUBLE
  dReal * R = (double *) Rv;
#endif
  dGeomSetOffsetWorldRotation (geom, R);
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomSetOffsetWorldQuaternion (value geomv, value qv)
{
  dGeomID geom = dGeomID_val (geomv);
#if defined(MEM_CPY) // dSINGLE
  dQuaternion q;
  int i;
  for (i=0; i<4; ++i)
    q[i] = Double_field(qv,i);
#else // dDOUBLE
  dReal * q = (double *) qv;
#endif
  dGeomSetOffsetWorldQuaternion (geom, q);
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomClearOffset (value geom)
{
  dGeomClearOffset (dGeomID_val (geom));
  return Val_unit;
}

CAMLprim value
ocamlode_dGeomIsOffset (value geom)
{
  int ret = dGeomIsOffset (dGeomID_val (geom));
  return Val_bool (ret);
}

CAMLprim value
ocamlode_dGeomCopyOffsetPosition (value geom)
{
  dVector3 pos;
  dGeomCopyOffsetPosition (dGeomID_val (geom), pos);
  return copy_dVector3 (pos);
}

CAMLprim value
ocamlode_dGeomCopyOffsetRotation (value geom)
{
  CAMLparam1 (geom);
  dMatrix3 R;
  dGeomCopyOffsetRotation (dGeomID_val (geom), R);
  CAMLreturn (copy_dMatrix3 (R));
}

CAMLprim value
ocamlode_dGeomGetOffsetPosition (value geom)
{
  const dReal *pos = dGeomGetOffsetPosition (dGeomID_val (geom));
  return copy_dVector3 (pos);
}

CAMLprim value
ocamlode_dGeomGetOffsetRotation (value geom)
{
  const dReal *rot = dGeomGetOffsetRotation (dGeomID_val (geom));
  return copy_dMatrix3 (rot);
}

/* }}} */
/* {{{ Mass functions */

CAMLprim value
ocamlode_dMassCreate (value unit)
{
  CAMLparam1 (unit);
  dMass mass;
  memset (&mass,0,sizeof(dMass));  // XXX is this necessary? 
  CAMLreturn (copy_dMass (&mass));
}

CAMLprim value
ocamlode_dMass_set_mass (value massv, value m)
{
  CAMLparam2 (massv, m);
  (dMass_data_custom_val (massv))->mass = Double_val(m);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMass_mass (value massv)
{
  CAMLparam1 (massv);
  CAMLreturn (caml_copy_double (dMass_data_custom_val (massv)->mass));
}

CAMLprim value
ocamlode_dMass_set_c (value massv, value cv)
{
  CAMLparam2 (massv, cv);
  dVector4_val (cv, (dMass_data_custom_val (massv))->c);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMass_c (value massv)
{
  CAMLparam1 (massv);
  CAMLlocal1 (cv);
  cv = copy_dVector4( (dMass_data_custom_val (massv))->c );
  CAMLreturn (cv);
}

CAMLprim value
ocamlode_dMass_set_I (value massv, value matrixv)
{
  CAMLparam2 (massv, matrixv);
#if defined(MEM_CPY) // dSINGLE
  dMass *mp = dMass_data_custom_val (massv);
  int i;
  for (i=0; i<12; ++i)
    mp->I[i] = Double_field(matrixv,i);
#else // dDOUBLE
  dMass *mp = dMass_data_custom_val (massv);
  memcpy (mp->I, (double *)matrixv, sizeof (dMatrix3));
#endif
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMass_I (value massv)
{
  CAMLparam1 (massv);
  CAMLlocal1 (rv);
  dMass *mp = dMass_data_custom_val (massv);
  rv = copy_dReal_array (mp->I, 12);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dMassSetZero (value massv)
{
  CAMLparam1 (massv);
  dMassSetZero (dMass_data_custom_val (massv));
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassSetParameters (value massv, value themassv, value cgxv, value cgyv, value cgzv,
                             value i11v, value i22v, value i33v, value i12v, value i13v, value i23v)
{
  CAMLparam1 (massv);
  //CAMLparam5 (massv, themassv, cgxv, cgyv, cgzv);
  //CAMLxparam5 (i11v, i22v, i33v, i12v, i13v);
  //CAMLxparam1 (i23v);
  dReal themass = Double_val (themassv);
  dReal cgx = Double_val (cgxv);
  dReal cgy = Double_val (cgyv);
  dReal cgz = Double_val (cgzv);
  dReal i11 = Double_val (i11v);
  dReal i22 = Double_val (i22v);
  dReal i33 = Double_val (i33v);
  dReal i12 = Double_val (i12v);
  dReal i13 = Double_val (i13v);
  dReal i23 = Double_val (i23v);
  dMassSetParameters (dMass_data_custom_val (massv), themass, cgx, cgy, cgz, i11, i22, i33, i12, i13, i23);
  CAMLreturn (Val_unit);
}
CAMLprim value
ocamlode_dMassSetParameters_bc (value * argv, int argn)
{
  return ocamlode_dMassSetParameters(argv[0], argv[1], argv[2], argv[3], argv[4],
                                     argv[5], argv[6], argv[7], argv[8], argv[9], argv[10]);
}

CAMLprim value
ocamlode_dMassSetSphere (value massv, value densityv, value radiusv)
{
  CAMLparam3 (massv, densityv, radiusv);
  dReal density = Double_val (densityv);
  dReal radius = Double_val (radiusv);
  dMassSetSphere (dMass_data_custom_val (massv), density, radius);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassSetSphereTotal (value massv, value total_massv, value radiusv)
{
  CAMLparam3 (massv, total_massv, radiusv);
  dReal total_mass = Double_val (total_massv);
  dReal radius = Double_val (radiusv);
  dMassSetSphereTotal (dMass_data_custom_val (massv), total_mass, radius);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassSetBox (value massv, value densityv, value lxv, value lyv, value lzv)
{
  CAMLparam5 (massv, densityv, lxv, lyv, lzv);
  dReal density = Double_val (densityv);
  dReal lx = Double_val (lxv);
  dReal ly = Double_val (lyv);
  dReal lz = Double_val (lzv);
  dMassSetBox (dMass_data_custom_val (massv), density, lx, ly, lz);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassSetBoxTotal (value massv, value total_massv, value lxv, value lyv, value lzv)
{
  CAMLparam5 (massv, total_massv, lxv, lyv, lzv);
  dReal total_mass = Double_val (total_massv);
  dReal lx = Double_val (lxv);
  dReal ly = Double_val (lyv);
  dReal lz = Double_val (lzv);
  dMassSetBoxTotal (dMass_data_custom_val (massv), total_mass, lx, ly, lz);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassSetCapsule (value massv, value densityv, value direction, value radiusv, value lengthv)
{
  CAMLparam5 (massv, densityv, direction, radiusv, lengthv);
  dReal density = Double_val (densityv);
  dReal radius = Double_val (radiusv);
  dReal length = Double_val (lengthv);
  dMassSetCapsule (dMass_data_custom_val (massv), density, Int_val(direction) + 1, radius, length);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassSetCapsuleTotal (value massv, value total_massv, value direction, value radiusv, value lengthv)
{
  CAMLparam5 (massv, total_massv, direction, radiusv, lengthv);
  dReal total_mass = Double_val (total_massv);
  dReal radius = Double_val (radiusv);
  dReal length = Double_val (lengthv);
  dMassSetCapsuleTotal (dMass_data_custom_val (massv), total_mass, Int_val(direction) + 1, radius, length);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassSetCylinder (value massv, value densityv, value direction, value radiusv, value lengthv)
{
  CAMLparam5 (massv, densityv, direction, radiusv, lengthv);
  dReal density = Double_val (densityv);
  dReal radius = Double_val (radiusv);
  dReal length = Double_val (lengthv);
  dMassSetCylinder (dMass_data_custom_val (massv), density, Int_val(direction) + 1, radius, length);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassSetCylinderTotal (value massv, value total_massv, value direction, value radiusv, value lengthv)
{
  CAMLparam5 (massv, total_massv, direction, radiusv, lengthv);
  dReal total_mass = Double_val (total_massv);
  dReal radius = Double_val (radiusv);
  dReal length = Double_val (lengthv);
  dMassSetCylinderTotal (dMass_data_custom_val (massv), total_mass, Int_val(direction) + 1, radius, length);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassSetTrimesh (value massv, value densityv, value idv)
{
  CAMLparam3 (massv, densityv, idv);
  dReal density = Double_val (densityv);
  dGeomID id = dGeomID_val (idv);
  dMassSetTrimesh (dMass_data_custom_val (massv), density, id);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassSetTrimeshTotal (value massv, value total_massv, value idv)
{
  CAMLparam3 (massv, total_massv, idv);
  dReal total_mass = Double_val (total_massv);
  dGeomID id = dGeomID_val (idv);
  dMassSetTrimeshTotal (dMass_data_custom_val (massv), total_mass, id);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassCheck(value massv)
{
  if (dMassCheck(dMass_data_custom_val (massv)) == 1) return Val_true; else return Val_false;
}

CAMLprim value
ocamlode_dMassAdjust (value massv, value newmassv)
{
  CAMLparam2 (massv, newmassv);
  dReal newmass = Double_val (newmassv);
  dMassAdjust (dMass_data_custom_val (massv), newmass);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassTranslate (value massv, value xv, value yv, value zv)
{
  CAMLparam4 (massv, xv, yv, zv);
  dReal x = Double_val (xv);
  dReal y = Double_val (yv);
  dReal z = Double_val (zv);
  dMassTranslate (dMass_data_custom_val (massv), x, y, z);
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassRotate (value massv, value rv)
{
  CAMLparam2 (massv, rv);
#if defined(MEM_CPY) // dSINGLE
  dMatrix3 r;
  int i;
  for (i=0; i<12; ++i)
    r[i] = Double_field(rv,i);
  dMassRotate (dMass_data_custom_val (massv), r);
#else // dDOUBLE
  dMassRotate (dMass_data_custom_val (massv), (double *) rv);
#endif
  CAMLreturn (Val_unit);
}

CAMLprim value
ocamlode_dMassAdd (value mass1v, value mass2v)
{
  CAMLparam2 (mass1v, mass2v);
  dMassAdd (dMass_data_custom_val (mass1v), dMass_data_custom_val (mass2v));
  CAMLreturn (Val_unit);
}

/* }}} */
/* {{{ Matrices */

CAMLprim value
ocamlode_dRSetIdentity (value unit)
{
  CAMLparam0();
  dMatrix3 m;
  dRSetIdentity (m);
  CAMLreturn (copy_dMatrix3 (m));
}

CAMLprim value
ocamlode_dRFromAxisAndAngle (value ax, value ay, value az, value angle)
{
  CAMLparam0();
  dMatrix3 m;
  dRFromAxisAndAngle (m, Double_val(ax), Double_val(ay), Double_val(az), Double_val(angle));
  CAMLreturn (copy_dMatrix3 (m));
}

CAMLprim value
ocamlode_dRFromEulerAngles (value phi, value theta, value psi)
{
  CAMLparam3 (phi, theta, psi);
  dMatrix3 m;
  dRFromEulerAngles (m, Double_val (phi), Double_val (theta), Double_val (psi));
  CAMLreturn (copy_dMatrix3 (m));
}

/*
 void dRFrom2Axes (dMatrix3 R, dReal ax, dReal ay, dReal az, dReal bx, dReal by, dReal bz);
 void dRFromZAxis (dMatrix3 R, dReal ax, dReal ay, dReal az);
*/

/* }}} */
/* {{{ Quaternion */

CAMLprim value
ocamlode_dQSetIdentity (value unit)
{
  CAMLparam0 ();
  CAMLlocal1 (rq);
  dQuaternion q;
  dQSetIdentity (q);
  rq = copy_dQuaternion (q);
  CAMLreturn (rq);
}

CAMLprim value
ocamlode_dQFromAxisAndAngle (value ax, value ay, value az, value angle)
{
  CAMLparam0 ();
  CAMLlocal1 (rq);
  dQuaternion q;
  dQFromAxisAndAngle (q, Double_val (ax), Double_val (ay), Double_val (az), Double_val (angle));
  rq = copy_dQuaternion (q);
  CAMLreturn (rq);
}

/*
 void dQMultiply0 (dQuaternion qa, const dQuaternion qb, const dQuaternion qc);
 void dQMultiply1 (dQuaternion qa, const dQuaternion qb, const dQuaternion qc);
 void dQMultiply2 (dQuaternion qa, const dQuaternion qb, const dQuaternion qc);
 void dQMultiply3 (dQuaternion qa, const dQuaternion qb, const dQuaternion qc);

 void dRfromQ (dMatrix3 R, const dQuaternion q);
 void dQfromR (dQuaternion q, const dMatrix3 R);
 void dDQfromW (dReal dq[4], const dVector3 w, const dQuaternion q);
*/

/* }}} */
/* {{{ Misc */

CAMLprim value
ocamlode_dWorldImpulseToForce (value worldv, value stepsizev, value ixv, value iyv, value izv)
{
  CAMLparam5 (worldv, stepsizev, ixv, iyv, izv);
  CAMLlocal1 (fv);
  dWorldID world = dWorldID_val (worldv);
  dReal stepsize = Double_val(stepsizev);
  dReal ix = Double_val(ixv);
  dReal iy = Double_val(iyv);
  dReal iz = Double_val(izv);
  dVector3 f;
  dWorldImpulseToForce (world, stepsize, ix, iy, iz, f);
  fv = copy_dReal_array (f, 4);
  CAMLreturn (fv);
}

CAMLprim value
ocamlode_dQtoR (value qv)
{
#if defined(MEM_CPY) // dSINGLE
  CAMLparam1 (qv);
  dQuaternion q;
  dMatrix3 r;
  dQuaternion_val (qv, q);
  dQtoR (q, r);
  CAMLreturn (copy_dMatrix3 (r));
#else // dDOUBLE
  dMatrix3 r;
  dQtoR ((double *)qv, r);
  return copy_dMatrix3 (r);
#endif
}

CAMLprim value
ocamlode_dPlaneSpace (value nv)
{
#if defined(MEM_CPY) // dSINGLE
  CAMLparam1 (nv);
  CAMLlocal1 (rv);
  dVector3 n, p, q;
  dVector3_val (nv, n);
  dPlaneSpace (n, p, q);
  rv = caml_alloc(2, 0);
  Store_field (rv, 0, copy_dVector3 (p));
  Store_field (rv, 1, copy_dVector3 (q));
  CAMLreturn (rv);
#else // dDOUBLE
  CAMLparam1 (nv);
  CAMLlocal1 (rv);
  dVector3 p, q;
  dPlaneSpace ((double *) nv, p, q);
  rv = caml_alloc(2, 0);
  Store_field (rv, 0, copy_dVector3 (p));
  Store_field (rv, 1, copy_dVector3 (q));
  CAMLreturn (rv);
#endif
}

#if 0
#include <ode/export-dif.h>

CAMLprim value
ocamlode_dWorldExportDIF (value worldv, value filenamev, value world_name)
{
  CAMLparam3 (worldv, filenamev, world_name);
  char *filename = String_val (filenamev);
  FILE *f;
  int do_close;

  if (strncmp (filename, "stdout", 8) == 0) {
    f = stdout;
    do_close = 0;
  } else
  if (strncmp (filename, "stderr", 8) == 0) {
    f = stderr;
    do_close = 0;
  } else {
    f = fopen (filename,"wt");
    do_close = 1;
  }

  if (f) {
    dWorldID world = dWorldID_val (worldv);
    dWorldExportDIF (world, f, String_val (world_name));
    if (do_close) fclose (f);
  } else {
    caml_failwith ("dWorldExportDIF: fail to open file");
  }
  CAMLreturn (Val_unit);
}
#endif

CAMLprim value
ocamlode_dSafeNormalize3 (value vecv)
{
  CAMLparam1 (vecv);
  CAMLlocal1 (rv);
  dVector3 vec;
  dVector3_val (vecv, vec);
  dSafeNormalize3 (vec);
  rv = copy_dVector3 (vec);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dSafeNormalize4 (value vecv)
{
  CAMLparam1 (vecv);
  CAMLlocal1 (rv);
  dVector4 vec;
  dVector4_val (vecv, vec);
  dSafeNormalize4 (vec);
  rv = copy_dVector4 (vec);
  CAMLreturn (rv);
}

CAMLprim value
ocamlode_dMaxDifference (value Av, value Bv, value n, value m)
{
#if defined(MEM_CPY) // dSINGLE
  CAMLparam4 (Av, Bv, n, m);
  dVector3 A, B;
  dVector3_val (Av, A);
  dVector3_val (Bv, B);
  dReal ret = dMaxDifference (A, B, Int_val (n), Int_val (m));
  CAMLreturn (caml_copy_double (ret));
#else // dDOUBLE
  dReal ret = dMaxDifference ((double *)Av, (double *)Bv, Int_val (n), Int_val (m));
  return caml_copy_double (ret);
#endif
}

CAMLprim value
ocamlode_dMultiply0 (value Bv, value Cv, value pv, value qv, value rv)
{
  CAMLparam5 (Bv, Cv, pv, qv, rv);
  CAMLlocal1 (fv);
  int p = Int_val(pv); // 3
  int q = Int_val(qv); // 3
  int r = Int_val(rv); // 1
  dReal *A;
  A = malloc (p*r * sizeof(dReal));
#if defined(MEM_CPY) // dSINGLE
  int i, len;
  dReal *B, *C;

  len = Wosize_val(Bv) / Double_wosize;
  //assert (len == (p*q));
  B = malloc (len * sizeof(dReal));
  for (i=0; i < len; ++i)
  {
    B[i] = Double_field(Bv,i);
  }

  len = Wosize_val(Cv) / Double_wosize;
  //assert (len == (q*r));
  C = malloc (len * sizeof(dReal));
  for (i=0; i < len; ++i)
  {
    C[i] = Double_field(Cv,i);
  }

  dMultiply0 (A, B, C, p, q, r);
  free (B);
  free (C);
#else // dDOUBLE
  dMultiply0 (A, (double *)Bv, (double *)Cv, p, q, r);
#endif
  fv = copy_dReal_array (A, p*r);
  free (A);
  CAMLreturn (fv);
}

CAMLprim value
ocamlode_memory_share (value unit)
{
#if defined(MEM_CPY)
  return Val_false;
#else
  return Val_true;
#endif
}

/* }}} */

/* {{{ List of functions not wrapped yet 

typedef void dMessageFunction (int errnum, const char *msg, va_list ap);
 void dSetErrorHandler (dMessageFunction *fn);
 void dSetDebugHandler (dMessageFunction *fn);
 void dSetMessageHandler (dMessageFunction *fn);
 dMessageFunction *dGetErrorHandler(void);
 dMessageFunction *dGetDebugHandler(void);
 dMessageFunction *dGetMessageHandler(void);
 void dError (int num, const char *msg, ...);
 void dDebug (int num, const char *msg, ...);
 void dMessage (int num, const char *msg, ...);

typedef dReal dVector3[4];
typedef dReal dVector4[4];
typedef dReal dMatrix3[4*3];
typedef dReal dMatrix4[4*4];
typedef dReal dMatrix6[8*6];
typedef dReal dQuaternion[4];

struct dxWorld;
struct dxSpace;
struct dxBody;
struct dxGeom;
struct dxJoint;
struct dxJointNode;
struct dxJointGroup;

typedef struct dxWorld *dWorldID;
typedef struct dxSpace *dSpaceID;
typedef struct dxBody *dBodyID;
typedef struct dxGeom *dGeomID;
typedef struct dxJoint *dJointID;
typedef struct dxJointGroup *dJointGroupID;
enum {
  d_ERR_UNKNOWN = 0,
  d_ERR_IASSERT,
  d_ERR_UASSERT,
  d_ERR_LCP
};

enum{
  dAMotorUser = 0,
  dAMotorEuler = 1
};

// joint force feedback information
typedef struct dJointFeedback {
  dVector3 f1;      // force applied to body 1
  dVector3 t1;      // torque applied to body 1
  dVector3 f2;      // force applied to body 2
  dVector3 t2;      // torque applied to body 2
} dJointFeedback;



void dGeomMoved (dGeomID);
dGeomID dGeomGetBodyNext (dGeomID);




typedef struct dSurfaceParameters {
  int mode;
  dReal mu;
  dReal mu2;
  dReal bounce;
  dReal bounce_vel;
  dReal soft_erp;
  dReal soft_cfm;
  dReal motion1,motion2;
  dReal slip1,slip2;
} dSurfaceParameters;

typedef struct dContactGeom {
  dVector3 pos;
  dVector3 normal;
  dReal depth;
  dGeomID g1,g2;
  int side1,side2;
} dContactGeom;

typedef struct dContact {
  dSurfaceParameters surface;
  dContactGeom geom;
  dVector3 fdir1;
} dContact;
typedef void * dAllocFunction (size_t size);
typedef void * dReallocFunction (void *ptr, size_t oldsize, size_t newsize);
typedef void dFreeFunction (void *ptr, size_t size);

 void dSetAllocHandler (dAllocFunction *fn);
 void dSetReallocHandler (dReallocFunction *fn);
 void dSetFreeHandler (dFreeFunction *fn);
 dAllocFunction *dGetAllocHandler (void);
 dReallocFunction *dGetReallocHandler (void);
 dFreeFunction *dGetFreeHandler (void);
 void * dAlloc (size_t size);
 void * dRealloc (void *ptr, size_t oldsize, size_t newsize);
 void dFree (void *ptr, size_t size);

 void dNormalize3 (dVector3 a);
 void dNormalize4 (dVector4 a);

 void dSetZero (dReal *a, int n);
 void dSetValue (dReal *a, int n, dReal value);
 dReal dDot (const dReal *a, const dReal *b, int n);

 void dMultiply0 (dReal *A, const dReal *B, const dReal *C, int p,int q,int r);
 void dMultiply1 (dReal *A, const dReal *B, const dReal *C, int p,int q,int r);
 void dMultiply2 (dReal *A, const dReal *B, const dReal *C, int p,int q,int r);

 int dFactorCholesky (dReal *A, int n);
 void dSolveCholesky (const dReal *L, dReal *b, int n);

 int dInvertPDMatrix (const dReal *A, dReal *Ainv, int n);

 int dIsPositiveDefinite (const dReal *A, int n);

 void dFactorLDLT (dReal *A, dReal *d, int n, int nskip);
 void dSolveL1 (const dReal *L, dReal *b, int n, int nskip);
 void dSolveL1T (const dReal *L, dReal *b, int n, int nskip);
 void dVectorScale (dReal *a, const dReal *d, int n);

 void dSolveLDLT (const dReal *L, const dReal *d, dReal *b, int n, int nskip);

 void dLDLTAddTL (dReal *L, dReal *d, const dReal *a, int n, int nskip);

 void dLDLTRemove (dReal **A, const int *p, dReal *L, dReal *d, int n1, int n2, int r, int nskip);
 void dRemoveRowCol (dReal *A, int n, int nskip, int r);

typedef struct dStopwatch {
  double time;
  unsigned long cc[2];
} dStopwatch;

 void dStopwatchReset (dStopwatch *);
 void dStopwatchStart (dStopwatch *);
 void dStopwatchStop (dStopwatch *);
 double dStopwatchTime (dStopwatch *);
 void dTimerStart (const char *description);
 void dTimerNow (const char *description);
 void dTimerEnd(void);

 void dTimerReport (FILE *fout, int average);

 double dTimerTicksPerSecond(void);
 double dTimerResolution(void);


 int dTestRand(void);
 unsigned long dRand(void);
 unsigned long dRandGetSeed(void);
 void dRandSetSeed (unsigned long s);
 int dRandInt (int n);
 dReal dRandReal(void);
 void dPrintMatrix (const dReal *A, int n, int m, char *fmt, FILE *f);

 void dMakeRandomVector (dReal *A, int n, dReal range);
 void dMakeRandomMatrix (dReal *A, int n, int m, dReal range);
 void dClearUpperTriangle (dReal *A, int n);

 dReal dMaxDifferenceLowerTriangle (const dReal *A, const dReal *B, int n);



 void dBodyCopyPosition (dBodyID body, dVector3 pos);
 void dBodyCopyRotation (dBodyID, dMatrix3 R);
 void dBodyCopyQuaternion(dBodyID body, dQuaternion quat);




struct dContactGeom;

typedef void dNearCallback (void *data, dGeomID o1, dGeomID o2);



 void dGeomCopyPosition (dGeomID geom, dVector3 pos);
 void dGeomCopyRotation(dGeomID geom, dMatrix3 R);



enum {
  dMaxUserClasses = 4
};
enum {
  dSphereClass = 0,
  dBoxClass,
  dCapsuleClass,
  dCylinderClass,
  dPlaneClass,
  dRayClass,
  dConvexClass,
  dGeomTransformClass,
  dTriMeshClass,
  dHeightfieldClass,

  dFirstSpaceClass,
  dSimpleSpaceClass = dFirstSpaceClass,
  dHashSpaceClass,
  dQuadTreeSpaceClass,
  dLastSpaceClass = dQuadTreeSpaceClass,

  dFirstUserClass,
  dLastUserClass = dFirstUserClass + dMaxUserClasses - 1,
  dGeomNumClasses
};




struct dxTriMeshData;
typedef struct dxTriMeshData* dTriMeshDataID;
enum { TRIMESH_FACE_NORMALS };
 void dGeomTriMeshDataSet(dTriMeshDataID g, int data_id, void* in_data);
 void* dGeomTriMeshDataGet(dTriMeshDataID g, int data_id);

 void dGeomTriMeshSetLastTransform( dGeomID g, dMatrix4 last_trans );
 dReal* dGeomTriMeshGetLastTransform( dGeomID g );

 void dGeomTriMeshDataBuildSingle1(dTriMeshDataID g,
                                  const void* Vertices, int VertexStride, int VertexCount,
                                  const void* Indices, int IndexCount, int TriStride,
                                  const void* Normals);

 void dGeomTriMeshDataBuildDouble1(dTriMeshDataID g,
                                  const void* Vertices, int VertexStride, int VertexCount,
                                  const void* Indices, int IndexCount, int TriStride,
                                  const void* Normals);

 void dGeomTriMeshDataBuildSimple(dTriMeshDataID g,
                                 const dReal* Vertices, int VertexCount,
                                 const int* Indices, int IndexCount);

 void dGeomTriMeshDataBuildSimple1(dTriMeshDataID g,
                                  const dReal* Vertices, int VertexCount,
                                  const int* Indices, int IndexCount,
                                  const int* Normals);

 void dGeomTriMeshDataGetBuffer(dTriMeshDataID g, unsigned char** buf, int* bufLen);
 void dGeomTriMeshDataSetBuffer(dTriMeshDataID g, unsigned char* buf);
typedef int dTriCallback(dGeomID TriMesh, dGeomID RefObject, int TriangleIndex);
 void dGeomTriMeshSetCallback(dGeomID g, dTriCallback* Callback);
 dTriCallback* dGeomTriMeshGetCallback(dGeomID g);
typedef void dTriArrayCallback(dGeomID TriMesh, dGeomID RefObject, const int* TriIndices, int TriCount);
 void dGeomTriMeshSetArrayCallback(dGeomID g, dTriArrayCallback* ArrayCallback);
 dTriArrayCallback* dGeomTriMeshGetArrayCallback(dGeomID g);

typedef int dTriRayCallback(dGeomID TriMesh, dGeomID Ray, int TriangleIndex, dReal u, dReal v);
 void dGeomTriMeshSetRayCallback(dGeomID g, dTriRayCallback* Callback);
 dTriRayCallback* dGeomTriMeshGetRayCallback(dGeomID g);



 void dGeomTriMeshGetTriangle(dGeomID g, int Index, dVector3* v0, dVector3* v1, dVector3* v2);
 void dGeomTriMeshGetPoint(dGeomID g, int Index, dReal u, dReal v, dVector3 Out);
 int dGeomTriMeshGetTriangleCount (dGeomID g);




struct dxHeightfieldData;
typedef struct dxHeightfieldData* dHeightfieldDataID;

typedef dReal dHeightfieldGetHeight( void* p_user_data, int x, int z );


 void dGeomHeightfieldDataBuildCallback( dHeightfieldDataID d,
    void* pUserData, dHeightfieldGetHeight* pCallback,
    dReal width, dReal depth, int widthSamples, int depthSamples,
    dReal scale, dReal offset, dReal thickness, int bWrap );


 void dGeomHeightfieldDataBuildByte( dHeightfieldDataID d,
    const unsigned char* pHeightData, int bCopyHeightData,
    dReal width, dReal depth, int widthSamples, int depthSamples,
    dReal scale, dReal offset, dReal thickness, int bWrap );

 void dGeomHeightfieldDataBuildShort( dHeightfieldDataID d,
    const short* pHeightData, int bCopyHeightData,
    dReal width, dReal depth, int widthSamples, int depthSamples,
    dReal scale, dReal offset, dReal thickness, int bWrap );

 void dGeomHeightfieldDataBuildSingle( dHeightfieldDataID d,
    const float* pHeightData, int bCopyHeightData,
    dReal width, dReal depth, int widthSamples, int depthSamples,
    dReal scale, dReal offset, dReal thickness, int bWrap );

 void dGeomHeightfieldDataBuildDouble( dHeightfieldDataID d,
    const double* pHeightData, int bCopyHeightData,
    dReal width, dReal depth, int widthSamples, int depthSamples,
    dReal scale, dReal offset, dReal thickness, int bWrap );


 void dGeomHeightfieldDataSetBounds( dHeightfieldDataID d,
    dReal minHeight, dReal maxHeight );

 void dGeomHeightfieldSetHeightfieldData( dGeomID g, dHeightfieldDataID d );

 dHeightfieldDataID dGeomHeightfieldGetHeightfieldData( dGeomID g );


 void dClosestLineSegmentPoints (const dVector3 a1, const dVector3 a2,
    const dVector3 b1, const dVector3 b2,
    dVector3 cp1, dVector3 cp2);

 int dBoxTouchesBox (const dVector3 _p1, const dMatrix3 R1,
      const dVector3 side1, const dVector3 _p2,
      const dMatrix3 R2, const dVector3 side2);

 int dBoxBox (const dVector3 p1, const dMatrix3 R1,
      const dVector3 side1, const dVector3 p2,
      const dMatrix3 R2, const dVector3 side2,
      dVector3 normal, dReal *depth, int *return_code,
      int maxc, dContactGeom *contact, int skip);



typedef void dGetAABBFn (dGeomID, dReal aabb[6]);
typedef int dColliderFn (dGeomID o1, dGeomID o2,
    int flags, dContactGeom *contact, int skip);
typedef dColliderFn * dGetColliderFnFn (int num);
typedef void dGeomDtorFn (dGeomID o);
typedef int dAABBTestFn (dGeomID o1, dGeomID o2, dReal aabb[6]);

typedef struct dGeomClass {
  int bytes;
  dGetColliderFnFn *collider;
  dGetAABBFn *aabb;
  dAABBTestFn *aabb_test;
  dGeomDtorFn *dtor;
} dGeomClass;

 int dCreateGeomClass (const dGeomClass *classptr);
 void * dGeomGetClassData (dGeomID);
 dGeomID dCreateGeom (int classnum);

}}} */
// vim: fdm=marker
