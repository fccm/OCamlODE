(* OCaml bindings for the Open Dynamics Engine (ODE).
 * By Richard W.M. Jones <rich@annexia.org>
 * $Id: ode.mli,v 1.1 2005/06/24 18:15:29 rich Exp $
 *)

module LowLevel : sig
  (* Opaque types of ODE objects. *)
  type dWorldID
  type dSpaceID
  type dBodyID
  type dGeomID
  type dJointID
  type dJointGroupID
  type dMass

  (* Note: These structures are binary-compatible with the ODE
   * definitions, provided that the ODE library was compiled with
   * dDOUBLE.
   *)
  (* Note 2: Despite the name, dVector3 has 4 elements (see <ode/common.h>). *)
  type dVector3 = { x : float; y : float; z : float; w : float }
  type dVector4 = dVector3
  type dMatrix3 = { r11 : float; r12 : float; r13 : float; r14 : float;
		    r21 : float; r22 : float; r23 : float; r24 : float;
		    r31 : float; r32 : float; r33 : float; r34 : float }
  type dMatrix4 = { s11 : float; s12 : float; s13 : float; s14 : float;
		    s21 : float; s22 : float; s23 : float; s24 : float;
		    s31 : float; s32 : float; s33 : float; s34 : float;
		    s41 : float; s42 : float; s43 : float; s44 : float }
  type dMatrix6 = {
    t11 : float; t12 : float; t13 : float; t14 : float; t15 : float; t16 : float; t17 : float; t18 : float;
    t21 : float; t22 : float; t23 : float; t24 : float; t25 : float; t26 : float; t27 : float; t28 : float;
    t31 : float; t32 : float; t33 : float; t34 : float; t35 : float; t36 : float; t37 : float; t38 : float;
    t41 : float; t42 : float; t43 : float; t44 : float; t45 : float; t46 : float; t47 : float; t48 : float;
    t51 : float; t52 : float; t53 : float; t54 : float; t55 : float; t56 : float; t57 : float; t58 : float;
    t61 : float; t62 : float; t63 : float; t64 : float; t65 : float; t66 : float; t67 : float; t68 : float
  }
  type dQuaternion = { q1 : float; q2 : float; q3 : float; q4 : float }

  (* Contact points. *)
  type dContactGeom = {
    cg_pos : dVector3;
    cg_normal : dVector3;
    cg_depth : float;
    cg_g1 : dGeomID;
    cg_g2 : dGeomID;
  }

  (* Contact structure. *)
  type dContact = {
    c_surface : dSurfaceParameters;
    c_geom : dContactGeom;
    c_fdir1 : dVector3;
  }
  and dSurfaceParameters = {
    sp_mode : [ `dContactMu2 | `dContactFDir1 | `dContactBounce |
		`dContactSoftERP | `dContactSoftCFM |
		`dContactMotion1 | `dContactMotion2 |
		`dContactSlip1 | `dContactSlip2 |
		`dContactApprox1_1 | `dContactApprox1_2 |
		`dContactApprox1 ] list;
    sp_mu : float;
    sp_mu2 : float;
    sp_bounce : float;
    sp_bounce_vel : float;
    sp_soft_erp : float;
    sp_soft_cfm : float;
    sp_motion1 : float;
    sp_motion2 : float;
    sp_slip1 : float;
    sp_slip2 : float;
  }

  type dJointParam =
    | DParamLoStop
    | DParamHiStop
    | DParamVel
    | DParamFMax
    | DParamFudgeFactor
    | DParamBounce
    | DParamCFM
    | DParamStopERP
    | DParamStopCFM
    | DParamSuspensionERP
    | DParamSuspensionCFM

  val dInfinity : float

  (* World. *)
  val dWorldCreate : unit -> dWorldID
  val dWorldDestroy : dWorldID -> unit
  val dWorldSetGravity : dWorldID -> x:float -> y:float -> z:float -> unit

  val dCloseODE : unit -> unit
  val dWorldStep : dWorldID -> float -> unit
  val dWorldQuickStep : dWorldID -> float -> unit
(*
  val dWorldSetQuickStepNumIterations : dWorldID -> int -> unit
  val dWorldGetQuickStepNumIterations : dWorldID -> int
*)

  (* Bodies. *)
  val dBodyCreate : dWorldID -> dBodyID
  val dBodyDestroy : dBodyID -> unit
(*
  val dBodySetPosition : dBodyID -> x:float -> y:float -> z:float -> unit
  val dBodySetRotation : dBodyID -> dMatrix3 -> unit
  val dBodySetQuaternion : dBodyID -> dQuaternion -> unit
  val dBodySetLinearVel : dBodyID -> x:float -> y:float -> z:float -> unit
  val dBodySetAngularVel : dBodyID -> x:float -> y:float -> z:float -> unit
*)
  val dBodyGetPosition : dBodyID -> dVector3
  val dBodyGetRotation : dBodyID -> dMatrix3
  val dBodyGetQuaternion : dBodyID -> dQuaternion
  val dBodyGetLinearVel : dBodyID -> dVector3
  val dBodyGetAngularVel : dBodyID -> dVector3
  val dBodySetMass : dBodyID -> dMass -> unit
  val dBodyGetMass : dBodyID -> dMass

  val dBodyAddForce : dBodyID -> fx:float -> fy:float -> fz:float -> unit
  val dBodyAddTorque : dBodyID -> fx:float -> fy:float -> fz:float -> unit
  val dBodyAddRelForce : dBodyID -> fx:float -> fy:float -> fz:float -> unit
  val dBodyAddRelTorque : dBodyID -> fx:float -> fy:float -> fz:float -> unit

  val dBodyGetRelPointPos : dBodyID -> px:float -> py:float -> pz:float -> dVector3
  val dBodyGetPosRelPoint : dBodyID -> px:float -> py:float -> pz:float -> dVector3

  val dBodyEnable : dBodyID -> unit
  val dBodyDisable : dBodyID -> unit
  val dBodyIsEnabled : dBodyID -> bool
  val dBodySetAutoDisableFlag : dBodyID -> bool -> unit
  val dBodyGetAutoDisableFlag : dBodyID -> bool

  (* Joints. *)
  val dJointCreateBall : dWorldID -> dJointGroupID option -> dJointID
  val dJointCreateHinge : dWorldID -> dJointGroupID option -> dJointID
  val dJointCreateSlider : dWorldID -> dJointGroupID option -> dJointID
  val dJointCreateContact : dWorldID -> dJointGroupID option -> dContact -> dJointID
  val dJointCreateUniversal : dWorldID -> dJointGroupID option -> dJointID
  val dJointCreateHinge2 : dWorldID -> dJointGroupID option -> dJointID
  val dJointCreateFixed : dWorldID -> dJointGroupID option -> dJointID
  val dJointCreateAMotor : dWorldID -> dJointGroupID option -> dJointID
  val dJointDestroy : dJointID -> unit

  val dJointGroupCreate : unit -> dJointGroupID
  val dJointGroupDestroy : dJointGroupID -> unit
  val dJointGroupEmpty : dJointGroupID -> unit

  val dJointAttach : dJointID -> dBodyID option -> dBodyID option -> unit

  val dJointSetSliderAxis : dJointID -> x:float -> y:float -> z:float -> unit
  val dJointGetSliderAxis : dJointID -> dVector3
  val dJointGetSliderPosition: dJointID -> float
  val dJointGetSliderPositionRate : dJointID -> float

  val dJointSetHingeParam : dJointID -> dJointParam -> float -> unit
  val dJointSetSliderParam : dJointID -> dJointParam -> float -> unit
  val dJointSetHinge2Param : dJointID -> dJointParam -> float -> unit
  val dJointSetUniversalParam : dJointID -> dJointParam -> float -> unit
  val dJointSetAMotorParam : dJointID -> dJointParam -> float -> unit
  val dJointGetHingeParam : dJointID -> dJointParam -> float
  val dJointGetSliderParam : dJointID -> dJointParam -> float
  val dJointGetHinge2Param : dJointID -> dJointParam -> float
  val dJointGetUniversalParam : dJointID -> dJointParam -> float
  val dJointGetAMotorParam : dJointID -> dJointParam -> float

  (* Geometry. *)
  val dGeomDestroy : dGeomID -> unit
  val dGeomSetBody : dGeomID -> dBodyID option -> unit
  val dGeomGetBody : dGeomID -> dBodyID option
  val dGeomSetPosition : dGeomID -> x:float -> y:float -> z:float -> unit
  val dGeomSetRotation : dGeomID -> dMatrix3 -> unit
  val dGeomSetQuaternion : dGeomID -> dQuaternion -> unit
  val dGeomGetPosition : dGeomID -> dVector3
  val dGeomGetRotation : dGeomID -> dMatrix3
  val dGeomGetQuaternion : dGeomID -> dQuaternion

  val dCollide : dGeomID -> dGeomID -> max:int -> dContactGeom array
  val dSpaceCollide : dSpaceID -> (dGeomID -> dGeomID -> unit) -> unit

  val dSimpleSpaceCreate : dSpaceID option -> dSpaceID
  val dHashSpaceCreate : dSpaceID option -> dSpaceID
  val dQuadTreeSpaceCreate : dSpaceID option ->
    center:dVector3 -> extents:dVector3 -> depth:int -> dSpaceID
  val dSpaceDestroy : dSpaceID -> unit
  val dHashSpaceSetLevels : dSpaceID -> minlevel:int -> maxlevel:int -> unit
  val dHashSpaceGetLevels : dSpaceID -> int * int

  val dSpaceAdd : dSpaceID -> dGeomID -> unit
  val dSpaceRemove : dSpaceID -> dGeomID -> unit

  val dCreateSphere : dSpaceID option -> radius:float -> dGeomID

  val dGeomSphereGetRadius : dGeomID -> float

  val dCreateBox : dSpaceID option -> lx:float -> ly:float -> lz:float -> dGeomID

  val dGeomBoxGetLengths : dGeomID -> dVector3

  val dCreatePlane : dSpaceID option -> a:float -> b:float -> c:float -> d:float -> dGeomID

  val dCreateGeomTransform : dSpaceID option -> dGeomID
  val dGeomTransformSetGeom : dGeomID -> dGeomID option -> unit
  val dGeomTransformGetGeom : dGeomID -> dGeomID option

  (* Mass functions.  Note that dMass objects are garbage collected. *)
  val dMassCreate : unit -> dMass
(*
  val dMass_set_mass : dMass -> float -> unit
*)
  val dMass_mass : dMass -> float
(*
  val dMass_set_c : dMass -> dVector4 -> unit
  val dMass_c : dMass -> dVector4
  val dMass_set_I : dMass -> dMatrix3 -> unit
  val dMass_I : dMass -> dMatrix3
*)

  val dMassSetZero : dMass -> unit
(*
  val dMassSetParameters : dMass ->
    mass:float ->
    cgx:float -> cgy:float -> cgz:float ->
    i11:float -> i22:float -> i33:float ->
    i12:float -> i13:float -> i23:float -> unit
*)
  val dMassSetSphere : dMass -> density:float -> radius:float -> unit
  val dMassSetSphereTotal : dMass -> total_mass:float -> radius:float -> unit

  val dMassSetBox : dMass -> density:float -> lx:float -> ly:float -> lz:float -> unit
  val dMassSetBoxTotal : dMass -> total_mass:float -> lx:float -> ly:float -> lz:float -> unit

  val dMassAdjust : dMass -> float -> unit
  val dMassTranslate : dMass -> x:float -> y:float -> z:float -> unit
  val dMassRotate : dMass -> dMatrix3 -> unit
  val dMassAdd : dMass -> dMass -> unit
end
