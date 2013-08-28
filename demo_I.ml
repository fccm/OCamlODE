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
  Test that the rotational physics is correct.

  An "anchor body" has a number of other randomly positioned bodies
  ("particles") attached to it by ball-and-socket joints, giving it some
  random effective inertia tensor. the effective inertia matrix is calculated,
  and then this inertia is assigned to another "test" body. a random torque is
  applied to both bodies and the difference in angular velocity and orientation
  is observed after a number of iterations.

  typical errors for each test cycle are about 1e-5 ... 1e-4.
*)

(* Converted roughly from C to OCaml by F. Monnier <fmonnier@linux-nantes.org>
 *)

open Ode.LowLevel
open Drawstuff

(* some constants *)

let num = 10      (* number of particles *)
let side = 0.1    (* visual size of the particles *)

(* emulate C variables *)

exception Null_pointer
let ( !< ) v = match !v with Some v -> v | None -> raise Null_pointer ;;
let ( !> ) v = match !v with Some _ -> true | None -> false ;;
let ( =: ) a b = (a := Some b) ;;

(* dynamics objects an globals *)

let world = ref None
let anchor_body = ref None
let particle = ref None
let test_body = ref None
let torque = Array.make 3 0.
let iteration = ref 0

(* utils *)

let () = Random.self_init() ;;
let dRandReal() = Random.float 1.0 ;;

let ( += ) a b = (a := !a +. b)
let ( -= ) a b = (a := !a -. b)
let ( /= ) a b = (a := !a /. b)


(* compute the mass parameters of a particle set.
   q = particle positions,
   pm = particle masses
*)
let computeMassParams m q pm =
  dMassSetZero (m);
  let m_mass = ref(dMass_mass m)
  and m_I = dMass_I m
  and m_c = dMass_c m
  in
  let r00 = ref m_I.r11
  and r01 = ref m_I.r12
  and r02 = ref m_I.r13
  and r03 = ref m_I.r14
  and r04 = ref m_I.r21
  and r05 = ref m_I.r22
  and r06 = ref m_I.r23
  and r07 = ref m_I.r24
  and r08 = ref m_I.r31
  and r09 = ref m_I.r32
  and r10 = ref m_I.r33
  and r11 = ref m_I.r34
  in
  let m_c0 = ref m_c.x
  and m_c1 = ref m_c.y
  and m_c2 = ref m_c.z
  and m_c3 = ref m_c.w
  in
  for i=0 to pred num do
    m_mass += pm.(i);

    m_c0 += pm.(i) *. q.(i).(0);
    m_c1 += pm.(i) *. q.(i).(1);
    m_c2 += pm.(i) *. q.(i).(2);

    r00 += pm.(i) *. (q.(i).(1) *. q.(i).(1) +. q.(i).(2) *. q.(i).(2));
    r05 += pm.(i) *. (q.(i).(0) *. q.(i).(0) +. q.(i).(2) *. q.(i).(2));
    r10 += pm.(i) *. (q.(i).(0) *. q.(i).(0) +. q.(i).(1) *. q.(i).(1));
    r01 -= pm.(i) *. (q.(i).(0) *. q.(i).(1));
    r02 -= pm.(i) *. (q.(i).(0) *. q.(i).(2));
    r06 -= pm.(i) *. (q.(i).(1) *. q.(i).(2));
  done;
  r04 := !r01;
  r08 := !r02;
  r09 := !r06;

  let m_c = {
    x = !m_c0 /. !m_mass;
    y = !m_c1 /. !m_mass;
    z = !m_c2 /. !m_mass;
    w = !m_c3;
  }
  and m_I = {
    r11 = !r00;
    r12 = !r01;
    r13 = !r02;
    r14 = !r03;
    r21 = !r04;
    r22 = !r05;
    r23 = !r06;
    r24 = !r07;
    r31 = !r08;
    r32 = !r09;
    r33 = !r10;
    r34 = !r11;
  } in
  dMass_set_I m m_I;
  dMass_set_mass m !m_mass;
  dMass_set_c m m_c;
;;


let reset_test() =
  let m = dMassCreate()
  and anchor_m = dMassCreate()
  in
  let pos1 = [| 1.; 0.; 1.; |]  (* point of reference (POR) *)
  and pos2 = [| -1.; 0.; 1. |]  (* point of reference (POR) *)
  in

  (* particles with random positions (relative to POR) and masses *)
  let pm = Array.init num (fun _ -> dRandReal() +. 0.1) in
  let q = Array.init num (fun _ ->
    [| dRandReal() -. 0.5;
       dRandReal() -. 0.5;
       dRandReal() -. 0.5; |]
  ) in

  (* adjust particle positions so centor of mass = POR *)
  computeMassParams m q pm;
  let m_c = dMass_c m in
  for i=0 to pred num do
    q.(i).(0) <- q.(i).(0) -. m_c.x;
    q.(i).(1) <- q.(i).(1) -. m_c.y;
    q.(i).(2) <- q.(i).(2) -. m_c.z;
  done;

  if !> world then dWorldDestroy !<world;
  world =: dWorldCreate();

  anchor_body =: dBodyCreate !<world;
  dBodySetPosition !<anchor_body pos1.(0) pos1.(1) pos1.(2);
  dMassSetBox anchor_m 1. side side side;
  dMassAdjust anchor_m 0.1;
  dBodySetMass !<anchor_body anchor_m;

  let _particle = Array.init num (fun i ->
    let particle = dBodyCreate !<world in
    dBodySetPosition particle (pos1.(0) +. q.(i).(0))
                              (pos1.(1) +. q.(i).(1))
                              (pos1.(2) +. q.(i).(2));
    dMassSetBox m 1. side side side;
    dMassAdjust m pm.(i);
    dBodySetMass particle m;
    (particle)
  ) in
  particle =: _particle;

  for i=0 to pred num do
    let particle_joint = dJointCreateBall !<world None in
    dJointAttach particle_joint (Some !<anchor_body) (Some _particle.(i));
    let p = dBodyGetPosition _particle.(i) in
    dJointSetBallAnchor particle_joint p.x p.y p.z;
  done;

  (* make test_body with the same mass and inertia of the anchor_body plus
     all the particles *)

  test_body =: dBodyCreate !<world;
  dBodySetPosition !<test_body pos2.(0) pos2.(1) pos2.(2);
  computeMassParams m q pm;

  dMass_set_mass m ((dMass_mass m) +.
                    (dMass_mass anchor_m));

  let mI = dMass_I m
  and amI = dMass_I anchor_m
  in
  let new_mI = {
    r11 = mI.r11 +. amI.r11;
    r12 = mI.r12 +. amI.r12;
    r13 = mI.r13 +. amI.r13;
    r14 = mI.r14 +. amI.r14;
    r21 = mI.r21 +. amI.r21;
    r22 = mI.r22 +. amI.r22;
    r23 = mI.r23 +. amI.r23;
    r24 = mI.r24 +. amI.r24;
    r31 = mI.r31 +. amI.r31;
    r32 = mI.r32 +. amI.r32;
    r33 = mI.r33 +. amI.r33;
    r34 = mI.r34 +. amI.r34;
  } in
  dMass_set_I m new_mI;

  dBodySetMass !<test_body m;

  (* rotate the test and anchor bodies by a random amount *)
  let qrot = {
    q1 = dRandReal() -. 0.5;
    q2 = dRandReal() -. 0.5;
    q3 = dRandReal() -. 0.5;
    q4 = dRandReal() -. 0.5;
  } in
  let qrot = dQNormalize4 qrot in
  dBodySetQuaternion !<anchor_body qrot;
  dBodySetQuaternion !<test_body qrot;
  let rot = dQtoR qrot in
  for i=0 to pred num do
    let v = dMultiply0_331 rot q.(i) in
    dBodySetPosition _particle.(i) (pos1.(0) +. v.x)
                                   (pos1.(1) +. v.y)
                                   (pos1.(2) +. v.z);
  done;

  (* set random torque *)
  torque.(0) <- (dRandReal() -. 0.5) *. 0.1;
  torque.(1) <- (dRandReal() -. 0.5) *. 0.1;
  torque.(2) <- (dRandReal() -. 0.5) *. 0.1;

  iteration := 0;
;;


(* simulation loop *)

let sim_step = function true -> () (* pause *) | false ->
  dBodyAddTorque !<anchor_body torque.(0) torque.(1) torque.(2);
  dBodyAddTorque !<test_body torque.(0) torque.(1) torque.(2);
  dWorldStep !<world 0.03;

  incr iteration;
  if (!iteration >= 100) then begin
    (* measure the difference between the anchor and test bodies *)
    let w1 = dBodyGetAngularVel !<anchor_body
    and w2 = dBodyGetAngularVel !<test_body
    and q1 = dBodyGetQuaternion !<anchor_body
    and q2 = dBodyGetQuaternion !<test_body
    in
    let maxdiff = dMaxDifference w1 w2 1 3 in
    Printf.printf "w-error = %.4e  (%.2f,%.2f,%.2f) and (%.2f,%.2f,%.2f)\n"
                  maxdiff  w1.x w1.y w1.z  w2.x w2.y w2.z;

    let maxdiff = dQMaxDifference q1 q2 1 4 in
    Printf.printf "q-error = %.4e\n%!" maxdiff;

    reset_test();
  end;
;;


(* draw the scene *)

let sim_draw = fun () ->
  let sides  = (side,side,side)
  and sides2 = (6.*.side, 6.*.side, 6.*.side)
  and sides3 = (3.*.side, 3.*.side, 3.*.side)
  in
  let color = (1.,1.,1.) in
  dsDrawBox (dBodyGetPosition !<anchor_body)
            (dBodyGetRotation !<anchor_body) sides3 color;
  let color = (1.,0.,0.) in
  dsDrawBox (dBodyGetPosition !<test_body)
            (dBodyGetRotation !<test_body) sides2 color;
  let color = (1.,1.,0.) in
  let _particle = !<particle in
  for i=0 to pred num do
    dsDrawBox (dBodyGetPosition _particle.(i))
              (dBodyGetRotation _particle.(i)) sides color;
  done;
  dsDrawPlane (0.0, 0.0, 0.0) ~scale:(1.0) (1.,0.,0.);
;;


(* main *)
let () =
  dInitODE();
  reset_test();

  let free_env() =
    dWorldDestroy !<world;
    dCloseODE();
  in

  begin
    (* set initial viewpoint *)
    let pos = (2.2, 4.0, -2.6)
    and angles = (112.8, 210.4) in

    (* call sim_step every N milliseconds *)
    let timer_msecs = 8 in

    (* simulation params (for the drawstuff lib) *)
    let dsd =
      ( (pos, angles, timer_msecs, !<world),
        (sim_draw),
        (sim_step),
        (fun _ -> ()),
        (free_env)
      )
    in
    (* run simulation *)
    dsSimulationLoop 480 360 dsd;
  end;
;;

(* vim: sw=2 sts=2 ts=2 et
 *)
