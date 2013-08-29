(* Test the Plane2D constraint. *)
(* Converted from C to OCaml by Florent Monnier *)

open Ode.LowLevel
open Drawstuff

let drand48() = Random.float 1.0

let n_bodies = 40
let stage_size = 8.0  (* in m *)

let time_step = 0.01
let k_spring = 10.0
let k_damp = 10.0


let first  (v,_,_) = v ;;
let second (_,v,_) = v ;;
let third  (_,_,v) = v ;;

let split_array arr =
  let a = Array.map first  arr
  and b = Array.map second arr
  and c = Array.map third  arr in
  (a, b, c)
;;

let ( += ) a b = (a := !a +. b) ;;
let ( %. ) = mod_float ;;


(* collision callback *)
let cb_near_collision dyn_world coll_contacts o1 o2 =
  let b1 = dGeomGetBody o1
  and b2 = dGeomGetBody o2 in

  match b1, b2 with
  (* exit without doing anything if the two bodies are static *)
  | None, None -> ()
  (* exit without doing anything if the two bodies are connected by a joint *)
  | Some _b1, Some _b2
    when (dAreConnected _b1 _b2) -> ()
  | _ ->

    try
      let cnt_geom_arr = dCollide o1 o2 1 in
      if cnt_geom_arr <> [| |] then
        let contact ={
          c_surface = surface_param ~mu:0.0 [];
          c_geom = cnt_geom_arr.(0);
          c_fdir1 = {x=0.; y=0.; z=0.; w=0.}
        } in
        let c = dJointCreateContact dyn_world (Some coll_contacts) contact in
        dJointAttach c b1 b2;
    with _ -> ()
;;



let track_to_pos body joint_id target_x target_y =
  let curr_x = (dBodyGetPosition body).x
  and curr_y = (dBodyGetPosition body).y in

  dJointSetPlane2DXParam joint_id DParamVel (1. *. (target_x -. curr_x));
  dJointSetPlane2DYParam joint_id DParamVel (1. *. (target_y -. curr_y));
;;


(* simulation step *)
let cb_sim_step dyn_world coll_space dyn_bodies plane2d_joints coll_contacts =
  let angle = ref 0. in
  (function pause ->
  if not(pause) then
  begin
    angle += 0.01;

    track_to_pos
        dyn_bodies.(0)
        plane2d_joints.(0)
        ((stage_size /. 2.) +. (stage_size /. 2.0) *. (cos !angle))
        ((stage_size /. 2.) +. (stage_size /. 2.0) *. (sin !angle));

    if false then begin
      let f0 = 0.001 in
      for b=0 to pred n_bodies do
        let p = float(1 + b) /. (float n_bodies)
        and q = float(2 - b) /. (float n_bodies)
        in
        dBodyAddForce dyn_bodies.(b)
                      (f0 *. cos(p *. !angle))
                      (f0 *. sin(q *. !angle))  0.;
      done;
      dBodyAddTorque dyn_bodies.(0)  0. 0. 0.1;
    end;

    let n = 10 in
    for i=0 to pred n do
      dSpaceCollide coll_space (cb_near_collision dyn_world coll_contacts);
      dWorldStep dyn_world (time_step /. float n);
      dJointGroupEmpty coll_contacts;
    done;
  end;

  if true then
    begin
      (* XXX hack Plane2D constraint error reduction here: *)
      for b=0 to pred n_bodies do
        let rot = dBodyGetAngularVel dyn_bodies.(b) in

        let quat_ptr = dBodyGetQuaternion  dyn_bodies.(b) in
        let quat = {
          q1 = quat_ptr.q1;
          q2 = 0.;
          q3 = 0.;
          q4 = quat_ptr.q4;
        } in
        let quat_len = sqrt (quat.q1 *. quat.q1 +. quat.q4 *. quat.q4) in
        let quat = {quat with
          q1 = quat.q1 /. quat_len;
          q4 = quat.q4 /. quat_len;
        } in
        dBodySetQuaternion dyn_bodies.(b) quat;
        dBodySetAngularVel dyn_bodies.(b) 0. 0. rot.z;
      done;
    end;

  if false then
    begin
      (* XXX friction *)
      for b=0 to pred n_bodies do
        let vel = dBodyGetLinearVel dyn_bodies.(b)
        and rot = dBodyGetAngularVel dyn_bodies.(b)
        and s = 1.00
        and t = 0.99 in
        dBodySetLinearVel  dyn_bodies.(b) (s *. vel.x) (s *. vel.y) (s *. vel.z);
        dBodySetAngularVel dyn_bodies.(b) (t *. rot.x) (t *. rot.y) (t *. rot.z);
      done;
    end;
  )
;;



(* drawing the scene *)
let cb_sim_draw dyn_bodies bodies_sides = fun () ->
  (* ode  drawstuff *)
  for b=0 to pred n_bodies do
    let color =
      if b = 0
      then (1.0, 0.6, 0.0)
      else (0.0, 0.5, 1.0)
    in
    dsDrawBox (dBodyGetPosition dyn_bodies.(b))
              (dBodyGetRotation dyn_bodies.(b))
              bodies_sides.(b)
              color;
  done;
  dsDrawPlane (4.3, 4.3, -0.6) ~scale:(2.1) (1.0, 0.0, 0.0);
;;



(* main *)
let () =
  Random.self_init();
  dInitODE();

  (* dynamic world *)

  let cf_mixing = 0.001 in (* = 1. /. time_step *. k_spring +. k_damp *)
  let err_reduct = 0.5 in (* = time_step *. k_spring *. cf_mixing *)

  let dyn_world = dWorldCreate() in

  dWorldSetERP dyn_world err_reduct;
  dWorldSetCFM dyn_world cf_mixing;
  dWorldSetGravity dyn_world  0.0 0.0 (-1.0);

  let coll_space = dSimpleSpaceCreate None in

  let free_env() =
    dSpaceDestroy coll_space;
    dWorldDestroy dyn_world;
  in

  (* dynamic bodies *)
  let dyn_bodies, bodies_sides, plane2d_joints =
    split_array(
      Array.init n_bodies (fun b ->
        let l = 1. +. (sqrt (float n_bodies)) in
        let bf = float b in

        let x = ((0.5 +. (bf /. l)) /. l *. stage_size)
        and y = ((0.5 +. (bf %. l)) /. l *. stage_size)
        and z = 1.0 +. 0.1 *. (drand48())
        in
      
        let _x = (5. *. (0.2 +. 0.7 *. drand48()) /. (sqrt (float n_bodies)))
        and _y = (5. *. (0.2 +. 0.7 *. drand48()) /. (sqrt (float n_bodies)))
        and _z = z
        in
        let body_sides = (_x, _y, _z) in
      
        let body = dBodyCreate dyn_world in
        dBodySetPosition body x y (z /. 2.);
        dBodySetData body b;
        dBodySetLinearVel body (3. *. (drand48() -. 0.5)) 
                               (3. *. (drand48() -. 0.5)) 0.;
      
        let m = dMassCreate() in
        dMassSetBox m 1. _x _y _z;
        dMassAdjust m (0.1 *. _x *. _y);
        dBodySetMass body m;
      
        let joint = dJointCreatePlane2D dyn_world None in
        dJointAttach joint (Some body) None;
    
        (body, body_sides, joint)))
  in

  dJointSetPlane2DXParam plane2d_joints.(0) DParamFMax 10.;
  dJointSetPlane2DYParam plane2d_joints.(0) DParamFMax 10.;


  (* collision geoms and joints *)
  let _ = dCreatePlane (Some coll_space) ( 1.) ( 0.) (0.) (0.);
  and _ = dCreatePlane (Some coll_space) (-1.) ( 0.) (0.) (-. stage_size);
  and _ = dCreatePlane (Some coll_space) ( 0.) ( 1.) (0.) (0.);
  and _ = dCreatePlane (Some coll_space) ( 0.) (-1.) (0.) (-. stage_size);
  in

  for b=0 to pred n_bodies do
    let coll_box_id =
      let (lx, ly, lz) = bodies_sides.(b) in
      dCreateBox (Some coll_space) ~lx ~ly ~lz
    in
    dGeomSetBody coll_box_id (Some dyn_bodies.(b));
  done;

  let coll_contacts = dJointGroupCreate() in

  let free_env() =
    Array.iter dBodyDestroy dyn_bodies;
    Array.iter dJointDestroy plane2d_joints;
    dJointGroupDestroy coll_contacts;
    free_env();
    dCloseODE();
  in

  begin
    (* set initial viewpoint *)
    let pos = (3.2, 1.6, -7.2)
    and angles = (134.2, 230.8) in

    (* call sim_step every N milliseconds *)
    let timer_msecs = 10 in

    (* simulation params (for the drawstuff lib) *)
    let dsd =
      ( (pos, angles, timer_msecs, dyn_world),
        (cb_sim_draw  dyn_bodies bodies_sides),
        (cb_sim_step  dyn_world coll_space dyn_bodies plane2d_joints coll_contacts),
        (fun _ -> ()),
        (free_env)
      )
    in
    dsSimulationLoop 480 360 dsd;
  end;
;;

