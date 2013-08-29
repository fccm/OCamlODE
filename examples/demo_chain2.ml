(* Open Dynamics Engine, Copyright (C) 2001,2002 Russell L. Smith.
 * All rights reserved.  Email: russ@q12.org   Web: www.q12.org
 *
 * This demo is free software; you can redistribute it and/or modify it
 * under the terms of EITHER:
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

(* Converted from C to OCaml by Florent Monnier *)

open Ode
open LowLevel
open Drawstuff

(* some constants *)

let num = 10          (* number of boxes *)
let side = (0.2)      (* side length of a box *)
let mass = (1.0)      (* mass of a box *)


(* this is called by space.collide when two objects in space are
   potentially colliding. *)

let nearCallback world contactgroup = fun o1 o2 ->
  let b1 = dGeomGetBody o1
  and b2 = dGeomGetBody o2 in
  let surf_params = {surf_param_zero with
    sp_mu = dInfinity;
  } in
  let create_contact () =
    let cnt_arr = dCollide o1 o2 5 in
    let mk_contact cnt_geom =
      let cnt = {
        c_surface = surf_params;
        c_geom = cnt_geom;
        c_fdir1 = { x=0.; y=0.; z=0.; w=0. }
      } in
      let j = dJointCreateContact world (Some contactgroup) cnt in
      dJointAttach j b1 b2;
    in
    Array.iter mk_contact cnt_arr;
  in
  match b1, b2 with
  | Some _b1, Some _b2
    (* exit without doing anything if the two bodies are connected by a joint *)
    when not(dAreConnected _b1 _b2) -> create_contact()
  | None, Some _
  | Some _, None -> create_contact()
  | _ -> ()
;;



let ( += ) a b = (a := !a +. b) ;;

(* drawing the scene *)
let sim_draw body = fun () ->
  let sides = (side,side,side)
  and color = (1.9, 0.7, 0.0)
  in
  for i=0 to pred num do
    dsDrawBox (dBodyGetPosition body.(i))
              (dBodyGetRotation body.(i)) sides color;
  done;
  dsDrawPlane (0.,0.,0.) (1.0, 0.0, 0.0);
;;


(* simulation step *)
let sim_step world space body contactgroup =
  let angle = ref 0.0 in
  (function pause ->
     if not(pause) then begin
       angle += 0.05;
       dBodyAddForce body.(num-1) 0. 0. (1.5 *. ((sin !angle) +. 1.0));

       dSpaceCollide space (nearCallback world contactgroup);
       dWorldStep world 0.05;

       (* remove all contact joints *)
       dJointGroupEmpty contactgroup;
     end;
  )
;;


(* main *)
let () =
  (* dynamics and collision objects *)
  let world = dWorldCreate()
  and space = dSimpleSpaceCreate None in
  let body = Array.init num (function _ -> dBodyCreate world) in
  let contactgroup = dJointGroupCreate() in

  let free_stuff() =
    dJointGroupDestroy contactgroup;
    Array.iter dBodyDestroy body;
    dSpaceDestroy space;
    dWorldDestroy world;
  in

  (* create world *)
  dInitODE();

  dWorldSetGravity world 0. 0. (-0.5);
  dWorldSetCFM world (1e-5);
  let plane = dCreatePlane (Some space) 0. 0. 1. 0. in

  let init_body i b =
    let k = (float i) *. side in
    dBodySetPosition b k k (k +. 0.4);
    let m = dMassCreate() in
    dMassSetBox m 1. side side side;
    dMassAdjust m mass;
    dBodySetMass body.(i) m;
    dBodySetData body.(i) i;
  in
  Array.iteri init_body body;

  let box =
    Array.init num (function i ->
      let b = dCreateBox (Some space) side side side in
      dGeomSetBody b (Some body.(i));
      (b))
  in
  let joint =
    Array.init (num-1) (function i ->
      let j = dJointCreateBall world None in
      dJointAttach j (Some body.(i)) (Some body.(i+1));
      let k = (float i +. 0.5) *. side in
      dJointSetBallAnchor j k k (k +. 0.4);
      (j))
  in

  let free_stuff() =
    Array.iter dJointDestroy joint;
    Array.iter dGeomDestroy box;
    dGeomDestroy plane;
    free_stuff();
    dCloseODE();
  in

  begin
    (* set initial viewpoint *)
    let pos = (3.7, -2.8, -1.4)
    and angles = (98.4, 304.8) in

    (* call sim_step every N milliseconds *)
    let timer_msecs = 20 in

    let dsd =
      ( (pos, angles, timer_msecs, world),
        (sim_draw body),
        (sim_step world space body contactgroup),
        (fun _ -> ()),
        (free_stuff)
      )
    in

    (* run simulation *)
    dsSimulationLoop 480 360 dsd;
  end;
;;

