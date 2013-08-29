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

(* Test for cylinder vs sphere, by Bram Stolk *)

(* Converted from C to OCaml by Florent Monnier *)

open Ode.LowLevel
open Drawstuff

let show_contacts = true

let cyl_radius = 0.6
let cyl_length = 2.0
let sphere_radius = 0.5

    
let draw_contacts = ref (fun () -> ()) ;;

(* this is called by dSpaceCollide when two objects in space are *)
(* potentially colliding. *)

let rec nearCallback world contactgroup = fun o1 o2 ->
  if (dGeomIsSpace o1) || (dGeomIsSpace o2) then
  begin
    Printf.eprintf "colliding space\n%!";
    (* colliding a space with something *)
    dSpaceCollide2 o1 o2 (nearCallback world contactgroup);
    (* Note we do not want to test intersections within a space, *)
    (* only between spaces. *)
    ()
  end else
  begin
    let contact_geom_arr = dCollide o1 o2 32 in
    ArrayLabels.iter contact_geom_arr ~f:(function contact_geom ->
      let contact = {
        c_surface = { surf_param_zero with sp_mu = 50.0 };
        c_geom = contact_geom;
        c_fdir1 = {x=0.; y=0.; z=0.; w=0.}
      } in
      let c = dJointCreateContact world (Some contactgroup) contact in
      dJointAttach c (dGeomGetBody contact_geom.cg_g1) (dGeomGetBody contact_geom.cg_g2);
      draw_contacts := (function () ->
        if (show_contacts) then
        begin
          let ri = dRGetIdentity() in
          let ss = (0.12,0.12,0.12) in
          let color = (0.6, 0.8, 0.9)
          in
          let pos  = contact_geom.cg_pos
          and depth = contact_geom.cg_depth
          and norm = contact_geom.cg_normal
          in
          dsDrawBox pos ri ss color;
          let endp =
            { x = pos.x +. depth *. norm.x;
              y = pos.y +. depth *. norm.y;
              z = pos.z +. depth *. norm.z;
              w = 0. }
          in
          let color = (0.7, 0.9, 1.0) in
          dsDrawLine pos endp color;
        end;
      );
    );
  end;
;;


(* called when a key pressed *)

let command = function
  | ' ' -> ()
  | _ -> ()
;;


(* simulation step *)

let sim_step world space contactgroup = fun pause ->
  dSpaceCollide space (nearCallback world contactgroup);
  if not(pause) then
    dWorldQuickStep world  0.01; (* 100 Hz *)
  dJointGroupEmpty contactgroup;
;;


(* draw the scene *)

let sim_draw cylbody sphbody = fun () ->
  let color = (1.0, 0.8, 0.0) in
  (*
  dsDrawCylinder (dBodyGetPosition cylbody)
                 (dBodyGetRotation cylbody) cyl_length cyl_radius color;
  *)
  dsDrawWireCylinder (dBodyGetPosition cylbody)
                     (dBodyGetRotation cylbody) cyl_length cyl_radius color;

  (*
  dsDrawSphere (dBodyGetPosition sphbody)
               (dBodyGetRotation sphbody) sphere_radius color;
  *)
  dsDrawWireSphere (dBodyGetPosition sphbody)
                   (dBodyGetRotation sphbody) sphere_radius color;

  (!draw_contacts)();

  dsDrawPlane (0.0, 0.0, 0.0) (1.0, 0.0, 0.0);
;;


let pi = 3.1415926535_8979323846

(* main *)
let () =
  let m = dMassCreate() in

  (* create world *)
  dInitODE();
  let world = dWorldCreate()
  and space = dHashSpaceCreate None
  and contactgroup = dJointGroupCreate() in
  dWorldSetGravity world 0. 0. (-9.8);
  dWorldSetQuickStepNumIterations world 32;

  (* dynamics and collision objects *)

  let _ = dCreatePlane (Some space) 0. 0. 1.  0.0 in

  let cylbody = dBodyCreate world in
  (*
  let q = dQFromAxisAndAngle 1. 0. 0. (pi *. 0.5) in
  let q = dQFromAxisAndAngle 1. 0. 0. (pi *. 1.0) in
  *)
  let q = dQFromAxisAndAngle 1. 0. 0. (pi *. (-0.77)) in

  dBodySetQuaternion cylbody q;
  dMassSetCylinder m 1.0 Dir_z cyl_radius cyl_length;
  dBodySetMass cylbody m;
  let cylgeom = dCreateCylinder None cyl_radius cyl_length in
  dGeomSetBody cylgeom (Some cylbody);
  dBodySetPosition cylbody 0. 0. 3.;
  dSpaceAdd space cylgeom;

  let sphbody = dBodyCreate world in
  dMassSetSphere m 1. sphere_radius;
  dBodySetMass sphbody m;
  let sphgeom = dCreateSphere None sphere_radius in
  dGeomSetBody sphgeom (Some sphbody);
  dBodySetPosition sphbody 0. 0. 5.5;
  dSpaceAdd space sphgeom;

  let free_env() =
    dJointGroupEmpty (contactgroup);
    dJointGroupDestroy (contactgroup);

    dGeomDestroy(sphgeom);
    dGeomDestroy (cylgeom);

    dSpaceDestroy (space);
    dWorldDestroy (world);
    dCloseODE();
  in

  begin
    (* set initial viewpoint *)
    let pos = (5.9, 5.7, -5.0)
    and angles = (112.2, 211.6) in

    (* call sim_step every N milliseconds *)
    let timer_msecs = 20 in

    (* simulation params (for the drawstuff lib) *)
    let dsd =
      ( (pos, angles, timer_msecs, world),
        (sim_draw cylbody sphbody),
        (sim_step world space contactgroup),
        (command),
        (free_env)
      )
    in
    (* run simulation *)
    dsSimulationLoop 480 360 dsd;
  end;
;;

