(* OCaml bindings for the Open Dynamics Engine (ODE).
 * By Richard W.M. Jones <rich@annexia.org>
 * $Id: ode.ml,v 1.1 2005/06/24 18:15:29 rich Exp $
 *)

module LowLevel = struct
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

  external dGetInfinity : unit -> float = "ocamlode_dGetInfinity"
  let dInfinity = dGetInfinity ()

  (* World. *)
  external dWorldCreate : unit -> dWorldID = "ocamlode_dWorldCreate"
  external dWorldDestroy : dWorldID -> unit = "ocamlode_dWorldDestroy"
  external dWorldSetGravity : dWorldID -> x:float -> y:float -> z:float -> unit = "ocamlode_dWorldSetGravity"

  external dCloseODE : unit -> unit = "ocamlode_dCloseODE"
  external dWorldStep : dWorldID -> float -> unit = "ocamlode_dWorldStep"
  external dWorldQuickStep : dWorldID -> float -> unit = "ocamlode_dWorldQuickStep"
(*
  external dWorldSetQuickStepNumIterations : dWorldID -> int -> unit = "ocamlode_dWorldSetQuickStepNumIterations"
  external dWorldGetQuickStepNumIterations : dWorldID -> int = "ocamlode_dWorldGetQuickStepNumIterations"
*)

  (* Bodies. *)
  external dBodyCreate : dWorldID -> dBodyID = "ocamlode_dBodyCreate"
  external dBodyDestroy : dBodyID -> unit = "ocamlode_dBodyDestroy"
(*
  external dBodySetPosition : dBodyID -> x:float -> y:float -> z:float -> unit = "ocamlode_dBodySetPosition"
  external dBodySetRotation : dBodyID -> dMatrix3 -> unit = "ocamlode_dBodySetRotation"
  external dBodySetQuaternion : dBodyID -> dQuaternion -> unit = "ocamlode_dBodySetQuaternion"
  external dBodySetLinearVel : dBodyID -> x:float -> y:float -> z:float -> unit = "ocamlode_dBodySetLinearVel"
  external dBodySetAngularVel : dBodyID -> x:float -> y:float -> z:float -> unit = "ocamlode_dBodySetAngularVel"
*)
  external dBodyGetPosition : dBodyID -> dVector3 = "ocamlode_dBodyGetPosition"
  external dBodyGetRotation : dBodyID -> dMatrix3 = "ocamlode_dBodyGetRotation"
  external dBodyGetQuaternion : dBodyID -> dQuaternion = "ocamlode_dBodyGetQuaternion"
  external dBodyGetLinearVel : dBodyID -> dVector3 = "ocamlode_dBodyGetLinearVel"
  external dBodyGetAngularVel : dBodyID -> dVector3 = "ocamlode_dBodyGetAngularVel"
  external dBodySetMass : dBodyID -> dMass -> unit = "ocamlode_dBodySetMass"
  external dBodyGetMass : dBodyID -> dMass = "ocamlode_dBodyGetMass"

  external dBodyAddForce : dBodyID -> fx:float -> fy:float -> fz:float -> unit = "ocamlode_dBodyAddForce"
  external dBodyAddTorque : dBodyID -> fx:float -> fy:float -> fz:float -> unit = "ocamlode_dBodyAddTorque"
  external dBodyAddRelForce : dBodyID -> fx:float -> fy:float -> fz:float -> unit = "ocamlode_dBodyAddRelForce"
  external dBodyAddRelTorque : dBodyID -> fx:float -> fy:float -> fz:float -> unit = "ocamlode_dBodyAddRelTorque"

  external dBodyGetRelPointPos : dBodyID -> px:float -> py:float -> pz:float -> dVector3 = "ocamlode_dBodyGetRelPointPos"
  external dBodyGetPosRelPoint : dBodyID -> px:float -> py:float -> pz:float -> dVector3 = "ocamlode_dBodyGetPosRelPoint"

  external dBodyEnable : dBodyID -> unit = "ocamlode_dBodyEnable"
  external dBodyDisable : dBodyID -> unit = "ocamlode_dBodyDisable"
  external dBodyIsEnabled : dBodyID -> bool = "ocamlode_dBodyIsEnabled"
  external dBodySetAutoDisableFlag : dBodyID -> bool -> unit = "ocamlode_dBodySetAutoDisableFlag"
  external dBodyGetAutoDisableFlag : dBodyID -> bool = "ocamlode_dBodyGetAutoDisableFlag"

  (* Joints. *)
  external dJointCreateBall : dWorldID -> dJointGroupID option -> dJointID = "ocamlode_dJointCreateBall"
  external dJointCreateHinge : dWorldID -> dJointGroupID option -> dJointID = "ocamlode_dJointCreateHinge"
  external dJointCreateSlider : dWorldID -> dJointGroupID option -> dJointID = "ocamlode_dJointCreateSlider"
  external dJointCreateContact : dWorldID -> dJointGroupID option -> dContact -> dJointID = "ocamlode_dJointCreateContact"
  external dJointCreateUniversal : dWorldID -> dJointGroupID option -> dJointID = "ocamlode_dJointCreateUniversal"
  external dJointCreateHinge2 : dWorldID -> dJointGroupID option -> dJointID = "ocamlode_dJointCreateHinge2"
  external dJointCreateFixed : dWorldID -> dJointGroupID option -> dJointID = "ocamlode_dJointCreateFixed"
  external dJointCreateAMotor : dWorldID -> dJointGroupID option -> dJointID = "ocamlode_dJointCreateAMotor"

  external dJointDestroy : dJointID -> unit = "ocamlode_dJointDestroy"

  external dJointGroupCreate : unit -> dJointGroupID = "ocamlode_dJointGroupCreate"
  external dJointGroupDestroy : dJointGroupID -> unit = "ocamlode_dJointGroupDestroy"
  external dJointGroupEmpty : dJointGroupID -> unit = "ocamlode_dJointGroupEmpty"
  external dJointAttach : dJointID -> dBodyID option -> dBodyID option -> unit = "ocamlode_dJointAttach"

  external dJointSetSliderAxis : dJointID -> x:float -> y:float -> z:float -> unit = "ocamlode_dJointSetSliderAxis"
  external dJointGetSliderAxis : dJointID -> dVector3 = "ocamlode_dJointGetSliderAxis"
  external dJointGetSliderPosition : dJointID -> float = "ocamlode_dJointGetSliderPosition"
  external dJointGetSliderPositionRate : dJointID -> float = "ocamlode_dJointGetSliderPositionRate"

  external dJointSetHingeParam : dJointID -> dJointParam -> float -> unit = "ocamlode_dJointSetHingeParam"
  external dJointSetSliderParam : dJointID -> dJointParam -> float -> unit = "ocamlode_dJointSetSliderParam"
  external dJointSetHinge2Param : dJointID -> dJointParam -> float -> unit = "ocamlode_dJointSetHinge2Param"
  external dJointSetUniversalParam : dJointID -> dJointParam -> float -> unit = "ocamlode_dJointSetUniversalParam"
  external dJointSetAMotorParam : dJointID -> dJointParam -> float -> unit = "ocamlode_dJointSetAMotorParam"
  external dJointGetHingeParam : dJointID -> dJointParam -> float = "ocamlode_dJointGetHingeParam"
  external dJointGetSliderParam : dJointID -> dJointParam -> float = "ocamlode_dJointGetSliderParam"
  external dJointGetHinge2Param : dJointID -> dJointParam -> float = "ocamlode_dJointGetHinge2Param"
  external dJointGetUniversalParam : dJointID -> dJointParam -> float = "ocamlode_dJointGetUniversalParam"
  external dJointGetAMotorParam : dJointID -> dJointParam -> float = "ocamlode_dJointGetAMotorParam"

  (* Geometry. *)
  external dGeomDestroy : dGeomID -> unit = "ocamlode_dGeomDestroy"
  external dGeomSetBody : dGeomID -> dBodyID option -> unit = "ocamlode_dGeomSetBody"
  external dGeomGetBody : dGeomID -> dBodyID option = "ocamlode_dGeomGetBody"
  external dGeomSetPosition : dGeomID -> x:float -> y:float -> z:float -> unit = "ocamlode_dGeomSetPosition"
  external dGeomSetRotation : dGeomID -> dMatrix3 -> unit = "ocamlode_dGeomSetRotation"
  external dGeomSetQuaternion : dGeomID -> dQuaternion -> unit = "ocamlode_dGeomSetQuaternion"
  external dGeomGetPosition : dGeomID -> dVector3 = "ocamlode_dGeomGetPosition"
  external dGeomGetRotation : dGeomID -> dMatrix3 = "ocamlode_dGeomGetRotation"
  external dGeomGetQuaternion : dGeomID -> dQuaternion = "ocamlode_dGeomGetQuaternion"

  external dCollide : dGeomID -> dGeomID -> max:int -> dContactGeom array = "ocamlode_dCollide"
  external dSpaceCollide : dSpaceID -> (dGeomID -> dGeomID -> unit) -> unit = "ocamlode_dSpaceCollide"

  external dSimpleSpaceCreate : dSpaceID option -> dSpaceID = "ocamlode_dSimpleSpaceCreate"
  external dHashSpaceCreate : dSpaceID option -> dSpaceID = "ocamlode_dHashSpaceCreate"
  external dQuadTreeSpaceCreate : dSpaceID option -> center:dVector3 -> extents:dVector3 -> depth:int -> dSpaceID = "ocamlode_dQuadTreeSpaceCreate"
  external dSpaceDestroy : dSpaceID -> unit = "ocamlode_dSpaceDestroy"
  external dHashSpaceSetLevels : dSpaceID -> minlevel:int -> maxlevel:int -> unit = "ocamlode_dHashSpaceSetLevels"
  external dHashSpaceGetLevels : dSpaceID -> int * int = "ocamlode_dHashSpaceGetLevels"

  external dSpaceAdd : dSpaceID -> dGeomID -> unit = "ocamlode_dSpaceAdd"
  external dSpaceRemove : dSpaceID -> dGeomID -> unit = "ocamlode_dSpaceRemove"

  external dCreateSphere : dSpaceID option -> radius:float -> dGeomID = "ocamlode_dCreateSphere"

  external dGeomSphereGetRadius : dGeomID -> float = "ocamlode_dGeomSphereGetRadius"

  external dCreateBox : dSpaceID option -> lx:float -> ly:float -> lz:float -> dGeomID = "ocamlode_dCreateBox"

  external dGeomBoxGetLengths : dGeomID -> dVector3 = "ocamlode_dGeomBoxGetLengths"

  external dCreatePlane : dSpaceID option -> a:float -> b:float -> c:float -> d:float -> dGeomID = "ocamlode_dCreatePlane"

  external dCreateGeomTransform : dSpaceID option -> dGeomID = "ocamlode_dCreateGeomTransform"
  external dGeomTransformSetGeom : dGeomID -> dGeomID option -> unit = "ocamlode_dGeomTransformSetGeom"
  external dGeomTransformGetGeom : dGeomID -> dGeomID option = "ocamlode_dGeomTransformGetGeom"

  (* Mass functions. *)
  external dMassCreate : unit -> dMass = "ocamlode_dMassCreate"
(*
  external dMass_set_mass : dMass -> float -> unit = "ocamlode_dMass_set_mass"
*)
  external dMass_mass : dMass -> float = "ocamlode_dMass_mass"
(*
  external dMass_set_c : dMass -> dVector4 -> unit = "ocamlode_dMass_set_c"
  external dMass_c : dMass -> dVector4 = "ocamlode_dMass_c"
  external dMass_set_I : dMass -> dMatrix3 -> unit = "ocamlode_dMass_set_I"
  external dMass_I : dMass -> dMatrix3 = "ocamlode_dMass_I"
*)

  external dMassSetZero : dMass -> unit = "ocamlode_dMassSetZero"
(*
  external dMassSetParameters : dMass -> mass:float -> cgx:float -> cgy:float -> cgz:float -> i11:float -> i22:float -> i33:float -> i12:float -> i13:float -> i23:float -> unit = "ocamlode_dMassSetParameters_bc" "ocamlode_dMassSetParameters"
*)
  external dMassSetSphere : dMass -> density:float -> radius:float -> unit = "ocamlode_dMassSetSphere"
  external dMassSetSphereTotal : dMass -> total_mass:float -> radius:float -> unit = "ocamlode_dMassSetSphereTotal"

  external dMassSetBox : dMass -> density:float -> lx:float -> ly:float -> lz:float -> unit = "ocamlode_dMassSetBox"
  external dMassSetBoxTotal : dMass -> total_mass:float -> lx:float -> ly:float -> lz:float -> unit = "ocamlode_dMassSetBoxTotal"

  external dMassAdjust : dMass -> float -> unit = "ocamlode_dMassAdjust"
  external dMassTranslate : dMass -> x:float -> y:float -> z:float -> unit = "ocamlode_dMassTranslate"
  external dMassRotate : dMass -> dMatrix3 -> unit = "ocamlode_dMassRotate"
  external dMassAdd : dMass -> dMass -> unit = "ocamlode_dMassAdd"
end
