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

(* Test for breaking joints, by Bram Stolk *)

(* Converted from C to OCaml by Florent Monnier *)

open Ode.LowLevel
open Drawstuff

let stackcnt = 10     (* nr of weights on bridge *)
let segmcnt = 16      (* nr of segments in bridge *)
let segmdim = {x=0.9; y=4.; z=0.1; w=0.}


(* this is called by dSpaceCollide when two objects in space are *)
(* potentially colliding. *)

let rec nearCallback world contactgroup = fun o1 o2 ->
  if (dGeomIsSpace o1) || (dGeomIsSpace o2) then
  begin
    (* colliding a space with something *)
    dSpaceCollide2 o1 o2 (nearCallback world contactgroup);
    (* Note we do not want to test intersections within a space, *)
    (* only between spaces. *)
    ()
  end else
  let contact_geom_arr = dCollide o1 o2 32 in
  ArrayLabels.iter contact_geom_arr ~f:(fun contact_geom ->
    let surf_param = {surf_param_zero with
      sp_mode = [`dContactSoftERP; `dContactSoftCFM; `dContactApprox1];
      sp_mu = 100.0;
      sp_soft_erp = 0.96;
      sp_soft_cfm = 0.02;
    } in
    let contact = {
      c_surface = surf_param;
      c_geom = contact_geom;
      c_fdir1 = {x=0.; y=0.; z=0.; w=0.}
    } in
    let c = dJointCreateContact world (Some contactgroup) contact in
    dJointAttach c (dGeomGetBody contact_geom.cg_g1)
                   (dGeomGetBody contact_geom.cg_g2);
  );
;;


let inspect_joints hinges stress colors jfeedbacks =
  let forcelimit = 2000.0 in
  for i=0 to pred(segmcnt-1) do
    try
      let _ = dJointGetBody hinges.(i) (0) in
      begin
        (* This joint has not snapped already... inspect it. *)
        let l0 = dLENGTH((dJointFeedback_of_buffer jfeedbacks.(i)).f1)
        and l1 = dLENGTH((dJointFeedback_of_buffer jfeedbacks.(i)).f2)
        in
        colors.(i+0) <- 0.95 *. colors.(i+0) +. 0.05 *. l0 /. forcelimit;
        colors.(i+1) <- 0.95 *. colors.(i+1) +. 0.05 *. l1 /. forcelimit;

        if (l0 > forcelimit) || (l1 > forcelimit)
        then stress.(i) <- stress.(i) + 1
        else (* stress.(i) <- 0; *) ();

        (*
        if stress.(i) > 4 then
        *)
        if stress.(i) >= 1 then
        begin
          (* Low-pass filter the noisy feedback data. *)
          (* Only after 4 consecutive timesteps with excessive load, snap. *)
          Printf.eprintf "SNAP! (that was the sound of joint %d breaking)\n%!" i;
          dJointAttach hinges.(i) None None;
        end;
      end;
    with
      Failure _ -> ()
  done;
;;



(* simulation loop *)

let sim_step world space contactgroup hinges stress colors jfeedbacks =
  function true -> ()  (* pause *)
  | false ->
      (*
      let simstep = 0.010 in  (* 10ms simulation steps *)
      *)
      let simstep = 0.005 in  (* 5ms simulation steps *)
      let dt = dsElapsedTime() in

      let nrofsteps = truncate(ceil(dt /. simstep)) in
      for i=0 to pred nrofsteps do
        dSpaceCollide space (nearCallback world contactgroup);
        dWorldQuickStep world simstep;
        dJointGroupEmpty contactgroup;
        inspect_joints hinges stress colors jfeedbacks;
      done;
;;



let draw_geom g color =
  let pos = dGeomGetPosition g
  and rot = dGeomGetRotation g in

  let kind = geom_kind g in
  match kind with
  | Box_geom g ->
      let sides = dGeomBoxGetLengths g in
      let dims = (sides.x, sides.y, sides.z) in
      dsDrawBox pos rot dims color;
  | Cylinder_geom g ->
      let (r, l) = dGeomCylinderGetParams g in
      dsDrawCylinder pos rot l r color;
  | _ -> ()
;;

(* draw scene *)

let sim_draw seggeoms stackgeoms colors = fun () ->
  for i=0 to pred segmcnt do
    let b=0.2 in
    let v = colors.(i) in

    let v = if (v > 1.0) then 1.0 else v in
    let r, g =
      if (v < 0.5) 
      then (2. *. v), (1.0)
      else (1.0), (2. *. (1.0 -. v))
    in
    let color = (r,g,b) in
    draw_geom seggeoms.(i) color;
  done;

  let color = (0.3, 0.6, 1.0) in
  ArrayLabels.iter stackgeoms ~f:(fun stackgeom ->
                                  draw_geom stackgeom color);

  dsDrawPlane (0.,0.,0.) ~scale:3.6 (1.0, 0.0, 0.0);
;;


let split_array arr =
  let a = Array.map fst arr
  and b = Array.map snd arr in
  (a, b)
;;


(* main *)
let () =
  let m = dMassCreate() in

  (* create world *)
  dInitODE();
  let world = dWorldCreate()
  and space = dHashSpaceCreate None
  and contactgroup = dJointGroupCreate () in
  dWorldSetGravity world 0. 0. (-9.8);
  dWorldSetQuickStepNumIterations world 20;

  (* dynamics and collision objects *)

  let (segbodies, seggeoms) =
    split_array(Array.init segmcnt (fun i ->
      let segbody = dBodyCreate world in
      let x = (float i) -. ((float segmcnt) /. 2.0) in
      dBodySetPosition segbody x 0. 5.;
      dMassSetBox m 1. segmdim.x segmdim.y segmdim.z;
      dBodySetMass segbody m;
      let seggeom = dCreateBox None segmdim.x segmdim.y segmdim.z in
      dGeomSetBody seggeom (Some segbody);
      dSpaceAdd space seggeom;
      (segbody, seggeom)
    ))
  in

  let (hinges, stress) =
    split_array(Array.init (segmcnt-1) (fun i ->
      let hinge = dJointCreateHinge world None in
      dJointAttach hinge (Some segbodies.(i)) (Some segbodies.(i+1));
      dJointSetHingeAnchor hinge ((float i) +. 0.5 -. (float segmcnt) /. 2.0) 0. 5.;
      dJointSetHingeAxis hinge 0. 1. 0.;
      dJointSetHingeParam hinge DParamFMax 8000.0;
      let stress = 0 in
      (hinge, stress)
    ))
  in

  (* NOTE: *)
  (* Here we tell ODE where to put the feedback on the forces for this hinge *)
  let jfeedbacks = Array.map (fun hinge -> dJointSetFeedback hinge) hinges in

  let (stackbodies, stackgeoms) =
    split_array(Array.init stackcnt (fun i ->

      let stackbody = dBodyCreate world in
      dMassSetBox m 2.0 2. 2. 0.6;
      dBodySetMass stackbody m;

      let stackgeom = dCreateBox None 2. 2. 0.6 in
      dGeomSetBody stackgeom (Some stackbody);
      dBodySetPosition stackbody 0. 0. (float(8+2*i));
      dSpaceAdd space stackgeom;

      (stackbody, stackgeom)
    ))
  in

  let slider_0 = dJointCreateSlider world None in
  dJointAttach slider_0 (Some segbodies.(0)) None;
  dJointSetSliderAxis  slider_0 1. 0. 0.;
  dJointSetSliderParam slider_0 DParamFMax  4000.0;
  dJointSetSliderParam slider_0 DParamLoStop   0.0;
  dJointSetSliderParam slider_0 DParamHiStop   0.2;

  let slider_1 = dJointCreateSlider world None in
  dJointAttach slider_1 (Some segbodies.(segmcnt-1)) None;
  dJointSetSliderAxis  slider_1 1. 0. 0.;
  dJointSetSliderParam slider_1 DParamFMax  4000.0;
  dJointSetSliderParam slider_1 DParamLoStop   0.0;
  dJointSetSliderParam slider_1 DParamHiStop (-0.2);

  let sliders = [| slider_0; slider_1 |] in

  let groundgeom = dCreatePlane (Some space) 0. 0. 1. 0. in

  let colors = Array.make segmcnt 0.0 in

  let destroy_all() =
    dJointGroupEmpty contactgroup;
    dJointGroupDestroy contactgroup;

    (* First destroy seggeoms, then space, then the world. *)
    Array.iter dGeomDestroy seggeoms;
    Array.iter dGeomDestroy stackgeoms;
    dGeomDestroy groundgeom;

    Array.iter dJointDestroy sliders;

    (* Make sure that this function is called to free the memory buffer! *)
    Array.iter dJointFeedbackBufferDestroy jfeedbacks;

    dSpaceDestroy space;
    dWorldDestroy world;
    dCloseODE();
  in

  begin
    (* set initial viewpoint *)
    let pos = (13.4, -12.6, -7.8)
    and angles = (100.8, 318.2) in

    (* call sim_step every N milliseconds *)
    let timer_msecs = 20 in

    let dsd =
      ( (pos, angles, timer_msecs, world),
        (sim_draw seggeoms stackgeoms colors),
        (sim_step world space contactgroup hinges stress colors jfeedbacks),
        (fun _ -> ()),
        (destroy_all)
      )
    in

    (* run simulation *)
    dsSimulationLoop 480 360 dsd;
  end;
;;

