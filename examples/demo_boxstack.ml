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

(* WIP OCaml version by Florent Monnier *)

open Ode.LowLevel
open Drawstuff


(*<---- Convex Object *)
let planes = [|
    (* planes for a cube, these should coincide with the face array *)
     1.0;  0.0;  0.0; 0.25;
     0.0;  1.0;  0.0; 0.25;
     0.0;  0.0;  1.0; 0.25;
    -1.0;  0.0;  0.0; 0.25;
     0.0; -1.0;  0.0; 0.25;
     0.0;  0.0; -1.0; 0.25;
  |]

let points = [|
    (* points for a cube *)
     0.25; 0.25; 0.25; (* point 0 *)
    -0.25; 0.25; 0.25; (* point 1 *)

     0.25;-0.25; 0.25; (* point 2 *)
    -0.25;-0.25; 0.25; (* point 3 *)

     0.25; 0.25;-0.25; (* point 4 *)
    -0.25; 0.25;-0.25; (* point 5 *)

     0.25;-0.25;-0.25; (* point 6 *)
    -0.25;-0.25;-0.25; (* point 7 *)
  |]

let polygons = [|
    (* Polygons for a cube (6 squares) *)
    4;0;2;6;4; (* positive X *)
    4;1;0;4;5; (* positive Y *)
    4;0;1;3;2; (* positive Z *)
    4;3;1;5;7; (* negative X *)
    4;2;3;7;6; (* negative Y *)
    4;5;4;6;7; (* negative Z *)
  |]
(*----> Convex Object *)


(* some constants *)

let _NUM = 100           (* max number of objects *)
let density = (5.0)      (* density of all objects *)
let gpb = 3              (* maximum number of geometries per body *)
let max_contacts = 8     (* maximum number of contact points per body *)
let use_geom_offset = true


(* some variables *)

type 'a my_object = {
  body : dBodyID;              (* the body *)
  geom : 'a dGeomID array;     (* geometries representing this body *)
}

let num = ref 0                (* number of objects in simulation *)
let nextobj = ref 0            (* next object to recycle if num==_NUM *)

let selected = ref(-1)         (* selected object *)
let show_aabb = ref false      (* show geom AABBs? *)
let show_contacts = ref false  (* show contact points? *)
let random_pos = ref true      (* drop objects from random position? *)
let show_body = true

(* utils *)

let () = Random.self_init()
let dRandReal() = Random.float 1.0

let opt = function Some v -> v | None -> raise Not_found

let draw_contacts = ref (fun () -> ())


(* this is called by dSpaceCollide when two objects in space are
   potentially colliding. *)

let nearCallback world contactgroup = fun o1 o2 ->

  let b1 = dGeomGetBody o1
  and b2 = dGeomGetBody o2 in
  match b1, b2 with
  (* exit without doing anything if the two bodies are connected by a joint *)
  | Some _b1, Some _b2
    when (dAreConnectedExcluding _b1 _b2 JointTypeContact) -> ()
  | _ ->

    (* up to max_contacts contacts per geom-geom *)
    let surf_param = { surf_param_zero with
      sp_mode = [`dContactBounce; `dContactSoftCFM];
      sp_mu = dInfinity;
      sp_mu2 = 0.0;
      sp_bounce = 0.1;
      sp_bounce_vel = 0.1;
      sp_soft_cfm = 0.01;
    } in
    ArrayLabels.iter (dCollide o1 o2 max_contacts) ~f:(fun contact_geom ->
      let ri = dRGetIdentity()
      and ss = (0.02, 0.02, 0.02)
      and contact = {
        c_surface = surf_param;
        c_geom = contact_geom;
        c_fdir1 = {x=0.; y=0.; z=0.; w=0.}
      } in
      let c = dJointCreateContact world (Some contactgroup) contact in
      dJointAttach c b1 b2;
      draw_contacts := (fun () ->
          let color = (1.0, 0.8, 0.2) in
          if !show_contacts then dsDrawWireBox (contact_geom.cg_pos) ri ss color;
        );
    );
;;


(* usage message *)

let usage() =
  print_endline "
    To drop another object, press:
       'b' for box,
       's' for sphere,
       'c' for capsule,
       'y' for cylinder,
       'n' for a convex object,
       'x' for a composite object.
    Press \"space\" to select an object.
    Press 'd' to disable the selected object.
    Press 'e' to enable the selected object.
    Press 'a' to toggle showing the geom AABBs.
    Press 't' to toggle showing the contact points.
    Press 'r' to toggle dropping from random position/orientation.\n";
;;


(* called when a key pressed *)

let command world space obj convex_data = fun cmd ->

  let m = dMassCreate() in
  
  match Char.lowercase_ascii cmd with
  | ' ' ->
      incr selected;
      if (!selected >= !num) then selected := 0;
      if (!selected < 0) then selected := 0;

  | 'd' when (!selected >= 0 && !selected < !num) ->
      dBodyDisable ((opt obj.(!selected)).body);

  | 'e' when (!selected >= 0 && !selected < !num) ->
      dBodyEnable ((opt obj.(!selected)).body);

  | 'a' ->
      show_aabb := not !show_aabb;

  | 't' ->
      show_contacts := not(!show_contacts);

  | 'r' ->
      random_pos := not(!random_pos);

  | 'b' | 's' | 'c' (* | 'x' *) | 'y' | 'n' ->
  begin
    let setBody = ref false in
    let i =
      if (!num < _NUM) then begin
        let i = !num in
        incr num;
        (i)
      end
      else begin
        let i = !nextobj in
        incr nextobj;
        if (!nextobj >= !num) then nextobj := 0;

        (* destroy the body and geoms for slot i *)
        dBodyDestroy (opt obj.(i)).body;
        Array.iter dGeomDestroy (opt obj.(i)).geom;
        obj.(i) <- None;
        (i)
      end
    in

    let obj_i_body = dBodyCreate world in

    let sides = {
      x = dRandReal() *. 0.5 +. 0.1;
      y = dRandReal() *. 0.5 +. 0.1;
      z = dRandReal() *. 0.5 +. 0.1;
      w = 0.;
    } in

    let rot =
      if (!random_pos) then
        begin
          dBodySetPosition obj_i_body
                           (dRandReal() *. 2. -. 1.)
                           (dRandReal() *. 2. -. 1.)
                           (dRandReal() +. 2.);
          dRFromAxisAndAngle (dRandReal() *. 2.0 -. 1.0)
                             (dRandReal() *. 2.0 -. 1.0)
                             (dRandReal() *. 2.0 -. 1.0)
                             (dRandReal() *. 10.0 -. 5.0);
        end
      else 
        begin
          let maxheight = ref 0. in
          for k=0 to pred !num do 
            let _body =
              if k = i
              then obj_i_body
              else (opt obj.(k)).body
            in
            let pos = dBodyGetPosition _body in
            if (pos.z > !maxheight) then maxheight := pos.z;
          done;
          dBodySetPosition obj_i_body 0. 0. (!maxheight +. 1.);
          dRGetIdentity()
          (* dRFromAxisAndAngle 0. 0. 1. ( (*dRandReal() *. 10.0 -. 5.0*) 0.); *)
        end
    in

    dBodySetRotation obj_i_body rot;
    dBodySetData obj_i_body i;

    (* create dynamics and collision objects *)
    let obj_i_geom =
      begin match cmd with
      | 'b' ->
          dMassSetBox m density sides.x sides.y sides.z;
          let geom0 = dCreateBox (Some space) sides.x sides.y sides.z in
          [| (Obj.magic geom0 : 'a dGeomID) |]

      | 'c' ->
          let radius = sides.x *. 0.5
          and length = sides.y in
          dMassSetCapsule m density Dir_z radius length;
          let geom0 = dCreateCapsule (Some space) sides.x sides.y in
          [| (Obj.magic geom0 : 'a dGeomID) |]

      (*<---- Convex Object     *)
      | 'n' ->
          dMassSetBox m density 0.25 0.25 0.25;
          let geom0 = dCreateConvex (Some space) convex_data in
          [| (Obj.magic geom0 : 'a dGeomID) |]

      (*----> Convex Object *)

      | 'y' ->
          dMassSetCylinder m density Dir_z sides.x sides.y;
          let geom0 = dCreateCylinder (Some space) sides.x sides.y in
          [| (Obj.magic geom0 : 'a dGeomID) |]

      | 's' ->
          let radius = sides.x *. 0.5 in
          dMassSetSphere m density radius;
          let geom0 = dCreateSphere (Some space) radius in
          [| (Obj.magic geom0 : 'a dGeomID) |]

      | 'x' when use_geom_offset ->
          [|  |]
      (* TODO
        setBody := true;
        (* start accumulating masses for the encapsulated geometries *)
        dMass m2;
        dMassSetZero (&m);

        dReal dpos[gpb][3];        (* delta-positions for encapsulated geometries *)
        dMatrix3 drot[gpb];
        
        (* set random delta positions *)
        for (j=0; j<gpb; j++) {
                  for (k=0; k<3; k++) dpos[j][k] = dRandReal()*0.3-0.15;
        }
      
        for (k=0; k<gpb; k++) {
                  if (k==0) {
                    dReal radius = dRandReal()*0.25+0.05;
                    obj[i].geom[k] = dCreateSphere (space,radius);
                    dMassSetSphere (&m2,density,radius);
                  }
                  else if (k==1) {
                    obj[i].geom[k] = dCreateBox (space,sides[0],sides[1],sides[2]);
                    dMassSetBox (&m2,density,sides[0],sides[1],sides[2]);
                  }
                  else {
                    dReal radius = dRandReal()*0.1+0.05;
                    dReal length = dRandReal()*1.0+0.1;
                    obj[i].geom[k] = dCreateCapsule (space,radius,length);
                    dMassSetCapsule (&m2,density,3,radius,length);
                  }

                  dRFromAxisAndAngle (drot[k],dRandReal()*2.0-1.0,dRandReal()*2.0-1.0,
                                          dRandReal()*2.0-1.0,dRandReal()*10.0-5.0);
                  dMassRotate (&m2,drot[k]);
                  
                  dMassTranslate (&m2,dpos[k][0],dpos[k][1],dpos[k][2]);

                  (* add to the total mass *)
                  dMassAdd (&m,&m2);
                  
          }
        for (k=0; k<gpb; k++) {
                  dGeomSetBody (obj[i].geom[k],obj[i].body);
                  dGeomSetOffsetPosition (obj[i].geom[k],
                            dpos[k][0]-m.c[0],
                            dpos[k][1]-m.c[1],
                            dpos[k][2]-m.c[2]);
                  dGeomSetOffsetRotation(obj[i].geom[k], drot[k]);
        }
        dMassTranslate (&m,-m.c[0],-m.c[1],-m.c[2]);
            dBodySetMass (obj[i].body,&m);
                  
      *)

      | 'x' ->
          [|  |]
      (* TODO
        dGeomID g2[gpb];                (* encapsulated geometries *)
        dReal dpos[gpb][3];        (* delta-positions for encapsulated geometries *)

        (* start accumulating masses for the encapsulated geometries *)
        dMass m2;
        dMassSetZero (&m);

        (* set random delta positions *)
        for (j=0; j<gpb; j++) {
          for (k=0; k<3; k++) dpos[j][k] = dRandReal()*0.3-0.15;
        }

        for k=0 to pred gpb do
          obj.(i).geom.(k) <- dCreateGeomTransform space;
          dGeomTransformSetCleanup obj.(i).geom.(k) true;
          if k = 0 then begin
            let radius = dRandReal() *. 0.25 +. 0.05 in
            g2.(k) <- dCreateSphere None radius;
            dMassSetSphere m2 density radius;
          end
          else if k = 1 then begin
            g2.(k) <- dCreateBox None sides.(0) sides.(1) sides.(2);
            dMassSetBox m2 density sides.(0) sides.(1) sides.(2);
          end
          else begin
            let radius = dRandReal() *. 0.1 +. 0.05
            and length = dRandReal() *. 1.0 +. 0.1 in
            g2.(k) <- dCreateCapsule None radius length;
            dMassSetCapsule m2 density 3. radius length;
          end;
          dGeomTransformSetGeom obj.(i).geom.(k)  g2.(k);

          (* set the transformation (adjust the mass too) *)
          dGeomSetPosition g2.(k) dpos[k][0] dpos[k][1] dpos[k][2];
          let rtx =
            dRFromAxisAndAngle (dRandReal() *. 2.0 -. 1.0)
                               (dRandReal() *. 2.0 -. 1.0)
                               (dRandReal() *. 2.0 -. 1.0)
                               (dRandReal() *. 10.0 -. 5.0)
          in
          dGeomSetRotation g2.(k) rtx;
          dMassRotate m2 rtx;

          (* Translation *after* rotation *)
          dMassTranslate m2 dpos[k][0] dpos[k][1] dpos[k][2];

          (* add to the total mass *)
          dMassAdd m m2;
        done;

        (* move all encapsulated objects so that the center of mass is (0,0,0) *)
        for k=0 to pred gpb do
          dGeomSetPosition g2.(k)
                           (dpos[k][0] -. m.c[0])
                           (dpos[k][1] -. m.c[1])
                           (dpos[k][2] -. m.c[2]);
        done;
        dMassTranslate (&m,-m.c[0],-m.c[1],-m.c[2]);
      *)

      | _ ->
          invalid_arg "bug command"  (* this point should never been reached *)
      end
    in

    if not(!setBody) then
      ArrayLabels.iter obj_i_geom ~f:(fun geom ->
        dGeomSetBody geom (Some obj_i_body);
      );

    dBodySetMass obj_i_body m;

    obj.(i) <- Some {
      body = obj_i_body;
      geom = obj_i_geom;
    };

  end
  | _ -> ()
;;


(* draw a geom *)

let rec drawGeom g pos rot show_aabb color =

  let pos = match pos with Some pos -> pos | None -> dGeomGetPosition g
  and rot = match rot with Some rot -> rot | None -> dGeomGetRotation g in

  begin match geom_kind g with
  | Box_geom g ->
      let l = dGeomBoxGetLengths g in
      let sides = (l.x, l.y, l.z) in
      dsDrawBox pos rot sides color;

  | Sphere_geom g ->
      dsDrawSphere pos rot (dGeomSphereGetRadius g) color;

  | Capsule_geom g ->
      let radius, length = dGeomCapsuleGetParams g in
      dsDrawCapsule pos rot length radius color;

  (*<---- Convex Object *)
  | Convex_geom g ->
      dsDrawConvex pos rot planes
                           points
                           polygons color;
  (*----> Convex Object *)

  | Cylinder_geom g ->
      let radius, length = dGeomCylinderGetParams g in
      dsDrawCylinder pos rot length radius color;

  | GeomTransform_geom g ->
      let g2 = None (* dGeomTransformGetGeom g *) in
      begin match g2 with
      | None -> prerr_endline "Error: Empty GeomTransform"
      | Some g2 ->
          let pos2 = dGeomGetPosition g2
          and rot2 = dGeomGetRotation g2 in
          let actual_pos = dMultiply0_331 rot pos2 in
          let actual_pos = {
            x = actual_pos.x +. pos.x;
            y = actual_pos.y +. pos.y;
            z = actual_pos.z +. pos.z;
            w = 0.;
          } in
          let actual_R = dMultiply0_333 rot rot2 in
          drawGeom g2 (Some actual_pos) (Some actual_R) false color;
      end
  | _ -> ()
  end;

  if show_body then begin
    let body = dGeomGetBody g in
    match body with
    | None -> ()
    | Some body ->
        let bodypos = dBodyGetPosition body
        and bodyr = dBodyGetRotation body in
        let bodySides = (0.1, 0.1, 0.1)
        and color = (0.,1.,0.) in
        (*
        dsDrawWireBox bodypos bodyr bodySides color;
        *)
        dsDrawAbovePoint bodypos color; ignore(bodyr,bodySides);
  end;
  if show_aabb then begin
    (* draw the bounding box for this geom *)
    let aabb = dGeomGetAABB g in
    let bbpos = {
      x = 0.5 *. (aabb.(0) +. aabb.(1));
      y = 0.5 *. (aabb.(2) +. aabb.(3));
      z = 0.5 *. (aabb.(4) +. aabb.(5));
      w = 0.;
    }
    and bbsides = (
      aabb.(1) -. aabb.(0),
      aabb.(3) -. aabb.(2),
      aabb.(5) -. aabb.(4)
    )
    and ri = dRGetIdentity()
    and color = (0.,0.8,1.) in
    dsDrawWireBox bbpos ri bbsides color;
  end;
;;


(* simulation loop *)

let sim_step world space obj contactgroup = fun pause ->

  dSpaceCollide space (nearCallback world contactgroup);
  if not(pause) then dWorldQuickStep world 0.02;

  (* remove all contact joints *)
  dJointGroupEmpty (contactgroup);
;;


(* draw the scene *)

let sim_draw obj = fun () ->

  (!draw_contacts)();

  dsDrawPlane (0.0, 0.0, 0.0) ~scale:(1.4) (1.0, 0.0, 0.0);

  ArrayLabels.iteri obj ~f:(fun i obj_i ->
    match obj_i with
    | None -> ()
    | Some obj_i ->
        ArrayLabels.iter obj_i.geom ~f:(fun obj_i_geom_j ->
          let color =
          if i = !selected then
            (0., 0.7, 1.)
          else if (dBodyIsEnabled obj_i.body) then
            (1.0, 0.9, 0.)
          else
            (0.9, 0.7, 0.)
          in
          drawGeom obj_i_geom_j None None !show_aabb color;
        );
  );
;;


(* main *)

let () =
  usage();

  (* create world *)
  dInitODE();
  let world = dWorldCreate()
  and space = dHashSpaceCreate None
  and contactgroup = dJointGroupCreate() in
  dWorldSetGravity world 0. 0. (-0.5);
  dWorldSetCFM world (1e-5);
  dWorldSetAutoDisableFlag world true;

  if true then
    dWorldSetAutoDisableAverageSamplesCount world 10;

  dWorldSetContactMaxCorrectingVel world 0.1;
  dWorldSetContactSurfaceLayer world 0.001;
  let _ = dCreatePlane (Some space) 0. 0. 1. 0. in
  let obj = Array.make _NUM None in

  let convex_data = dConvexDataBuild  planes points polygons in

  let free_env() =
    dConvexDataDestroy convex_data;
    dJointGroupDestroy contactgroup;
    dSpaceDestroy space;
    dWorldDestroy world;
    dCloseODE();
  in

  begin
    (* set initial viewpoint *)
    let pos = (2.5, 6.1, -3.6)
    and angles = (111.2, 202.2) in

    (* call sim_step every N milliseconds *)
    let timer_msecs = 10 in

    (* simulation params (for the drawstuff lib) *)
    let dsd =
      ( (pos, angles, timer_msecs, world),
        (sim_draw obj),
        (sim_step world space obj contactgroup),
        (command world space obj convex_data),
        (free_env)
      )
    in
    (* run simulation *)
    dsSimulationLoop 480 360 dsd;
  end;
;;

(* vim: sw=2 sts=2 ts=2 et
 *)
