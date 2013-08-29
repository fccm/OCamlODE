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

(*
 test the Coulomb friction approximation.

 a 10x10 array of boxes is made, each of which rests on the ground.
 a horizantal force is applied to each box to try and get it to slide.
 box[i][j] has a mass (i+1)*mass and a force (j+1)*force. by the Coloumb
 friction model, the box should only slide if the force is greater than mu
 times the contact normal force, i.e.

   f > mu * body_mass * gravity
   (j+1)*force > mu * (i+1)*mass * gravity
   (j+1) > (i+1) * (mu*mass*gravity/force)
   (j+1) > (i+1) * k

 this should be independent of the number of contact points, as N contact
 points will each have 1/N'th the normal force but the pushing force will
 have to overcome N contacts. the constants are chosen so that k=1.
 thus you should see a triangle made of half the bodies in the array start
 to slide.
*)

(* Converted from C to OCaml by Florent Monnier *)

open Ode.LowLevel
open Drawstuff

(* some constants *)

let length = 0.2    (* box length & width *)
let height = 0.05   (* box height *)
let mass = 0.2      (* mass of box[i][j] = (i+1) * mass *)
let force = 0.05    (* force applied to box[i][j] = (j+1) * force *)
let mu = 0.5        (* the global mu to use *)
let gravity = 0.5   (* the global gravity to use *)
let n1 = 10         (* number of different forces to try *)
let n2 = 10         (* number of different masses to try *)



(* this is called by dSpaceCollide when two objects in space are *)
(* potentially colliding. *)

let nearCallback world ground contactgroup = fun o1 o2 ->
  (* only collide things with the ground *)
  if not(o1 <> ground && o2 <> ground) then
  begin
    let b1 = dGeomGetBody o1
    and b2 = dGeomGetBody o2 in

    (* up to 3 contacts per box *)
    let surf_param = {surf_param_zero with
      sp_mode = [`dContactSoftCFM; `dContactApprox1];
      sp_mu = mu;
      sp_soft_cfm = 0.01;
    } in
    let contact_geom_arr = dCollide o1 o2 3 in
    ArrayLabels.iter contact_geom_arr ~f:(fun contact_geom ->
      let contact = {
        c_surface = surf_param;
        c_geom = contact_geom;
        c_fdir1 = {x=0.; y=0.; z=0.; w=0.}
      } in
      let c = dJointCreateContact world (Some contactgroup) contact in
      dJointAttach c b1 b2;
    );
  end;
;;


(* simulation step *)
let sim_step world space ground body contactgroup =
  function true -> () (* pause *)
  | false ->
      (* apply forces to all bodies *)
      for i=0 to pred n1 do
        let body_i = body.(i) in
        for j=0 to pred n2 do
          dBodyAddForce body_i.(j) (force *. float(i+1)) 0. 0.;
        done;
      done;

      dSpaceCollide space (nearCallback world ground contactgroup);
      dWorldStep world 0.05;

      (* remove all contact joints *)
      dJointGroupEmpty contactgroup;
;;


(* display simulation scene *)
let sim_draw box = fun () ->
  let color = (1.,0.,1.)
  and sides = (length, length, height) in
  for i=0 to pred n1 do
    let box_i = box.(i) in
    for j=0 to pred n2 do
      let box_ij = box_i.(j) in
      dsDrawBox (dGeomGetPosition box_ij)
                (dGeomGetRotation box_ij) sides color;
    done;
  done;
;;


(* main *)
let () =
  let m = dMassCreate() in

  (* create world *)
  dInitODE();
  let world = dWorldCreate()
  and space = dHashSpaceCreate None
  and contactgroup = dJointGroupCreate() in
  dWorldSetGravity world 0. 0. (-. gravity);
  let ground = dCreatePlane (Some space) 0. 0. 1. 0. in

  let split_array arr =
    let a = Array.map fst arr
    and b = Array.map snd arr in
    (a, b)
  in

  (* dynamics and collision objects *)
  let body, box =
    split_array(Array.init n1 (fun i ->
      split_array(Array.init n2 (fun j ->
        let _i = float i and _j = float j in

        let body = dBodyCreate world in
        dMassSetBox m 1. length length height;
        dMassAdjust m (mass *. (_j +. 1.));
        dBodySetMass body m;
        dBodySetPosition body (_i *. 2. *. length)
                              (_j *. 2. *. length) (height *. 0.5);

        let box = dCreateBox (Some space) length length height in
        dGeomSetBody box (Some body);
        (body, box)
      ))
    ))
  in

  let destroy_all() =
    dJointGroupDestroy contactgroup;
    dSpaceDestroy space;
    dWorldDestroy world;
    dCloseODE();
  in

  begin
    (* set initial viewpoint *)
    let pos = (3.2, 1.5, -4.0)
    and angles = (116.4, 245.0) in

    (* call sim_step every N milliseconds *)
    let timer_msecs = 10 in

    (* simulation params (for the drawstuff lib) *)
    let dsd =
      ( (pos, angles, timer_msecs, world),
        (sim_draw box),
        (sim_step world space ground body contactgroup),
        (fun _ -> ()),
        (destroy_all)
      )
    in
    (* run simulation *)
    dsSimulationLoop 480 360 dsd;
  end;
;;

