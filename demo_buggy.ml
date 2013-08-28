(*
 * Open Dynamics Engine, Copyright (C) 2001,2002 Russell L. Smith.
 * All rights reserved.  Email: russ@q12.org   Web: www.q12.org
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of EITHER:
 *   (1) The GNU Lesser General Public License as published by the Free
 *       Software Foundation; either version 2.1 of the License, or (at
 *       your option) any later version. The text of the GNU Lesser
 *       General Public License is included with this library in the
 *       file LICENSE_LGPL.txt.
 *   (2) The BSD-style license that is included with this library in
 *       the file LICENSE_BSD.txt.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the files
 * LICENSE_LGPL.txt and LICENSE_BSD.txt for more details.
 *)

(* Converted from C to OCaml by F. Monnier <fmonnier@linux-nantes.org> *)

(*
  buggy with suspension.
  this also shows you how to use geom groups.
*)

open Ode.LowLevel
open Drawstuff


(* some constants *)

let length = 0.7    (* chassis length *)
let width  = 0.5    (* chassis width *)
let height = 0.2    (* chassis height *)
let radius = 0.18   (* wheel radius *)
let startz = 0.5    (* starting height of chassis *)
let cmass  = 1.0    (* chassis mass *)
let wmass  = 0.2    (* wheel mass *)



(* things that the user controls *)

let speed = ref 0.
let steer = ref 0.     (* user commands *)


(* usage message *)
let usage() =
  print_endline
      "Press:\n  \
         'a' to increase speed.\n  \
         'z' to decrease speed.\n  \
         '1' to steer left.\n  \
         '2' to steer right.\n  \
         ' ' to reset speed and steering.\n";
;;


let ( += ) a b = (a := !a +. b)
let ( -= ) a b = (a := !a -. b)

(* called when a key pressed *)
let command = function
  | 'a' | 'A' -> speed += 0.3;
  | 'z' | 'Z' -> speed -= 0.3;
  | '1' -> steer -= 0.5;
  | '2' -> steer += 0.5;
  | ' ' ->
      speed := 0.;
      steer := 0.;
  | _ -> ()
;;


let b_xor a b =
  match a, b with
  | false, false | true, true -> false
  | _ -> true
;;

(* this is called by dSpaceCollide when two objects in space are *)
(* potentially colliding. *)

let near_callback world ground ground_box contactgroup = fun o1 o2 ->
  let _o1 = geom_kind o1
  and _o2 = geom_kind o2
  in
  (* only collide things with the ground *)
  let g1 = (_o1 = (Plane_geom ground) || _o1 = (Box_geom ground_box))
  and g2 = (_o2 = (Plane_geom ground) || _o2 = (Box_geom ground_box))
  in
  if not(b_xor g1 g2) then ()
  else begin
    let contact_geom_ar = dCollide o1 o2 10 in
    ArrayLabels.iter contact_geom_ar ~f:(fun contact_geom ->
      let surface = { surf_param_zero with
        sp_mode = [`dContactSlip1; `dContactSoftERP;
                   `dContactSlip2; `dContactSoftCFM; `dContactApprox1];
        sp_mu = dInfinity;
        sp_slip1 = 0.1;
        sp_slip2 = 0.1;
        sp_soft_erp = 0.5;
        sp_soft_cfm = 0.3;
      } in
      let contact = {
        c_surface = surface;
        c_geom = contact_geom;
        c_fdir1 = {x=0.; y=0.; z=0.; w=0.}
      } in
      let c = dJointCreateContact world (Some contactgroup) contact in
      dJointAttach c (dGeomGetBody contact_geom.cg_g1)
                     (dGeomGetBody contact_geom.cg_g2);
    );
  end;
;;


(* simulation loop *)

let sim_loop world space ground ground_box joint contactgroup = fun pause ->
  if not(pause) then
  begin
    (* motor *)
    dJointSetHinge2Param joint.(0) DParamVel2 (-. !speed);
    dJointSetHinge2Param joint.(0) DParamFMax2 0.1;

    (* steering *)
    let v = !steer -. (dJointGetHinge2Angle1 joint.(0)) in
    let v = if v > 0.1 then 0.1 else v in
    let v = if v < -0.1 then -0.1 else v in
    let v = v *. 10.0 in
    dJointSetHinge2Param joint.(0) DParamVel v;
    dJointSetHinge2Param joint.(0) DParamFMax 0.2;
    dJointSetHinge2Param joint.(0) DParamLoStop (-0.75);
    dJointSetHinge2Param joint.(0) DParamHiStop ( 0.75);
    dJointSetHinge2Param joint.(0) DParamFudgeFactor 0.1;

    dSpaceCollide space (near_callback world ground ground_box contactgroup);
    dWorldStep world 0.05;

    (* remove all contact joints *)
    dJointGroupEmpty contactgroup;
  end;
;;


(* display the scene *)

let sim_draw body ground_box joint = fun () ->
  let color = (0., 0.2, 0.8)
  and sides = (length, width, height) in
  dsDrawBox (dBodyGetPosition body.(0)) 
            (dBodyGetRotation body.(0)) sides color;

  let color = (0., 0.6, 1.) in
  for i=1 to 3 do
    dsDrawCylinder (dBodyGetPosition body.(i))
                   (dBodyGetRotation body.(i)) 0.02 radius color;
    (*
    dsDrawSphere (dBodyGetPosition body.(i))
                 (dBodyGetRotation body.(i)) radius color;
    *)
  done;

  let ss = dGeomBoxGetLengths ground_box in
  dsDrawBox (dGeomGetPosition ground_box)
            (dGeomGetRotation ground_box) (ss.x, ss.y, ss.z) color;

  dsDrawPlane (3.0, 0.0, 0.0) ~scale:(2.0) (1.0, 0.0, 0.0);

  (*
  Printf.printf "%.10f %.10f %.10f %.10f\n"
          (dJointGetHinge2Angle1 joint.(1))
          (dJointGetHinge2Angle1 joint.(2))
          (dJointGetHinge2Angle1Rate joint.(1))
          (dJointGetHinge2Angle1Rate joint.(2));
  *)
;;


let pi = 3.1415926535_8979323846

(* main *)
let () =
  usage();
  let m = dMassCreate() in

  (* create world *)
  dInitODE();
  let world = dWorldCreate()
  and space = dHashSpaceCreate None
  and contactgroup = dJointGroupCreate()
  in
  dWorldSetGravity world 0. 0. (-0.5);
  let ground = dCreatePlane (Some space) 0. 0. 1. 0. in

  (* dynamics and collision objects (chassis, 3 wheels, environment) *)

  let body = Array.init 4 (fun _ -> dBodyCreate world) in

  (* chassis body *)
  dBodySetPosition body.(0) 0. 0. startz;
  dMassSetBox m 1. length width height;
  dMassAdjust m cmass;
  dBodySetMass body.(0) m;
  let box = [|
    dCreateBox None length width height;
  |] in
  dGeomSetBody box.(0) (Some body.(0));

  (* wheel bodies *)
  let sphere =
    Array.init 3 (fun i ->
      let q = dQFromAxisAndAngle 1. 0. 0. (pi *. 0.5) in
      dBodySetQuaternion body.(i+1) q;
      dMassSetSphere m 1. radius;
      dMassAdjust m wmass;
      dBodySetMass body.(i+1) m;
      let sphere = dCreateSphere None radius in
      dGeomSetBody sphere (Some body.(i+1));
      (sphere))
  in
  dBodySetPosition body.(1) ( 0.5 *. length) ( 0.0 )           (startz -. height *. 0.5);
  dBodySetPosition body.(2) (-0.5 *. length) (   width *. 0.5) (startz -. height *. 0.5);
  dBodySetPosition body.(3) (-0.5 *. length) (-. width *. 0.5) (startz -. height *. 0.5);

  (* front and back wheel hinges *)
  let joint =
    (* joint.(0) is the front wheel *)
    Array.init 3 (fun i ->
      let joint = dJointCreateHinge2 world None in
      dJointAttach joint (Some body.(0)) (Some body.(i+1));
      let a = dBodyGetPosition body.(i+1) in
      dJointSetHinge2Anchor joint a.x a.y a.z;
      dJointSetHinge2Axis1 joint 0. 0. 1.;
      dJointSetHinge2Axis2 joint 0. 1. 0.;
      (joint)
    )
  in

  (* set joint suspension *)
  for i=0 to pred 3 do
    dJointSetHinge2Param joint.(i) DParamSuspensionERP 0.4;
    dJointSetHinge2Param joint.(i) DParamSuspensionCFM 0.8;
  done;

  (* lock back wheels along the steering axis *)
  for i=1 to pred 3 do
    (* set stops to make sure wheels always stay in alignment *)
    dJointSetHinge2Param joint.(i) DParamLoStop 0.;
    dJointSetHinge2Param joint.(i) DParamHiStop 0.;
    (*
    (* the following alternative method is no good as the wheels may get out
       of alignment: *)
    dJointSetHinge2Param joint.(i) DParamVel 0.;
    dJointSetHinge2Param joint.(i) DParamFMax dInfinity;
    *)
  done;

  (* create car space and add it to the top level space *)
  let car_space = dSimpleSpaceCreate (Some space) in
  dSpaceSetCleanup car_space false;
  dSpaceAdd car_space box.(0);
  dSpaceAdd car_space sphere.(0);
  dSpaceAdd car_space sphere.(1);
  dSpaceAdd car_space sphere.(2);

  (* environment *)
  let ground_box = dCreateBox (Some space) 2. 1.5 1. in
  let r = dRFromAxisAndAngle 0. 1. 0. (-0.15) in
  dGeomSetPosition ground_box 2. 0. (-0.34);
  dGeomSetRotation ground_box r;

  let destroy_all() =
    dGeomDestroy box.(0);
    Array.iter dGeomDestroy sphere;
    Array.iter dBodyDestroy body;
    dJointGroupDestroy contactgroup;
    dSpaceDestroy space;
    dWorldDestroy world;
    dCloseODE();
  in

  begin
    (* set initial viewpoint *)
    let pos = (3.0, 4.9, -2.6)
    and angles = (102.6, 235.2) in

    (* call sim_step every N milliseconds *)
    let timer_msecs = 20 in

    (* simulation params (for the drawstuff lib) *)
    let dsd =
      ( (pos, angles, timer_msecs, world),
        (sim_draw body ground_box joint),
        (sim_loop world space ground ground_box joint contactgroup),
        (command),
        (destroy_all)
      )
    in
    (* run simulation *)
    dsSimulationLoop 480 360 dsd;
  end;
;;

