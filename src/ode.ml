(** OCaml bindings for the Open Dynamics Engine (ODE). *)
(*  Originally written by Richard W.M. Jones
    Maintained by Florent Monnier

 This software is provided "AS-IS", without any express or implied warranty.
 In no event will the authors be held liable for any damages arising from
 the use of this software.

 Permission is granted to anyone to use this software for any purpose,
 including commercial applications, and to alter it and redistribute it
 freely. *)

module LowLevel = struct

  (**
  {ul
    {- {{:http://www.ode.org/ode-latest-userguide.html}
          Latest ODE User Guide}}
    {- {{:http://opende.sourceforge.net/wiki/}
          ODE's Community Wiki}}
  }
  *)

  (** Opaque types of ODE objects. *)

  type dWorldID
  type dSpaceID
  type dBodyID
  type 'a dGeomID
  type dJointID
  type dJointGroupID
  type dMass

  (** Note: These structures are binary-compatible with the ODE definitions,
      provided that the ODE library was compiled with dDOUBLE.
      Otherwise the OCaml datas are copied to the appropriate C type. *)
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
    t11: float; t12: float; t13: float; t14: float; t15: float; t16: float; t17: float; t18: float;
    t21: float; t22: float; t23: float; t24: float; t25: float; t26: float; t27: float; t28: float;
    t31: float; t32: float; t33: float; t34: float; t35: float; t36: float; t37: float; t38: float;
    t41: float; t42: float; t43: float; t44: float; t45: float; t46: float; t47: float; t48: float;
    t51: float; t52: float; t53: float; t54: float; t55: float; t56: float; t57: float; t58: float;
    t61: float; t62: float; t63: float; t64: float; t65: float; t66: float; t67: float; t68: float
  }
  type dQuaternion = { q1 : float; q2 : float; q3 : float; q4 : float }

  (** Contact points. *)
  type ('a, 'b) dContactGeom = {
    cg_pos : dVector3;
    cg_normal : dVector3;
    cg_depth : float;
    cg_g1 : 'a dGeomID;
    cg_g2 : 'b dGeomID;
  }

  (** Contact structure. *)
  type ('a, 'b) dContact = {
    c_surface : dSurfaceParameters;
    c_geom : ('a, 'b) dContactGeom;
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

  let surf_param_zero = {
    sp_mode = [];
    sp_mu = 0.0;
    sp_mu2 = 0.0;
    sp_bounce = 0.0;
    sp_bounce_vel = 0.0;
    sp_soft_erp = 0.0;
    sp_soft_cfm = 0.0;
    sp_motion1 = 0.0;
    sp_motion2 = 0.0;
    sp_slip1 = 0.0;
    sp_slip2 = 0.0;
  }

  let get_surface ~mu
        ?(mu2 = 0.0)
        ?(bounce = 0.0)
        ?(bounce_vel = 0.0)
        ?(soft_erp = 0.0)
        ?(soft_cfm = 0.0)
        ?(motion1 = 0.0)
        ?(motion2 = 0.0)
        ?(slip1 = 0.0)
        ?(slip2 = 0.0) () =
    let mode = [] in
    let mode = if mu2 = 0.0 then mode else `dContactMu2 :: mode in
    let mode = if bounce = 0.0 then mode else `dContactBounce :: mode in
    let mode = if bounce_vel = 0.0 then mode else `dContactBounce :: mode in
    let mode = if soft_erp = 0.0 then mode else `dContactSoftERP :: mode in
    let mode = if soft_cfm = 0.0 then mode else `dContactSoftCFM :: mode in
    let mode = if motion1 = 0.0 then mode else `dContactMotion1 :: mode in
    let mode = if motion2 = 0.0 then mode else `dContactMotion2 :: mode in
    let mode = if slip1 = 0.0 then mode else `dContactSlip1 :: mode in
    let mode = if slip2 = 0.0 then mode else `dContactSlip2 :: mode in
    {
      sp_mode = mode;
      sp_mu = mu;
      sp_mu2 = mu2;
      sp_bounce = bounce;
      sp_bounce_vel = bounce_vel;
      sp_soft_erp = soft_erp;
      sp_soft_cfm = soft_cfm;
      sp_motion1 = motion1;
      sp_motion2 = motion2;
      sp_slip1 = slip1;
      sp_slip2 = slip2;
    }

  type surface_parameter =
      | Mu2 of float
      | Bounce of float
      | BounceVel of float
      (*
      | Bounce of float * float
      *)
      | SoftERP of float
      | SoftCFM of float
      | Motion1 of float
      | Motion2 of float
      | Slip1 of float
      | Slip2 of float

  let surface_param ~mu =
    let rec aux p = function [] -> p
      | (Mu2 mu2)::t -> aux {p with sp_mu2=mu2; sp_mode=`dContactMu2::p.sp_mode} t
      | (Bounce bounce)::t -> aux {p with sp_bounce=bounce; sp_mode=`dContactBounce::p.sp_mode} t
      | (BounceVel bounce_vel)::t -> aux {p with sp_bounce_vel=bounce_vel; sp_mode=`dContactBounce::p.sp_mode} t
      | (SoftERP soft_erp)::t -> aux {p with sp_soft_erp=soft_erp; sp_mode=`dContactSoftERP::p.sp_mode} t
      | (SoftCFM soft_cfm)::t -> aux {p with sp_soft_cfm=soft_cfm; sp_mode=`dContactSoftCFM::p.sp_mode} t
      | (Motion1 motion1)::t -> aux {p with sp_motion1=motion1; sp_mode=`dContactMotion1::p.sp_mode} t
      | (Motion2 motion2)::t -> aux {p with sp_motion2=motion2; sp_mode=`dContactMotion2::p.sp_mode} t
      | (Slip1 slip1)::t -> aux {p with sp_slip1=slip1; sp_mode=`dContactSlip1::p.sp_mode} t
      | (Slip2 slip2)::t -> aux {p with sp_slip2=slip2; sp_mode=`dContactSlip2::p.sp_mode} t
      (*
      | (Bounce(bounce,bounce_vel))::t ->
          aux {p with sp_bounce=bounce; sp_bounce_vel=bounce_vel; sp_mode=`dContactBounce::p.sp_mode} t
      *)
    in
    let p = {
      sp_mode = [];
      sp_mu = mu;
      sp_mu2 = 0.0;
      sp_bounce = 0.0;
      sp_bounce_vel = 0.0;
      sp_soft_erp = 0.0;
      sp_soft_cfm = 0.0;
      sp_motion1 = 0.0;
      sp_motion2 = 0.0;
      sp_slip1 = 0.0;
      sp_slip2 = 0.0;
    } in
    aux p ;;

  type joint_type =
    | JointTypeNone
    | JointTypeBall
    | JointTypeHinge
    | JointTypeSlider
    | JointTypeContact
    | JointTypeUniversal
    | JointTypeHinge2
    | JointTypeFixed
    | JointTypeNull
    | JointTypeAMotor
    | JointTypeLMotor
    | JointTypePlane2D
    | JointTypePR

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
    | DParamERP

    | DParamLoStop2
    | DParamHiStop2
    | DParamVel2
    | DParamFMax2
    | DParamFudgeFactor2
    | DParamBounce2
    | DParamCFM2
    | DParamStopERP2
    | DParamStopCFM2
    | DParamSuspensionERP2
    | DParamSuspensionCFM2
    | DParamERP2

    | DParamLoStop3
    | DParamHiStop3
    | DParamVel3
    | DParamFMax3
    | DParamFudgeFactor3
    | DParamBounce3
    | DParamCFM3
    | DParamStopERP3
    | DParamStopCFM3
    | DParamSuspensionERP3
    | DParamSuspensionCFM3
    | DParamERP3

    | DParamGroup

  external dGetInfinity : unit -> float = "ocamlode_dGetInfinity"
  let dInfinity = dGetInfinity ()

  external dInitODE : unit -> unit = "ocamlode_dInitODE"
  external dCloseODE : unit -> unit = "ocamlode_dCloseODE"

  type dInitODEFlags =
    | DInitFlagManualThreadCleanup
  external dInitODE2: initFlags:dInitODEFlags list -> unit = "ocamlode_dInitODE2"


  (** {3 World} *)

  external dWorldCreate : unit -> dWorldID = "ocamlode_dWorldCreate"
  external dWorldDestroy : dWorldID -> unit = "ocamlode_dWorldDestroy"
  external dWorldSetGravity : dWorldID -> x:float -> y:float -> z:float -> unit = "ocamlode_dWorldSetGravity"
  external dWorldGetGravity : dWorldID -> dVector3 = "ocamlode_dWorldGetGravity"
  external dWorldSetERP : dWorldID -> erp:float -> unit = "ocamlode_dWorldSetERP"
  external dWorldGetERP : dWorldID -> float = "ocamlode_dWorldGetERP"
  external dWorldSetCFM: dWorldID -> cfm:float -> unit = "ocamlode_dWorldSetCFM"
  external dWorldGetCFM : dWorldID -> float = "ocamlode_dWorldGetCFM"

  external dWorldStep : dWorldID -> float -> unit = "ocamlode_dWorldStep"
  external dWorldQuickStep : dWorldID -> float -> unit = "ocamlode_dWorldQuickStep"
  external dWorldSetQuickStepNumIterations : dWorldID -> num:int -> unit = "ocamlode_dWorldSetQuickStepNumIterations"
  external dWorldGetQuickStepNumIterations : dWorldID -> int = "ocamlode_dWorldGetQuickStepNumIterations"
  external dWorldSetContactSurfaceLayer : dWorldID -> depth:float -> unit = "ocamlode_dWorldSetContactSurfaceLayer"
  external dWorldGetContactSurfaceLayer : dWorldID -> float = "ocamlode_dWorldGetContactSurfaceLayer"
  external dWorldSetAutoDisableLinearThreshold : dWorldID -> linear_threshold:float -> unit
      = "ocamlode_dWorldSetAutoDisableLinearThreshold"
  external dWorldGetAutoDisableLinearThreshold : dWorldID -> float = "ocamlode_dWorldGetAutoDisableLinearThreshold"
  external dWorldSetAutoDisableAngularThreshold : dWorldID -> angular_threshold:float -> unit
      = "ocamlode_dWorldSetAutoDisableAngularThreshold"
  external dWorldGetAutoDisableAngularThreshold : dWorldID -> float = "ocamlode_dWorldGetAutoDisableAngularThreshold"
  (*
  external dWorldSetAutoDisableLinearAverageThreshold : dWorldID -> linear_average_threshold:float -> unit
      = "ocamlode_dWorldSetAutoDisableLinearAverageThreshold"
  external dWorldGetAutoDisableLinearAverageThreshold : dWorldID -> float = "ocamlode_dWorldGetAutoDisableLinearAverageThreshold"
  external dWorldSetAutoDisableAngularAverageThreshold : dWorldID -> angular_average_threshold:float -> unit
      = "ocamlode_dWorldSetAutoDisableAngularAverageThreshold"
  external dWorldGetAutoDisableAngularAverageThreshold : dWorldID -> float = "ocamlode_dWorldGetAutoDisableAngularAverageThreshold"
  *)
  external dWorldSetAutoDisableAverageSamplesCount : dWorldID -> average_samples_count:int -> unit
      = "ocamlode_dWorldSetAutoDisableAverageSamplesCount"
  external dWorldGetAutoDisableAverageSamplesCount : dWorldID -> int = "ocamlode_dWorldGetAutoDisableAverageSamplesCount"
  external dWorldSetAutoDisableSteps : dWorldID -> steps:int -> unit = "ocamlode_dWorldSetAutoDisableSteps"
  external dWorldGetAutoDisableSteps : dWorldID -> int = "ocamlode_dWorldGetAutoDisableSteps"
  external dWorldSetAutoDisableTime : dWorldID -> time:float -> unit = "ocamlode_dWorldSetAutoDisableTime"
  external dWorldGetAutoDisableTime : dWorldID -> float = "ocamlode_dWorldGetAutoDisableTime"
  external dWorldSetAutoDisableFlag : dWorldID -> do_auto_disable:bool -> unit = "ocamlode_dWorldSetAutoDisableFlag"
  external dWorldGetAutoDisableFlag : dWorldID -> bool = "ocamlode_dWorldGetAutoDisableFlag"
  external dWorldSetQuickStepW : dWorldID -> over_relaxation:float -> unit = "ocamlode_dWorldSetQuickStepW"
  external dWorldGetQuickStepW : dWorldID -> float = "ocamlode_dWorldGetQuickStepW"
  external dWorldSetContactMaxCorrectingVel : dWorldID -> vel:float -> unit = "ocamlode_dWorldSetContactMaxCorrectingVel"
  external dWorldGetContactMaxCorrectingVel : dWorldID -> float = "ocamlode_dWorldGetContactMaxCorrectingVel"


  (** {3 Bodies} *)

  external dBodyCreate : dWorldID -> dBodyID = "ocamlode_dBodyCreate"
  external dBodyDestroy : dBodyID -> unit = "ocamlode_dBodyDestroy"
  external dBodyGetWorld : dBodyID -> dWorldID = "ocamlode_dBodyGetWorld"
  external dBodySetPosition : dBodyID -> x:float -> y:float -> z:float -> unit = "ocamlode_dBodySetPosition"
  external dBodySetRotation : dBodyID -> dMatrix3 -> unit = "ocamlode_dBodySetRotation"
  external dBodySetQuaternion : dBodyID -> dQuaternion -> unit = "ocamlode_dBodySetQuaternion"
  external dBodySetLinearVel : dBodyID -> x:float -> y:float -> z:float -> unit = "ocamlode_dBodySetLinearVel"
  external dBodySetAngularVel : dBodyID -> x:float -> y:float -> z:float -> unit = "ocamlode_dBodySetAngularVel"
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

  external dBodyAddForceAtPos : dBodyID -> fx:float -> fy:float -> fz:float -> px:float -> py:float -> pz:float -> unit
      = "ocamlode_dBodyAddForceAtPos_bc" "ocamlode_dBodyAddForceAtPos"
  external dBodyAddForceAtRelPos : dBodyID -> fx:float -> fy:float -> fz:float -> px:float -> py:float -> pz:float -> unit
      = "ocamlode_dBodyAddForceAtRelPos_bc" "ocamlode_dBodyAddForceAtRelPos"
  external dBodyAddRelForceAtPos : dBodyID -> fx:float -> fy:float -> fz:float -> px:float -> py:float -> pz:float -> unit
      = "ocamlode_dBodyAddRelForceAtPos_bc" "ocamlode_dBodyAddRelForceAtPos"
  external dBodyAddRelForceAtRelPos : dBodyID -> fx:float -> fy:float -> fz:float -> px:float -> py:float -> pz:float -> unit
      = "ocamlode_dBodyAddRelForceAtRelPos_bc" "ocamlode_dBodyAddRelForceAtRelPos"
  external dBodySetForce : dBodyID -> x:float -> y:float -> z:float -> unit = "ocamlode_dBodySetForce"
  external dBodySetTorque : dBodyID -> x:float -> y:float -> z:float -> unit = "ocamlode_dBodySetTorque"
  external dBodyGetForce : dBodyID -> dVector3 = "ocamlode_dBodyGetForce"
  external dBodyGetTorque : dBodyID -> dVector3 = "ocamlode_dBodyGetTorque"

  external dBodyGetRelPointPos : dBodyID -> px:float -> py:float -> pz:float -> dVector3 = "ocamlode_dBodyGetRelPointPos"
  external dBodyGetPosRelPoint : dBodyID -> px:float -> py:float -> pz:float -> dVector3 = "ocamlode_dBodyGetPosRelPoint"

  external dBodyGetRelPointVel : dBodyID -> px:float -> py:float -> pz:float -> dVector3 = "ocamlode_dBodyGetRelPointVel"
  external dBodyGetPointVel : dBodyID -> px:float -> py:float -> pz:float -> dVector3 = "ocamlode_dBodyGetPointVel"
  external dBodyVectorToWorld : dBodyID -> px:float -> py:float -> pz:float -> dVector3 = "ocamlode_dBodyVectorToWorld"
  external dBodyVectorFromWorld : dBodyID -> px:float -> py:float -> pz:float -> dVector3 = "ocamlode_dBodyVectorFromWorld"

  external dBodyEnable : dBodyID -> unit = "ocamlode_dBodyEnable"
  external dBodyDisable : dBodyID -> unit = "ocamlode_dBodyDisable"
  external dBodyIsEnabled : dBodyID -> bool = "ocamlode_dBodyIsEnabled"
  external dBodySetAutoDisableFlag : dBodyID -> bool -> unit = "ocamlode_dBodySetAutoDisableFlag"
  external dBodyGetAutoDisableFlag : dBodyID -> bool = "ocamlode_dBodyGetAutoDisableFlag"
  external dBodySetAutoDisableSteps : dBodyID -> steps:int -> unit = "ocamlode_dBodySetAutoDisableSteps"
  external dBodyGetAutoDisableSteps : dBodyID -> int = "ocamlode_dBodyGetAutoDisableSteps"
  external dBodySetAutoDisableTime : dBodyID -> time:float -> unit = "ocamlode_dBodySetAutoDisableTime"
  external dBodyGetAutoDisableTime : dBodyID -> float = "ocamlode_dBodyGetAutoDisableTime"

  external dAreConnected : a:dBodyID -> b:dBodyID -> bool = "ocamlode_dAreConnected"
  external dAreConnectedExcluding : a:dBodyID -> b:dBodyID -> joint_type -> bool = "ocamlode_dAreConnectedExcluding"

  external dBodySetGravityMode : dBodyID -> mode:bool -> unit = "ocamlode_dBodySetGravityMode"
  external dBodyGetGravityMode : dBodyID -> bool = "ocamlode_dBodyGetGravityMode"

  external dBodySetFiniteRotationMode : dBodyID -> mode:bool -> unit = "ocamlode_dBodySetFiniteRotationMode"
  external dBodyGetFiniteRotationMode : dBodyID -> bool = "ocamlode_dBodyGetFiniteRotationMode"
  external dBodySetFiniteRotationAxis : dBodyID -> x:float -> y:float -> z:float -> unit = "ocamlode_dBodySetFiniteRotationAxis"
  external dBodyGetFiniteRotationAxis : dBodyID -> dVector3 = "ocamlode_dBodyGetFiniteRotationAxis"
  external dBodySetAutoDisableLinearThreshold : dBodyID -> linear_average_threshold:float -> unit
      = "ocamlode_dBodySetAutoDisableLinearThreshold"
  external dBodyGetAutoDisableLinearThresholda : dBodyID -> float = "ocamlode_dBodyGetAutoDisableLinearThreshold"
  external dBodySetAutoDisableAngularThreshold : dBodyID -> angular_average_threshold:float -> unit
      = "ocamlode_dBodySetAutoDisableAngularThreshold"
  external dBodyGetAutoDisableAngularThreshold : dBodyID -> float = "ocamlode_dBodyGetAutoDisableAngularThreshold"
  external dBodySetAutoDisableAverageSamplesCount : dBodyID -> average_samples_count:int -> unit
      = "ocamlode_dBodySetAutoDisableAverageSamplesCount"
  external dBodyGetAutoDisableAverageSamplesCount: dBodyID -> int = "ocamlode_dBodyGetAutoDisableAverageSamplesCount"

  external dBodySetData : dBodyID -> int -> unit = "ocamlode_dBodySetData"
  external dBodyGetData : dBodyID -> int = "ocamlode_dBodyGetData"
  (** you can use these functions for example to associate user data to a body: {[
  let body_data_tbl = Hashtbl.create 16
  let dBodySetData =
    let body_data_count = ref 0 in
    fun body ~data ->
      let i = !body_data_count in
      incr body_data_count;
      Hashtbl.add body_data_tbl i data;
      dBodySetData body i;
  ;;
  let dBodyGetData body = (Hashtbl.find body_data_tbl (dBodyGetData body))
  ]} *)


  (** {3 Joints} *)

  external dJointCreateBall : dWorldID -> dJointGroupID option -> dJointID = "ocamlode_dJointCreateBall"
  external dJointCreateHinge : dWorldID -> dJointGroupID option -> dJointID = "ocamlode_dJointCreateHinge"
  external dJointCreateSlider : dWorldID -> dJointGroupID option -> dJointID = "ocamlode_dJointCreateSlider"
  external dJointCreateContact : dWorldID -> dJointGroupID option -> ('a, 'b) dContact -> dJointID = "ocamlode_dJointCreateContact"
  external dJointCreateUniversal : dWorldID -> dJointGroupID option -> dJointID = "ocamlode_dJointCreateUniversal"
  external dJointCreateHinge2 : dWorldID -> dJointGroupID option -> dJointID = "ocamlode_dJointCreateHinge2"
  external dJointCreateFixed : dWorldID -> dJointGroupID option -> dJointID = "ocamlode_dJointCreateFixed"
  external dJointCreateAMotor : dWorldID -> dJointGroupID option -> dJointID = "ocamlode_dJointCreateAMotor"
  external dJointCreateLMotor : dWorldID -> dJointGroupID option -> dJointID = "ocamlode_dJointCreateLMotor"
  external dJointCreatePlane2D : dWorldID -> dJointGroupID option -> dJointID = "ocamlode_dJointCreatePlane2D"

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
  external dJointSetLMotorParam : dJointID -> dJointParam -> float -> unit = "ocamlode_dJointSetLMotorParam"
  external dJointGetHingeParam : dJointID -> dJointParam -> float = "ocamlode_dJointGetHingeParam"
  external dJointGetSliderParam : dJointID -> dJointParam -> float = "ocamlode_dJointGetSliderParam"
  external dJointGetHinge2Param : dJointID -> dJointParam -> float = "ocamlode_dJointGetHinge2Param"
  external dJointGetUniversalParam : dJointID -> dJointParam -> float = "ocamlode_dJointGetUniversalParam"
  external dJointGetAMotorParam : dJointID -> dJointParam -> float = "ocamlode_dJointGetAMotorParam"
  external dJointGetLMotorParam : dJointID -> dJointParam -> float = "ocamlode_dJointGetLMotorParam"
  external dJointSetBallAnchor : dJointID -> x:float -> y:float -> z:float -> unit = "ocamlode_dJointSetBallAnchor"
  external dJointSetBallAnchor2 : dJointID -> x:float -> y:float -> z:float -> unit = "ocamlode_dJointSetBallAnchor2"

  external dJointSetHingeAnchor : dJointID -> x:float -> y:float -> z:float -> unit = "ocamlode_dJointSetHingeAnchor"
  external dJointSetHingeAnchorDelta : dJointID -> x:float -> y:float -> z:float -> ax:float -> ay:float -> az:float -> unit
      = "ocamlode_dJointSetHingeAnchorDelta_bytecode"
        "ocamlode_dJointSetHingeAnchorDelta"
  external dJointSetHingeAxis : dJointID -> x:float -> y:float -> z:float -> unit = "ocamlode_dJointSetHingeAxis"
  external dJointAddHingeTorque : dJointID -> torque:float -> unit = "ocamlode_dJointAddHingeTorque"
  external dJointSetSliderAxisDelta : dJointID -> x:float -> y:float -> z:float -> ax:float -> ay:float -> az:float -> unit
      = "ocamlode_dJointSetSliderAxisDelta_bytecode"
        "ocamlode_dJointSetSliderAxisDelta"
  external dJointAddSliderForce: dJointID -> force:float -> unit = "ocamlode_dJointAddSliderForce"

  external dJointSetHinge2Anchor : dJointID -> x:float -> y:float -> z:float -> unit = "ocamlode_dJointSetHinge2Anchor"
  external dJointAddHinge2Torques : dJointID -> torque1:float -> torque2:float -> unit = "ocamlode_dJointAddHinge2Torques"

  external dJointSetUniversalAnchor : dJointID -> x:float -> y:float -> z:float -> unit = "ocamlode_dJointSetUniversalAnchor"
  external dJointSetUniversalAxis1 : dJointID -> x:float -> y:float -> z:float -> unit = "ocamlode_dJointSetUniversalAxis1"
  external dJointSetUniversalAxis2 : dJointID -> x:float -> y:float -> z:float -> unit = "ocamlode_dJointSetUniversalAxis2"
  external dJointAddUniversalTorques : dJointID -> torque1:float -> torque2:float -> unit = "ocamlode_dJointAddUniversalTorques"
  external dJointSetPRAnchor : dJointID -> x:float -> y:float -> z:float -> unit = "ocamlode_dJointSetPRAnchor"
  external dJointSetPRAxis1 : dJointID -> x:float -> y:float -> z:float -> unit = "ocamlode_dJointSetPRAxis1"
  external dJointSetPRAxis2 : dJointID -> x:float -> y:float -> z:float -> unit = "ocamlode_dJointSetPRAxis2"
  external dJointSetPRParam : dJointID -> parameter:int -> value:float -> unit = "ocamlode_dJointSetPRParam"
  external dJointAddPRTorque : dJointID -> torque:float -> unit = "ocamlode_dJointAddPRTorque"
  external dJointSetFixed : dJointID -> unit = "ocamlode_dJointSetFixed"
  external dJointSetAMotorNumAxes : dJointID -> num:int -> unit = "ocamlode_dJointSetAMotorNumAxes"
  external dJointSetAMotorAxis : dJointID -> anum:int -> rel:int -> x:float -> y:float -> z:float -> unit
      = "ocamlode_dJointSetAMotorAxis_bc" "ocamlode_dJointSetAMotorAxis"
  external dJointSetAMotorAngle : dJointID -> anum:int -> angle:float -> unit = "ocamlode_dJointSetAMotorAngle"
  external dJointSetAMotorMode : dJointID -> mode:int -> unit = "ocamlode_dJointSetAMotorMode"
  external dJointAddAMotorTorques : dJointID -> torque1:float -> torque2:float -> torque3:float -> unit
      = "ocamlode_dJointAddAMotorTorques"
  external dJointSetLMotorNumAxes : dJointID -> num:int -> unit = "ocamlode_dJointSetLMotorNumAxes"
  external dJointSetLMotorAxis : dJointID -> anum:int -> rel:int -> x:float -> y:float -> z:float -> unit
      = "ocamlode_dJointSetLMotorAxis_bc" "ocamlode_dJointSetLMotorAxis"

  external dJointSetPlane2DXParam : dJointID -> dJointParam -> float -> unit = "ocamlode_dJointSetPlane2DXParam"
  external dJointSetPlane2DYParam : dJointID -> dJointParam -> float -> unit = "ocamlode_dJointSetPlane2DYParam"
  external dJointSetPlane2DAngleParam : dJointID -> dJointParam -> float -> unit = "ocamlode_dJointSetPlane2DAngleParam"
  external dJointGetBallAnchor : dJointID -> dVector3 = "ocamlode_dJointGetBallAnchor"
  external dJointGetBallAnchor2 : dJointID -> dVector3 = "ocamlode_dJointGetBallAnchor2"
  external dJointGetHingeAnchor : dJointID -> dVector3 = "ocamlode_dJointGetHingeAnchor"
  external dJointGetHingeAnchor2 : dJointID -> dVector3 = "ocamlode_dJointGetHingeAnchor2"
  external dJointGetHingeAxis : dJointID -> dVector3 = "ocamlode_dJointGetHingeAxis"
  external dJointGetHingeAngle : dJointID -> float = "ocamlode_dJointGetHingeAngle"
  external dJointGetHingeAngleRate : dJointID -> float = "ocamlode_dJointGetHingeAngleRate"
  external dJointGetHinge2Anchor : dJointID -> dVector3 = "ocamlode_dJointGetHinge2Anchor"
  external dJointGetHinge2Anchor2 : dJointID -> dVector3 = "ocamlode_dJointGetHinge2Anchor2"
  external dJointGetHinge2Axis1 : dJointID -> dVector3 = "ocamlode_dJointGetHinge2Axis1"
  external dJointGetHinge2Axis2 : dJointID -> dVector3 = "ocamlode_dJointGetHinge2Axis2"
  external dJointGetHinge2Angle1 : dJointID -> float = "ocamlode_dJointGetHinge2Angle1"
  external dJointGetHinge2Angle1Rate : dJointID -> float = "ocamlode_dJointGetHinge2Angle1Rate"
  external dJointGetHinge2Angle2Rate : dJointID -> float = "ocamlode_dJointGetHinge2Angle2Rate"
  external dJointGetUniversalAnchor : dJointID -> dVector3 = "ocamlode_dJointGetUniversalAnchor"
  external dJointGetUniversalAnchor2 : dJointID -> dVector3 = "ocamlode_dJointGetUniversalAnchor2"
  external dJointGetUniversalAxis1 : dJointID -> dVector3 = "ocamlode_dJointGetUniversalAxis1"
  external dJointGetUniversalAxis2 : dJointID -> dVector3 = "ocamlode_dJointGetUniversalAxis2"

  external dBodyGetNumJoints : dBodyID -> int = "ocamlode_dBodyGetNumJoints"
  external dBodyGetJoint : dBodyID -> index:int -> dJointID = "ocamlode_dBodyGetJoint"
  external dConnectingJoint : dBodyID -> dBodyID -> dJointID = "ocamlode_dConnectingJoint"
  external dConnectingJointList : dBodyID -> dBodyID -> dJointID array = "ocamlode_dConnectingJointList"

  external dJointSetData : dJointID -> data:int -> unit = "ocamlode_dJointSetData"
  external dJointGetData : dJointID -> int = "ocamlode_dJointGetData"
  external dJointGetType : dJointID -> joint_type = "ocamlode_dJointGetType"
  external dJointGetBody : dJointID -> index:int -> dBodyID = "ocamlode_dJointGetBody"

  type dJointFeedback = {
    f1 : dVector3;
    t1 : dVector3;
    f2 : dVector3;
    t2 : dVector3;
  }
  type dJointFeedbackBuffer
  external dJointSetFeedback : dJointID -> dJointFeedbackBuffer = "ocamlode_dJointSetFeedback"
  (*
  let dJointFeedbackBufferFree (b:dJointFeedbackBuffer) = ignore(b) ;;
  *)
  external dJointFeedbackBufferDestroy : dJointFeedbackBuffer -> unit = "ocamlode_dJointFeedbackBufferDestroy"
  (** {b frees the memory of the buffer}
      (destroy the associated world and/or joint won't free this buffer) *)

  external dJointGetFeedback : dJointID -> dJointFeedback = "ocamlode_dJointGetFeedback"
  external dJointFeedback_of_buffer : dJointFeedbackBuffer -> dJointFeedback = "ocamlode_dJointFeedback_of_buffer"


  (** {3 Space} *)

  external dSimpleSpaceCreate : dSpaceID option -> dSpaceID = "ocamlode_dSimpleSpaceCreate"
  external dHashSpaceCreate : dSpaceID option -> dSpaceID = "ocamlode_dHashSpaceCreate"
  external dQuadTreeSpaceCreate : dSpaceID option -> center:dVector3 -> extents:dVector3 -> depth:int -> dSpaceID = "ocamlode_dQuadTreeSpaceCreate"
  external dSpaceDestroy : dSpaceID -> unit = "ocamlode_dSpaceDestroy"
  external dHashSpaceSetLevels : dSpaceID -> minlevel:int -> maxlevel:int -> unit = "ocamlode_dHashSpaceSetLevels"
  external dHashSpaceGetLevels : dSpaceID -> int * int = "ocamlode_dHashSpaceGetLevels"

  external dSpaceAdd : dSpaceID -> 'a dGeomID -> unit = "ocamlode_dSpaceAdd"
  external dSpaceRemove : dSpaceID -> 'a dGeomID -> unit = "ocamlode_dSpaceRemove"

  external dSpaceCollide : dSpaceID -> ('a dGeomID -> 'b dGeomID -> unit) -> unit = "ocamlode_dSpaceCollide"

  (* XXX test me *)
  external dSpaceCollide2 : 'a dGeomID -> 'b dGeomID -> ('c dGeomID -> 'd dGeomID -> unit) -> unit = "ocamlode_dSpaceCollide2"

  external dSpaceSetCleanup : dSpaceID -> mode:bool -> unit = "ocamlode_dSpaceSetCleanup"
  external dSpaceGetCleanup : dSpaceID -> bool = "ocamlode_dSpaceGetCleanup"
  external dSpaceClean : dSpaceID -> unit = "ocamlode_dSpaceClean"
  external dSpaceQuery : dSpaceID -> 'a dGeomID -> bool = "ocamlode_dSpaceQuery"
  external dSpaceGetNumGeoms : dSpaceID -> unit = "ocamlode_dSpaceGetNumGeoms"
  external dSpaceGetGeom : dSpaceID -> i:int -> 'a dGeomID = "ocamlode_dSpaceGetGeom"
  external dSpaceGetGeomsArray : dSpaceID -> 'a dGeomID array = "ocamlode_dSpaceGetGeomsArray"


  (** {3 Geometry} *)

  external dCollide : 'a dGeomID -> 'b dGeomID -> max:int -> ('a, 'b) dContactGeom array = "ocamlode_dCollide"

  external dGeomDestroy : 'a dGeomID -> unit = "ocamlode_dGeomDestroy"
  external dGeomSetBody : 'a dGeomID -> dBodyID option -> unit = "ocamlode_dGeomSetBody"
  external dGeomGetBody : 'a dGeomID -> dBodyID option = "ocamlode_dGeomGetBody"
  external dGeomSetPosition : 'a dGeomID -> x:float -> y:float -> z:float -> unit = "ocamlode_dGeomSetPosition"
  external dGeomSetRotation : 'a dGeomID -> dMatrix3 -> unit = "ocamlode_dGeomSetRotation"
  external dGeomSetQuaternion : 'a dGeomID -> dQuaternion -> unit = "ocamlode_dGeomSetQuaternion"
  external dGeomGetPosition : 'a dGeomID -> dVector3 = "ocamlode_dGeomGetPosition"
  external dGeomGetRotation : 'a dGeomID -> dMatrix3 = "ocamlode_dGeomGetRotation"
  external dGeomGetQuaternion : 'a dGeomID -> dQuaternion = "ocamlode_dGeomGetQuaternion"

  external dGeomGetAABB : 'a dGeomID -> float array = "ocamlode_dGeomGetAABB"
  external dInfiniteAABB : 'a dGeomID -> float array = "ocamlode_dInfiniteAABB"


  (** Geometry kind *)

  type sphere_geom
  type box_geom
  type plane_geom
  type heightfield_geom
  type trimesh_geom
  type convex_geom
  type capsule_geom
  type cylinder_geom
  type ray_geom
  type geomTransform_geom


  type geom_class =
    | SphereClass
    | BoxClass
    | CapsuleClass
    | CylinderClass
    | PlaneClass
    | RayClass
    | ConvexClass
    | GeomTransformClass
    | TriMeshClass
    | HeightfieldClass
    (* space geoms *)
    | FirstSpaceSimpleSpaceClass
    | HashSpaceClass
    | LastSpaceQuadTreeSpaceClass
    (* *)
    | FirstUserClass
    | LastUserClass

  external dGeomGetClass : 'a dGeomID -> geom_class = "ocamlode_dGeomGetClass"


  type geom_type =
    | Sphere_geom of sphere_geom dGeomID
    | Box_geom of box_geom dGeomID
    | Capsule_geom of capsule_geom dGeomID
    | Cylinder_geom of cylinder_geom dGeomID
    | Plane_geom of plane_geom dGeomID
    | Ray_geom of ray_geom dGeomID
    | Convex_geom of convex_geom dGeomID
    | GeomTransform_geom of geomTransform_geom dGeomID
    | TriMesh_geom of trimesh_geom dGeomID
    | Heightfield_geom of heightfield_geom dGeomID
    (* below is alpha *)
    | Geom_is_space
    | User_class

  let geom_kind (geom : 'a dGeomID) =
    match dGeomGetClass geom with
    | SphereClass        -> Sphere_geom        (Obj.magic geom : sphere_geom        dGeomID)
    | BoxClass           -> Box_geom           (Obj.magic geom : box_geom           dGeomID)
    | CapsuleClass       -> Capsule_geom       (Obj.magic geom : capsule_geom       dGeomID)
    | CylinderClass      -> Cylinder_geom      (Obj.magic geom : cylinder_geom      dGeomID)
    | PlaneClass         -> Plane_geom         (Obj.magic geom : plane_geom         dGeomID)
    | RayClass           -> Ray_geom           (Obj.magic geom : ray_geom           dGeomID)
    | ConvexClass        -> Convex_geom        (Obj.magic geom : convex_geom        dGeomID)
    | GeomTransformClass -> GeomTransform_geom (Obj.magic geom : geomTransform_geom dGeomID)
    | TriMeshClass       -> TriMesh_geom       (Obj.magic geom : trimesh_geom       dGeomID)
    | HeightfieldClass   -> Heightfield_geom   (Obj.magic geom : heightfield_geom   dGeomID)

    | FirstSpaceSimpleSpaceClass  -> (Geom_is_space)
    | HashSpaceClass              -> (Geom_is_space)
    | LastSpaceQuadTreeSpaceClass -> (Geom_is_space)

    | FirstUserClass -> (User_class)
    | LastUserClass  -> (User_class)
    (*
    | _ -> failwith "Unknown Geom Class"
    *)
  ;;


  external dCreateSphere : dSpaceID option -> radius:float -> sphere_geom dGeomID = "ocamlode_dCreateSphere"
  external dGeomSphereGetRadius : sphere_geom dGeomID -> float = "ocamlode_dGeomSphereGetRadius"
  external dGeomSphereSetRadius: sphere_geom dGeomID -> radius:float -> unit = "ocamlode_dGeomSphereSetRadius"
  external dGeomSpherePointDepth : sphere_geom dGeomID -> x:float -> y:float -> z:float -> float = "ocamlode_dGeomSpherePointDepth"

  external dCreateBox : dSpaceID option -> lx:float -> ly:float -> lz:float -> box_geom dGeomID = "ocamlode_dCreateBox"
  external dGeomBoxGetLengths : box_geom dGeomID -> dVector3 = "ocamlode_dGeomBoxGetLengths"
  external dGeomBoxSetLengths : box_geom dGeomID -> lx:float -> ly:float -> lz:float -> unit = "ocamlode_dGeomBoxSetLengths"
  external dGeomBoxPointDepth : box_geom dGeomID -> x:float -> y:float -> z:float -> float = "ocamlode_dGeomBoxPointDepth"

  external dCreatePlane : dSpaceID option -> a:float -> b:float -> c:float -> d:float -> plane_geom dGeomID = "ocamlode_dCreatePlane"
  external dGeomPlaneGetParams : plane_geom dGeomID -> dVector4 = "ocamlode_dGeomPlaneGetParams"
  external dGeomPlaneSetParams : plane_geom dGeomID -> a:float -> b:float -> c:float -> d:float -> unit = "ocamlode_dGeomPlaneSetParams"
  external dGeomPlanePointDepth : plane_geom dGeomID -> x:float -> y:float -> z:float -> unit = "ocamlode_dGeomPlanePointDepth"

  external dCreateCapsule : dSpaceID option -> radius:float -> length:float -> capsule_geom dGeomID = "ocamlode_dCreateCapsule"
  external dGeomCapsuleGetParams : capsule_geom dGeomID -> float * float = "ocamlode_dGeomCapsuleGetParams"
  external dGeomCapsuleSetParams : capsule_geom dGeomID -> radius:float -> length:float -> unit = "ocamlode_dGeomCapsuleSetParams"
  external dGeomCapsulePointDepth : capsule_geom dGeomID -> x:float -> y:float -> z:float -> unit = "ocamlode_dGeomCapsulePointDepth"

  external dCreateCylinder : dSpaceID option -> radius:float -> length:float -> cylinder_geom dGeomID = "ocamlode_dCreateCylinder"
  external dGeomCylinderGetParams : cylinder_geom dGeomID -> float * float = "ocamlode_dGeomCylinderGetParams"
  external dGeomCylinderSetParams : cylinder_geom dGeomID -> radius:float -> length:float -> unit = "ocamlode_dGeomCylinderSetParams"

  external dCreateRay : dSpaceID option -> length:float -> ray_geom dGeomID = "ocamlode_dCreateRay"
  external dGeomRaySetLength : ray_geom dGeomID -> length:float -> unit = "ocamlode_dGeomRaySetLength"
  external dGeomRayGetLength : ray_geom dGeomID -> float = "ocamlode_dGeomRayGetLength"
  external dGeomRaySet : ray_geom dGeomID -> px:float -> py:float -> pz:float -> dx:float -> dy:float -> dz:float -> unit
                            = "ocamlode_dGeomRaySet_bytecode"
                              "ocamlode_dGeomRaySet_native"
  external dGeomRayGet : ray_geom dGeomID -> (* start *) dVector3 * (* dir *) dVector3 = "ocamlode_dGeomRayGet"
  external dGeomRaySetClosestHit : ray_geom dGeomID -> closest_hit:bool -> unit = "ocamlode_dGeomRaySetClosestHit"
  external dGeomRayGetClosestHit : ray_geom dGeomID -> bool = "ocamlode_dGeomRayGetClosestHit"

  type dTriMeshDataID
  external dGeomTriMeshDataCreate : unit -> dTriMeshDataID = "ocamlode_dGeomTriMeshDataCreate"
  external dGeomTriMeshDataDestroy : dTriMeshDataID -> unit = "ocamlode_dGeomTriMeshDataDestroy"
  (** {b Frees the associated datas} (see [dGeomTriMeshDataBuild] for explanations) *)
  external dGeomTriMeshDataPreprocess : dTriMeshDataID -> unit = "ocamlode_dGeomTriMeshDataPreprocess"
  external dGeomTriMeshSetData : trimesh_geom dGeomID -> data:dTriMeshDataID -> unit = "ocamlode_dGeomTriMeshSetData"
  external dGeomTriMeshGetData : trimesh_geom dGeomID -> dTriMeshDataID = "ocamlode_dGeomTriMeshGetData"
  external dGeomTriMeshGetTriMeshDataID : trimesh_geom dGeomID -> dTriMeshDataID = "ocamlode_dGeomTriMeshGetTriMeshDataID"
  external dGeomTriMeshDataUpdate : dTriMeshDataID -> unit = "ocamlode_dGeomTriMeshDataUpdate"
  external dGeomTriMeshDataBuild : dTriMeshDataID -> vertices: float array -> indices: int array -> unit
      = "ocamlode_dGeomTriMeshDataBuildDouble"
  (** {b Important:} The vertices parameter is not copied for ODE's use so make sure that it is
      not garbage collected as long as it trimesh is still used.
      (The indices parameter's datas are copied to a buffer associated with the dTriMeshDataID,
      which is freed at the same time with the function [dGeomTriMeshDataDestroy].)
  *)

  external dCreateTriMesh : dSpaceID option -> dTriMeshDataID ->
                            ?tri_cb:'a -> ?arr_cb:'b -> ?ray_cb:'c -> unit -> trimesh_geom dGeomID
                            = "ocamlode_dCreateTriMesh_bytecode"
                              "ocamlode_dCreateTriMesh_native"
  (** the callbacks are not implemented yet, just omit the optional parameters *)

  external dGeomTriMeshEnableTC : trimesh_geom dGeomID -> geom_class -> bool -> unit = "ocamlode_dGeomTriMeshEnableTC"
  external dGeomTriMeshIsTCEnabled : trimesh_geom dGeomID -> geom_class -> bool = "ocamlode_dGeomTriMeshIsTCEnabled"
  external dGeomTriMeshClearTCCache : trimesh_geom dGeomID -> unit = "ocamlode_dGeomTriMeshClearTCCache"


  (*
  (* old version *)
  external dCreateConvex : dSpaceID option -> planes:float array ->
                                              points:float array ->
                                              polygones:int array -> convex_geom dGeomID = "ocamlode_dCreateConvex"
  *)
  type dConvexDataID
  external dConvexDataBuild : planes:float array ->
                              points:float array ->
                              polygones:int array -> dConvexDataID = "ocamlode_get_dConvexDataID"
  (** {b Important:} the [dConvexDataID] needs to be freed with [dConvexDataDestroy] at the end. *)

  external dCreateConvex : dSpaceID option -> dConvexDataID -> convex_geom dGeomID = "ocamlode_dCreateConvex"
  external dGeomSetConvex : convex_geom dGeomID -> dConvexDataID -> unit = "ocamlode_dGeomSetConvex"
  external dConvexDataDestroy : dConvexDataID -> unit = "ocamlode_free_dConvexDataID"
  (** {b Important:} do not destroy the [dConvexDataID] as long as the associated convex geom is used. *)


  type dHeightfieldDataID
  external dGeomHeightfieldDataCreate: unit -> dHeightfieldDataID = "ocamlode_dGeomHeightfieldDataCreate"
  external dGeomHeightfieldDataDestroy: id:dHeightfieldDataID -> unit = "ocamlode_dGeomHeightfieldDataDestroy"
  external dCreateHeightfield: dSpaceID option -> data:dHeightfieldDataID -> placeable:bool -> heightfield_geom dGeomID
      = "ocamlode_dCreateHeightfield"
  external dGeomHeightfieldDataBuild:
                id:dHeightfieldDataID ->
                height_data:float array ->
                width:float -> depth:float -> width_samples:int -> depth_samples:int ->
                scale:float -> offset:float -> thickness:float -> wrap:bool -> unit
                = "ocamlode_dGeomHeightfieldDataBuild_bytecode"
                  "ocamlode_dGeomHeightfieldDataBuild"


  external dGeomSetData : 'a dGeomID -> int -> unit = "ocamlode_dGeomSetData"
  external dGeomGetData : 'a dGeomID -> int = "ocamlode_dGeomGetData"
  (** you can use these functions for example to associate user data to a geometry: {[
  let geom_data_tbl = Hashtbl.create 16
  let geom_data_count = ref 0
  let dGeomSetData geom ~data =
    let i = !geom_data_count in
    incr geom_data_count;
    Hashtbl.add geom_data_tbl i data;
    dGeomSetData geom i;
  ;;
  let dGeomGetData geom = (Hashtbl.find geom_data_tbl (dGeomGetData geom))
  ]} *)

  external dGeomIsSpace : 'a dGeomID -> bool = "ocamlode_dGeomIsSpace"
  external dGeomGetSpace : 'a dGeomID -> dSpaceID = "ocamlode_dGeomGetSpace"


  external dGeomSetCategoryBits : 'a dGeomID -> bits:int -> unit = "ocamlode_dGeomSetCategoryBits"
  external dGeomSetCollideBits : 'a dGeomID -> bits:int -> unit = "ocamlode_dGeomSetCollideBits"
  external dGeomGetCategoryBits : 'a dGeomID -> int = "ocamlode_dGeomGetCategoryBits"
  external dGeomGetCollideBits : 'a dGeomID -> int = "ocamlode_dGeomGetCollideBits"
  (** {[
if ( ((g1.category_bits & g2.collide_bits) ||
      (g2.category_bits & g1.collide_bits)) == 0) ]} *)

  external dGeomEnable : 'a dGeomID -> unit = "ocamlode_dGeomEnable"
  external dGeomDisable : 'a dGeomID -> unit = "ocamlode_dGeomDisable"
  external dGeomIsEnabled : 'a dGeomID -> bool = "ocamlode_dGeomIsEnabled"

  external dGeomSetOffsetPosition : 'a dGeomID -> x:float -> y:float -> z:float -> unit = "ocamlode_dGeomSetOffsetPosition"
  external dGeomSetOffsetRotation : 'a dGeomID -> r:dMatrix3 -> unit = "ocamlode_dGeomSetOffsetRotation"

  external dGeomSetOffsetQuaternion : 'a dGeomID -> dQuaternion -> unit = "ocamlode_dGeomSetOffsetQuaternion"
  external dGeomGetOffsetQuaternion : 'a dGeomID -> dQuaternion = "ocamlode_dGeomGetOffsetQuaternion"
  external dGeomSetOffsetWorldPosition : 'a dGeomID -> x:float -> y:float -> z:float -> unit = "ocamlode_dGeomSetOffsetWorldPosition"
  external dGeomSetOffsetWorldRotation : 'a dGeomID -> dMatrix3 -> unit = "ocamlode_dGeomSetOffsetWorldRotation"
  external dGeomSetOffsetWorldQuaternion : 'a dGeomID -> dQuaternion -> unit = "ocamlode_dGeomSetOffsetWorldQuaternion"
  external dGeomClearOffset : 'a dGeomID -> unit = "ocamlode_dGeomClearOffset"
  external dGeomIsOffset : 'a dGeomID -> bool = "ocamlode_dGeomIsOffset"

  (*
  external dGeomCopyOffsetPosition : 'a dGeomID -> dVector3 = "ocamlode_dGeomCopyOffsetPosition"
  external dGeomCopyOffsetRotation : 'a dGeomID -> dMatrix3 = "ocamlode_dGeomCopyOffsetRotation"
  *)
  (* from the OCaml world *CopyOffset* and *GetOffset* are equivalent *)
  external dGeomGetOffsetPosition : 'a dGeomID -> dVector3 = "ocamlode_dGeomGetOffsetPosition"
  external dGeomGetOffsetRotation : 'a dGeomID -> dMatrix3 = "ocamlode_dGeomGetOffsetRotation"


  (** {3 Mass functions} *)
  (**  Note that dMass objects are garbage collected. *)

  external dMassCreate : unit -> dMass = "ocamlode_dMassCreate"
  external dMass_set_mass : dMass -> float -> unit = "ocamlode_dMass_set_mass"
  external dMass_mass : dMass -> float = "ocamlode_dMass_mass"
  external dMass_set_c : dMass -> dVector4 -> unit = "ocamlode_dMass_set_c"
  external dMass_c : dMass -> dVector4 = "ocamlode_dMass_c"
  external dMass_set_I : dMass -> dMatrix3 -> unit = "ocamlode_dMass_set_I"
  external dMass_I : dMass -> dMatrix3 = "ocamlode_dMass_I"

  external dMassSetZero : dMass -> unit = "ocamlode_dMassSetZero"

  external dMassSetParameters : dMass -> mass:float -> cgx:float -> cgy:float -> cgz:float ->
                i11:float -> i22:float -> i33:float -> i12:float -> i13:float -> i23:float -> unit
      = "ocamlode_dMassSetParameters_bc" "ocamlode_dMassSetParameters"

  external dMassSetSphere : dMass -> density:float -> radius:float -> unit = "ocamlode_dMassSetSphere"
  external dMassSetSphereTotal : dMass -> total_mass:float -> radius:float -> unit = "ocamlode_dMassSetSphereTotal"

  external dMassSetBox : dMass -> density:float -> lx:float -> ly:float -> lz:float -> unit = "ocamlode_dMassSetBox"
  external dMassSetBoxTotal : dMass -> total_mass:float -> lx:float -> ly:float -> lz:float -> unit = "ocamlode_dMassSetBoxTotal"

  type direction = Dir_x | Dir_y | Dir_z

  external dMassSetCapsule : dMass -> density:float -> direction:direction -> radius:float -> length:float -> unit
      = "ocamlode_dMassSetCapsule"
  external dMassSetCapsuleTotal : dMass -> total_mass:float -> direction:direction -> radius:float -> length:float -> unit
      = "ocamlode_dMassSetCapsuleTotal"

  external dMassSetCylinder : dMass -> density:float -> direction:direction -> radius:float -> length:float -> unit
      = "ocamlode_dMassSetCylinder"
  external dMassSetCylinderTotal : dMass -> total_mass:float -> direction:direction -> radius:float -> length:float -> unit
      = "ocamlode_dMassSetCylinderTotal"

  external dMassSetTrimesh : dMass -> density:float -> trimesh_geom dGeomID -> unit = "ocamlode_dMassSetTrimesh"
  external dMassSetTrimeshTotal : dMass -> total_mass:float -> trimesh_geom dGeomID -> unit = "ocamlode_dMassSetTrimeshTotal"

  external dMassCheck : dMass -> bool = "ocamlode_dMassCheck"

  external dMassAdjust : dMass -> float -> unit = "ocamlode_dMassAdjust"
  external dMassTranslate : dMass -> x:float -> y:float -> z:float -> unit = "ocamlode_dMassTranslate"
  external dMassRotate : dMass -> dMatrix3 -> unit = "ocamlode_dMassRotate"
  external dMassAdd : dMass -> dMass -> unit = "ocamlode_dMassAdd"


  (** {3 Matrices} *)

  external dRGetIdentity : unit -> dMatrix3 = "ocamlode_dRSetIdentity"
  external dRFromAxisAndAngle : ax:float -> ay:float -> az:float -> angle:float -> dMatrix3 = "ocamlode_dRFromAxisAndAngle"
  external dRFromEulerAngles : phi:float -> theta:float -> psi:float -> dMatrix3 = "ocamlode_dRFromEulerAngles"


  (** {3 Quaternion} *)

  external dQGetIdentity : unit -> dQuaternion = "ocamlode_dQSetIdentity"
  external dQFromAxisAndAngle : ax:float -> ay:float -> az:float -> angle:float -> dQuaternion = "ocamlode_dQFromAxisAndAngle"


  (** {3 Misc} *)

  external dWorldImpulseToForce : dWorldID -> stepsize:float -> ix:float -> iy:float -> iz:float -> dVector3
      = "ocamlode_dWorldImpulseToForce"
  (*
  external dWorldExportDIF : dWorldID -> filename:string -> world_name:string -> unit = "ocamlode_dWorldExportDIF"
  *)

  external dQtoR : dQuaternion -> dMatrix3 = "ocamlode_dQtoR"
  external dPlaneSpace : n:dVector3 -> dVector3 * dVector3 = "ocamlode_dPlaneSpace"

  (**/**)

  let is_nan f = (Stdlib.compare nan f) = 0 ;;
  let dVALIDVEC3 v = not((is_nan v.x) || (is_nan v.y) || (is_nan v.z)) ;;
  let dVALIDVEC4 v = not((is_nan v.x) || (is_nan v.y) || (is_nan v.z) || (is_nan v.w)) ;;

  let dVALIDMAT3 m =
    not( (is_nan m.r11) || (is_nan m.r12) || (is_nan m.r13) || (is_nan m.r14) ||
         (is_nan m.r21) || (is_nan m.r22) || (is_nan m.r23) || (is_nan m.r24) ||
         (is_nan m.r31) || (is_nan m.r32) || (is_nan m.r33) || (is_nan m.r34) ) ;;

  let dVALIDMAT4 m =
    not( (is_nan m.s11) || (is_nan m.s12) || (is_nan m.s13) || (is_nan m.s14) ||
         (is_nan m.s21) || (is_nan m.s22) || (is_nan m.s23) || (is_nan m.s24) ||
         (is_nan m.s31) || (is_nan m.s32) || (is_nan m.s33) || (is_nan m.s34) ||
         (is_nan m.s41) || (is_nan m.s42) || (is_nan m.s43) || (is_nan m.s44) ) ;;

  let dLENGTH a = sqrt( (a.x *. a.x) +. (a.y *. a.y) +. (a.z *. a.z) )

  let dMULTIPLY0_331 rot pos =
  {
    x = rot.r11 *. pos.x +. rot.r12 *. pos.y +. rot.r13 *. pos.z;
    y = rot.r21 *. pos.x +. rot.r22 *. pos.y +. rot.r23 *. pos.z;
    z = rot.r31 *. pos.x +. rot.r32 *. pos.y +. rot.r33 *. pos.z;
    w = 0.0
  }

  let dMULTIPLY0_333 rot1 rot2 =
  {
    r11 = rot1.r11 *. rot2.r11 +. rot1.r12 *. rot2.r21 +. rot1.r13 *. rot2.r31;
    r12 = rot1.r11 *. rot2.r12 +. rot1.r12 *. rot2.r22 +. rot1.r13 *. rot2.r32;
    r13 = rot1.r11 *. rot2.r13 +. rot1.r12 *. rot2.r23 +. rot1.r13 *. rot2.r33;
    r21 = rot1.r21 *. rot2.r11 +. rot1.r22 *. rot2.r21 +. rot1.r23 *. rot2.r31;
    r22 = rot1.r21 *. rot2.r12 +. rot1.r22 *. rot2.r22 +. rot1.r23 *. rot2.r32;
    r23 = rot1.r21 *. rot2.r13 +. rot1.r22 *. rot2.r23 +. rot1.r23 *. rot2.r33;
    r31 = rot1.r31 *. rot2.r11 +. rot1.r32 *. rot2.r21 +. rot1.r33 *. rot2.r31;
    r32 = rot1.r31 *. rot2.r12 +. rot1.r32 *. rot2.r22 +. rot1.r33 *. rot2.r32;
    r33 = rot1.r31 *. rot2.r13 +. rot1.r32 *. rot2.r23 +. rot1.r33 *. rot2.r33;
    r14 = rot1.r14;
    r24 = rot1.r24;
    r34 = rot1.r34;
    (*  r34 ?  0.0  1.0  rot2.r34  *)
  }

  let dSafeNormalize3_ml a =
    let copy_sign l a =
      if l > 0.0 && a > 0.0 then a else
      if l < 0.0 && a < 0.0 then a else (-. a)
    in
    let a0 = a.x
    and a1 = a.y
    and a2 = a.z
    in
    let aa0 = abs_float a0
    and aa1 = abs_float a1
    and aa2 = abs_float a2
    in
    let aa2_largest () =
      let a0 = a0 /. aa2
      and a1 = a1 /. aa2 in
      let l = sqrt (a0*.a0 +. a1*.a1 +. 1.) in
      { x = a0 *. l;
        y = a1 *. l;
        z = copy_sign l a2;
        w = 0. }
    in
    let aa1_largest () =
      let a0 = a0 /. aa1
      and a2 = a2 /. aa1 in
      let l = sqrt (a0*.a0 +. a2*.a2 +. 1.) in
      { x = a0 *. l;
        y = copy_sign l a1;
        z = a2 *. l;
        w = 0. }
    in
    let aa0_largest () =
      if (aa0 <= 0.) then
      { x = 1.;       (* if all a's are zero, this is where we'll end up. *)
        y = 0.;       (* return a default unit length vector. *)
        z = 0.;
        w = 0.; }
      else
      let a1 = a1 /. aa0
      and a2 = a2 /. aa0 in
      let l = sqrt (a1*.a1 +. a2*.a2 +. 1.) in
      { x = copy_sign l a0;
        y = a1 *. l;
        z = a2 *. l;
        w = 0. }
    in
    if (aa2 > aa0 && aa2 > aa1) then aa2_largest () else
    if (aa1 > aa0 && aa1 > aa2) then aa1_largest () else
    aa0_largest ()
  ;;

  external dSafeNormalize3_ode : dVector3 -> dVector3 = "ocamlode_dSafeNormalize3"
  let dNormalize3 = dSafeNormalize3_ode ;;

  external dNormalize4 : dVector4 -> dVector4 = "ocamlode_dSafeNormalize4"
  external dQNormalize4 : dQuaternion -> dQuaternion = "ocamlode_dSafeNormalize4"

  external dMaxDifference : a:dVector3 -> b:dVector3 -> n:int -> m:int -> float = "ocamlode_dMaxDifference"
  external dQMaxDifference : a:dQuaternion -> b:dQuaternion -> n:int -> m:int -> float = "ocamlode_dMaxDifference"

  external dMultiply0 : 'a -> 'b -> p:int -> q:int -> r:int -> float array = "ocamlode_dMultiply0"

  (*
      a(p*q)  b(q*r)  v(p*r)
  *)
  let dMultiply0_331 (a : dMatrix3) (b : 'a) =
    let _b = (Obj.magic b : float array) in
    assert(Array.length _b = 3);
    let v = dMultiply0 a _b ~p:3 ~q:3 ~r:1 in
    (Obj.magic v : dVector3)
  ;;

  let dMultiply0_333 (a : dMatrix3) (b : 'a) =
    let _b = (Obj.magic b : float array) in
    assert(Array.length _b = 12);
    let v = dMultiply0 a _b ~p:3 ~q:3 ~r:3 in
    (Obj.magic v : dMatrix3)
  ;;

  external memory_share : unit -> bool = "ocamlode_memory_share"
  (** tells whether the bindings were compiled to share structures memory *)

end

