(*
As explained in the manual of ODE a typical simulation will proceed like this:

  - Create a dynamics world.
  - Create bodies in the dynamics world.
  - Set the state (position etc) of all bodies.
  - Create joints in the dynamics world.
  - Attach the joints to the bodies.
  - Set the parameters of all joints.
  - Create a collision world and collision geometry objects, as necessary.
  - Create a joint group to hold the contact joints.
  - Loop: 
      - Apply forces to the bodies as necessary.
      - Adjust the joint parameters as necessary.
      - Call collision detection.
      - Create a contact joint for every collision point,
        and put it in the contact joint group.
      - Take a simulation step.
      - Remove all joints in the contact joint group.
  - Destroy the dynamics and collision worlds.

Here is how it looks like in OCaml with the most simple possible example:
*)

open Ode.LowLevel

let () =
  dInitODE ();
  let wrl = dWorldCreate () in
  dWorldSetGravity wrl 0. 0. (-0.9);
  let space = dHashSpaceCreate None in
  let plane = dCreatePlane (Some space) 0. 0. 1. 0. in
  let cgrp = dJointGroupCreate() in

  let (lx,ly,lz) = (1.,1.,1.) in
  let b = dBodyCreate wrl in
  dBodySetPosition b 0. 0. 1.;
  let m = dMassCreate () in
  dMassSetBox m 2.4 lx ly lz;
  dMassAdjust m 1.0;
  dBodySetMass b m;
  let g = dCreateBox (Some space) lx ly lz in
  dGeomSetBody g (Some b);

  let near ga gb =
    let surf_params = { surf_param_zero with
      sp_mode = [`dContactBounce];
      sp_mu = dInfinity;
      sp_bounce = 0.7;
      sp_bounce_vel = 0.1;
    } in
    let cnt_arr = dCollide ga gb 5 in
    ArrayLabels.iter cnt_arr ~f:(fun cnt_geom ->
      let cnt = {
        c_surface = surf_params;
        c_geom = cnt_geom;
        c_fdir1 = { x=0.; y=0.; z=0.; w=0. }
      } in
      let j = dJointCreateContact wrl (Some cgrp) cnt in
      dJointAttach j (dGeomGetBody ga)
                     (dGeomGetBody gb);
    );
  in

  Sys.catch_break true;
  try while true do
    dSpaceCollide space near;
    let p = dGeomGetPosition g in
    Printf.printf " (%6.3f %6.3f %6.3f)\n%!" p.x p.y p.z;
    dWorldStep wrl 0.1;
    dJointGroupEmpty cgrp;
    Unix.sleep 1;
  done
  with Sys.Break ->
    dBodyDestroy b;
    dGeomDestroy g;
    dGeomDestroy plane;
    dSpaceDestroy space;
    dWorldDestroy wrl;
    dCloseODE ();
;;

