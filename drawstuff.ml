(* Small Drawing Library
 * Copyright (C) 2008  Florent Monnier
 * Contact:  <fmonnier@linux-nantes.org>          
 * Some part are borrowed from the ODE's Drawstuff lib.
 *
 * This program is free software: you can redistribute it and/or    
 * modify it under the terms of the GNU General Public License      
 * as published by the Free Software Foundation, either version 3   
 * of the License, or (at your option) any later version.           
 *
 * This program is distributed in the hope that it will be useful,  
 * but WITHOUT ANY WARRANTY; without even the implied warranty of   
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the    
 * GNU General Public License for more details.                     
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 *)
open GL
open Glu
open Glut
open Ode.LowLevel

let dsError msg = Printf.eprintf "Error: %s\n%!" msg; exit 1 ;;

let reshape ~width ~height =
  glMatrixMode GL_PROJECTION;
  glLoadIdentity();
  gluPerspective 45. (float width /. float height) 0.5 80.;
  glViewport 0 0 width height;
  glMatrixMode GL_MODELVIEW;
  glutPostRedisplay();
;;

type vec3d = { mutable _x:float; mutable _y:float; mutable _z:float }
let pos = { _x=0.; _y=0.; _z=0. }

let angle_y = ref 0.
let angle_x = ref 0.
let xold = ref 0
let yold = ref 0

let motion ~x ~y =
  begin
    angle_y := !angle_y +. 0.2 *. float(!yold - y);
    angle_x := !angle_x +. 0.2 *. float(!xold - x);
    glutPostRedisplay();
  end;
  xold := x;
  yold := y;
;;

let mouse ~button ~state ~x ~y =
  xold := x;
  yold := y;
;;

let sim_pause = ref false ;;

let keyboard world command exit_func sim_step = fun ~key ~x ~y ->
  begin match key with
  | '\027' | 'q' ->
      exit_func();
      (*
      raise Exit
      *)
      exit(0)
  | 'p' -> sim_pause := not(!sim_pause)
  | '.' -> sim_step false; Glut.glutPostRedisplay();
  | 'v' ->
      Printf.printf "let pos = (%.1f, %.1f, %.1f)\n" pos._x pos._y pos._z;
      Printf.printf "and angles = (%.1f, %.1f) in\n" !angle_y !angle_x;
      Printf.printf "%!";
  (*
  | 'D' ->
      dWorldExportDIF world (Sys.argv.(0) ^ ".dump") "";
  *)
  | _ -> ()
  end;
  command key;
  glutPostRedisplay();
;;

let deg_to_rad = 3.14159265358979312 /. 180. ;;
let cosd a = cos(a *. deg_to_rad) ;;
let sind a = sin(a *. deg_to_rad) ;;

let moving = Array.make 6 false ;;

let special ~key ~x ~y =
  match key with
  | GLUT_KEY_PAGE_UP -> moving.(0) <- true
  | GLUT_KEY_PAGE_DOWN -> moving.(1) <- true
  | GLUT_KEY_DOWN -> moving.(2) <- true
  | GLUT_KEY_UP -> moving.(3) <- true
  | GLUT_KEY_LEFT -> moving.(4) <- true
  | GLUT_KEY_RIGHT -> moving.(5) <- true
  | _ -> ()
;;

let special_up ~key ~x ~y =
  match key with
  | GLUT_KEY_PAGE_UP -> moving.(0) <- false
  | GLUT_KEY_PAGE_DOWN -> moving.(1) <- false
  | GLUT_KEY_DOWN -> moving.(2) <- false
  | GLUT_KEY_UP -> moving.(3) <- false
  | GLUT_KEY_LEFT -> moving.(4) <- false
  | GLUT_KEY_RIGHT -> moving.(5) <- false
  | _ -> ()
;;

let move_around() =
  if moving.(0) then (pos._z <- pos._z -. 0.06);  (* up *)
  if moving.(1) then (pos._z <- pos._z +. 0.06);  (* down *)
  if moving.(2) then begin  (* backward *)
    let x = sind !angle_x
    and y = cosd !angle_x in
    pos._x <- pos._x -. (0.08 *. x);
    pos._y <- pos._y -. (0.08 *. y);
  end;
  if moving.(3) then begin  (* forward *)
    let x = sind !angle_x
    and y = cosd !angle_x in
    pos._x <- pos._x +. (0.08 *. x);
    pos._y <- pos._y +. (0.08 *. y);
  end;
  if moving.(4) then begin  (* left *)
    let x =    (cosd !angle_x)
    and y = -. (sind !angle_x) in
    pos._x <- pos._x -. (0.04 *. x);
    pos._y <- pos._y -. (0.04 *. y);
  end;
  if moving.(5) then begin  (* right *)
    let x =    (cosd !angle_x)
    and y = -. (sind !angle_x) in
    pos._x <- pos._x +. (0.04 *. x);
    pos._y <- pos._y +. (0.04 *. y);
  end;
;;

let display draw_scene = fun () ->
  glClear ~mask:[GL_COLOR_BUFFER_BIT; GL_DEPTH_BUFFER_BIT];
  glLoadIdentity();

  glRotate ~x:1.0 ~y:0.0 ~z:0.0  ~angle:(   !angle_y);
  glRotate ~x:0.0 ~y:0.0 ~z:1.0  ~angle:(-. !angle_x);
  glRotate ~x:0.0 ~y:1.0 ~z:0.0  ~angle:(-. 180.);

  glTranslate pos._x pos._y pos._z;

  draw_scene();
  glFlush();
  glutSwapBuffers();
;;


let gl_init () =
  let light_ambient = (0.0, 0.0, 0.0, 1.0)
  and light_diffuse = (1.0, 1.0, 1.0, 1.0)
  and light_specular = (1.0, 1.0, 1.0, 1.0)
  and light_position = (1.0, 1.0, 1.0, 0.0)

  and global_ambient = (0.3, 0.3, 0.8, 1.0) in

  glPointSize ~size:2.0;
  glClearColor ~r:0.2 ~g:0.3 ~b:0.5 ~a:0.0;

  glEnable GL_DEPTH_TEST;

  glLight (GL_LIGHT 0) (Light.GL_AMBIENT light_ambient);
  glLight (GL_LIGHT 0) (Light.GL_DIFFUSE light_diffuse);
  glLight (GL_LIGHT 0) (Light.GL_SPECULAR light_specular);
  glLight (GL_LIGHT 0) (Light.GL_POSITION light_position);
  glLightModel (GL_LIGHT_MODEL_AMBIENT global_ambient);
;;


let gl_backend width height (params,draw_scene,sim_step,command,exit_func) =
  ignore(glutInit Sys.argv);
  glutInitDisplayMode[GLUT_RGBA; GLUT_DOUBLE; GLUT_DEPTH];
  glutInitWindowSize ~width ~height;
  glutInitWindowPosition 160 140;
  ignore(glutCreateWindow ~title:Sys.argv.(0));

  (* user provided initialisation function *)
  let (px,py,pz), (ax, ay), (msecs), (world) = params in
  angle_y := ax;
  angle_x := ay;
  pos._x <- px;
  pos._y <- py;
  pos._z <- pz;

  (* callback functions *)
  glutDisplayFunc ~display:(display draw_scene);
  glutReshapeFunc ~reshape;
  glutKeyboardFunc ~keyboard:(keyboard world command exit_func sim_step);
  glutMouseFunc ~mouse;
  glutMotionFunc ~motion;
  glutSpecialFunc ~special;
  glutSpecialUpFunc ~special_up;

  let rec timer ~value =
    sim_step !sim_pause;
    if not !sim_pause then
    glutPostRedisplay();
    glutTimerFunc ~msecs ~timer ~value:();
  in
  glutTimerFunc ~msecs ~timer ~value:();

  let rec move_timer ~value =
    move_around();
    glutTimerFunc ~msecs:10 ~timer:move_timer ~value:();
  in
  glutTimerFunc ~msecs:10 ~timer:move_timer ~value:();

  (* init openGL *)
  gl_init();

  (* enter the main loop *)
  glutMainLoop();
;;


let current_state = ref false ;;

let dsSimulationLoop width height dsd =
  if (!current_state) then
    dsError "dsSimulationLoop() called more than once";
  current_state := true;

  (* look for flags that apply to us *)
  let argc = Array.length Sys.argv in
  for i=1 to pred argc do
    if Sys.argv.(i) = "-pause" then sim_pause := true;
  done;

  gl_backend width height dsd;

  current_state := false;
;;


(* ======================================================= *)

let dsSetColor (r,g,b) = glColor3 r g b ;;

let setTransform pos r =
  let matrix = [|
    [| r.r11;  r.r21;  r.r31;  0.; |];
    [| r.r12;  r.r22;  r.r32;  0.; |];
    [| r.r13;  r.r23;  r.r33;  0.; |];
    [| pos.x;  pos.y;  pos.z;  1.; |]; |]
  in
  glMultMatrix matrix;
  (*
  (* data exchange is optimum with a flat array *)
  let matrix = [|
    r.r11;  r.r21;  r.r31;  0.;
    r.r12;  r.r22;  r.r32;  0.;
    r.r13;  r.r23;  r.r33;  0.;
    pos.x;  pos.y;  pos.z;  1.; |]
  in
  glMultMatrixFlat matrix;
  *)
;;

(* {{{ dsDrawBox *)

let drawBox (sx,sy,sz) (r,g,b) =
  let lx = sx *. 0.5
  and ly = sy *. 0.5
  and lz = sz *. 0.5 in

  glColor3 r g b;

  (* sides *)
  glBegin GL_TRIANGLE_STRIP;
  glNormal3 (-1.) (0.) (0.);
    glVertex3 (-.lx) (-.ly) (-.lz);
    glVertex3 (-.lx) (-.ly) (lz);
    glVertex3 (-.lx) (ly) (-.lz);
    glVertex3 (-.lx) (ly) (lz);
    glNormal3 (0.) (1.) (0.);
    glVertex3 (lx) (ly) (-.lz);
    glVertex3 (lx) (ly) (lz);
    glNormal3 (1.) (0.) (0.);
    glVertex3 (lx) (-.ly) (-.lz);
    glVertex3 (lx) (-.ly) (lz);
    glNormal3 (0.) (-1.) (0.);
    glVertex3 (-.lx) (-.ly) (-.lz);
    glVertex3 (-.lx) (-.ly) (lz);
  glEnd();

  let f = 0.8 in
  glColor3 (r *. f) (g *. f) (b *. f);

  (* top face *)
  glBegin GL_TRIANGLE_FAN;
  glNormal3 (0.) (0.) (1.);
    glVertex3 (-.lx) (-.ly) (lz);
    glVertex3 (lx) (-.ly) (lz);
    glVertex3 (lx) (ly) (lz);
    glVertex3 (-.lx) (ly) (lz);
  glEnd();

  (* bottom face *)
  glBegin GL_TRIANGLE_FAN;
  glNormal3 (0.) (0.) (-1.);
    glVertex3 (-.lx) (-.ly) (-.lz);
    glVertex3 (-.lx) (ly) (-.lz);
    glVertex3 (lx) (ly) (-.lz);
    glVertex3 (lx) (-.ly) (-.lz);
  glEnd();
;;

let drawWireBox (sx,sy,sz) (r,g,b) =
  let lx = sx *. 0.5
  and ly = sy *. 0.5
  and lz = sz *. 0.5 in

  glColor3 r g b;

  (* top face *)
  glBegin GL_LINE_LOOP;
  glNormal3 (0.) (0.) (1.);
    glVertex3 (-.lx) (-.ly) (lz);
    glVertex3 (lx) (-.ly) (lz);
    glVertex3 (lx) (ly) (lz);
    glVertex3 (-.lx) (ly) (lz);
  glEnd();

  (* bottom face *)
  glBegin GL_LINE_LOOP;
  glNormal3 (0.) (0.) (-1.);
    glVertex3 (-.lx) (-.ly) (-.lz);
    glVertex3 (-.lx) (ly) (-.lz);
    glVertex3 (lx) (ly) (-.lz);
    glVertex3 (lx) (-.ly) (-.lz);
  glEnd();

  (* bottom face *)
  glBegin GL_LINES;
  glNormal3 (0.) (0.) (-1.);
    glVertex3 (-.lx) (-.ly) (  lz);
    glVertex3 (-.lx) (-.ly) (-.lz);

    glVertex3 (lx) (ly) (  lz);
    glVertex3 (lx) (ly) (-.lz);

    glVertex3 (-.lx) (ly) (lz);
    glVertex3 (-.lx) (ly) (-.lz);

    glVertex3 (lx) (-.ly) (lz);
    glVertex3 (lx) (-.ly) (-.lz);
  glEnd();
;;


let dsDrawBox pos r sides color =
  glShadeModel GL_FLAT;
  glPushMatrix();
    setTransform pos r;
    drawBox sides color;
  glPopMatrix();
;;

let dsDrawWireBox pos r sides color =
  glShadeModel GL_FLAT;
  glPushMatrix();
    setTransform pos r;
    drawWireBox sides color;
  glPopMatrix();
;;

(* }}} *)
(* {{{ dsDraw Plane, Line, Edge, Point *)

let dsDrawPlane (x,y,z) ?(scale=1.0) (r,g,b) =
  glColor3 r g b;
  glPushMatrix();
    glTranslate x y z;
    glScale scale scale scale;
    glBegin GL_LINES;
    for i = -2 to 2 do
        glVertex3 ( 2.0) (float i) 0.0;
        glVertex3 (-2.0) (float i) 0.0;
    done;
    for j = -2 to 2 do
        glVertex3 (float j) ( 2.0) 0.0;
        glVertex3 (float j) (-2.0) 0.0;
    done;
    glEnd();
  glPopMatrix();
;;


let dsDrawLine p1 p2 (r,g,b) =
  glColor3 r g b;
  glBegin GL_LINES;
    glVertex3 p1.x p1.y p1.z;
    glVertex3 p2.x p2.y p2.z;
  glEnd();
;;

let dsDrawEdge pos rot p1 p2 (r,g,b) =
  glColor3 r g b;
  glPushMatrix();
    setTransform pos rot;
    glBegin GL_LINES;
      glVertex3 p1.x p1.y p1.z;
      glVertex3 p2.x p2.y p2.z;
    glEnd();
  glPopMatrix();
;;

let dsDrawPoint p (r,g,b) =
  glColor3 r g b;
  glBegin GL_POINTS;
    glVertex3 p.x p.y p.z;
  glEnd();
;;

let dsDrawAbovePoint p (r,g,b) =
  glColor3 r g b;
  glDisable GL_DEPTH_TEST;
  glBegin GL_POINTS;
    glVertex3 p.x p.y p.z;
  glEnd();
  glEnable GL_DEPTH_TEST;
;;

(* }}} *)
(* {{{ dsDrawCylinder *)

let pi = 3.1415926535_8979323846

(* draw a cylinder of length l and radius r, aligned along the z axis *)
let drawCylinder l rad zoffset n (r,g,b) =

  let l = l *. 0.5
  and a = (pi *. 2.0) /. (float n) in
  let sa = sin a
  and ca = cos a in

  glColor3 r g b;

  (* draw cylinder body *)
  let ny= ref 1. and nz= ref 0. in  (* normal vector = (0,ny,nz) *)
  glBegin GL_TRIANGLE_STRIP;
  for i=0 to n do
    glNormal3 !ny !nz 0.;
    glVertex3 (!ny *. rad) (!nz *. rad) (zoffset +. l);
    glVertex3 (!ny *. rad) (!nz *. rad) (zoffset -. l);

    (* rotate ny,nz *)
    let tmp = (ca *. !ny) -. (sa *. !nz) in
    nz := (sa *. !ny) +. (ca *. !nz);
    ny := tmp;
  done;
  glEnd();

  (* draw top cap *)
  glShadeModel GL_FLAT;
  let ny= ref 1. and nz= ref 0. in  (* normal vector = (0,ny,nz) *)
  glBegin GL_TRIANGLE_FAN;
  glNormal3 0. 0. 1.;
  glVertex3 0. 0. (l +. zoffset);
  for i=0 to n do
    if (i=1 || i=n/2+1) then
      glColor3 r g b;
    glNormal3 0. 0. 1.;
    glVertex3 (!ny *. rad) (!nz *. rad) (l +. zoffset);
    if (i=1 || i=n/2+1) then
      glColor3 (r *. 0.75) (g *. 0.75) (b *. 0.75);

    (* rotate ny,nz *)
    let tmp = (ca *. !ny) -. (sa *. !nz) in
    nz := (sa *. !ny) +. (ca *. !nz);
    ny := tmp;
  done;
  glEnd();

  (* draw bottom cap *)
  let ny= ref 1. and nz= ref 0. in
  (* normal vector = (0,ny,nz) *)
  glBegin GL_TRIANGLE_FAN;
  glNormal3 0. 0. (-1.);
  glVertex3 0. 0. (-. l +. zoffset);
  for i=0 to n do
    if (i=1 || i=n/2+1) then
      glColor3 (r *. 0.75) (g *. 0.75) (b *. 0.75);
    glNormal3 0. 0. (-1.);
    glVertex3 (!ny *. rad) (!nz *. rad) (-. l +. zoffset);
    if (i=1 || i=n/2+1) then
      glColor3  r g b;

    (* rotate ny,nz *)
    let tmp = (ca *. !ny) +. (sa *. !nz) in
    nz := (-. sa *. !ny) +. (ca *. !nz);
    ny := tmp;
  done;
  glEnd();
;;


let dsDrawCylinder pos r length radius color =
  if not(!current_state) then
    dsError "drawing function called outside simulation loop";

  glShadeModel GL_SMOOTH;
  glPushMatrix();
    setTransform pos r;
    let n = 16 in  (* number of sides to the cylinder (divisible by 4) *)
    drawCylinder length radius 0.0 n color;
  glPopMatrix();
;;

let dsDrawWireCylinder pos r length radius color =
  if not(!current_state) then
    dsError "drawing function called outside simulation loop";

  glPolygonMode GL_FRONT_AND_BACK GL_LINE;
  glPushMatrix();
    setTransform pos r;
    let n = 12 in  (* number of sides to the cylinder (divisible by 4) *)
    drawCylinder length radius 0.0 n color;
  glPopMatrix();
  glPolygonMode GL_FRONT_AND_BACK GL_FILL;
;;

(* }}} *)
(* {{{ dsDrawSphere *)

let dsDrawSphere pos rot radius (r,g,b) =
  glShadeModel GL_FLAT;
  glPushMatrix();
    setTransform pos rot;
    glColor3 r g b;
    glutSolidSphere ~radius ~slices:8 ~stacks:8;
  glPopMatrix();
;;

let dsDrawWireSphere pos rot radius (r,g,b) =
  glShadeModel GL_FLAT;
  glPushMatrix();
    setTransform pos rot;
    glColor3 r g b;
    glutWireSphere ~radius ~slices:8 ~stacks:8;
  glPopMatrix();
;;

(* }}} *)
(* {{{ dsDrawCapsule *)

let drawCapsule l r (_r,g,b) =
  (* number of sides to the cylinder (divisible by 4): *)
  let n = 3 * 4 in

  let l = l *. 0.5 in
  let a = pi *. 2.0 /. (float n) in
  let sa = sin a
  and ca = cos a in

  glColor3 _r g b;

  (* draw cylinder body *)
  let ny = ref 1. and nz = ref 0. in  (* normal vector = (0,ny,nz) *)
  glBegin GL_TRIANGLE_STRIP;
  for i=0 to n do
    glNormal3 !ny !nz 0.;
    glVertex3 (!ny *. r) (!nz *. r) (l);
    glNormal3 !ny !nz 0.;
    glVertex3 (!ny *. r) (!nz *. r) (-. l);
    (* rotate ny,nz *)
    let tmp = ca *. !ny -. sa *. !nz in
    nz := sa *. !ny +. ca *. !nz;
    ny := tmp;
  done;
  glEnd();

  glColor3 (_r *. 0.75) (g *. 0.75) (b *. 0.75);

  (* draw first cylinder cap *)
  let start_nx = ref 0.
  and start_ny = ref 1. in
  for j=0 to pred (n/4) do
    (* get start_n2 = rotated start_n *)
    let start_nx2 = (   ca) *. !start_nx +. sa *. !start_ny
    and start_ny2 = (-. sa) *. !start_nx +. ca *. !start_ny in
    (* get n=start_n and n2=start_n2 *)
    let nx = !start_nx and ny = ref !start_ny and nz = ref 0. in
    let nx2 = start_nx2 and ny2 = ref start_ny2 and nz2 = ref 0. in
    glBegin GL_TRIANGLE_STRIP;
    for i=0 to n do
      glNormal3 !ny2 !nz2 nx2;
      glVertex3 (!ny2 *. r) (!nz2 *. r) (l +. nx2 *. r);
      glNormal3 !ny !nz nx;
      glVertex3 (!ny *. r) (!nz *. r) (l +. nx *. r);
      (* rotate n,n2 *)
      let tmp = ca *. !ny -. sa *. !nz in
      nz := sa *. !ny +. ca *. !nz;
      ny := tmp;
      let tmp = ca *. !ny2 -. sa *. !nz2 in
      nz2 := sa *. !ny2 +. ca *. !nz2;
      ny2 := tmp;
    done;
    glEnd();
    start_nx := start_nx2;
    start_ny := start_ny2;
  done;

  (* draw second cylinder cap *)
  let start_nx = ref 0.
  and start_ny = ref 1. in
  for j=0 to pred (n/4) do
    (* get start_n2 = rotated start_n *)
    let start_nx2 = ca *. !start_nx -. sa *. !start_ny
    and start_ny2 = sa *. !start_nx +. ca *. !start_ny in
    (* get n=start_n and n2=start_n2 *)
    let nx = !start_nx and ny = ref !start_ny and nz = ref 0. in
    let nx2 = start_nx2 and ny2 = ref start_ny2 and nz2 = ref 0. in
    glBegin GL_TRIANGLE_STRIP;
    for i=0 to n do
      glNormal3 !ny !nz nx;
      glVertex3 (!ny *. r) (!nz *. r) (-. l +. nx *. r);
      glNormal3 !ny2 !nz2 nx2;
      glVertex3 (!ny2 *. r) (!nz2 *. r) (-. l +. nx2 *. r);
      (* rotate n,n2 *)
      let tmp = ca *. !ny -. sa *. !nz in
      nz := sa *. !ny +. ca *. !nz;
      ny := tmp;
      let tmp = ca *. !ny2 -. sa *. !nz2 in
      nz2 := sa *. !ny2 +. ca *. !nz2;
      ny2 := tmp;
    done;
    glEnd();
    start_nx := start_nx2;
    start_ny := start_ny2;
  done;
;;

let dsDrawCapsule pos rot len rad color =
  glShadeModel GL_FLAT;
  glPushMatrix();
    setTransform pos rot;
    drawCapsule len rad color;
  glPopMatrix();
;;

(* }}} *)
(* {{{ dsDrawTriangles *)

let dsDrawTriangles pos rot world_vertices world_indices world_normals (r,g,b) =
  glPolygonMode ~face:GL_FRONT ~mode:GL_FILL;
  glPolygonMode ~face:GL_BACK ~mode:GL_LINE;
  glShadeModel GL_FLAT;
  glShadeModel GL_SMOOTH;
  glEnable GL_LIGHTING;
  glEnable GL_LIGHT0;
  glColor3 r g b;
    glPushMatrix();
      setTransform pos rot;
      glBegin GL_TRIANGLES;
      let numi = Array.length world_indices in
      let last = pred(numi/3) in
      for i=0 to last do
        (* coordinates indices *)
        let i0 = world_indices.(i*3+0)
        and i1 = world_indices.(i*3+1)
        and i2 = world_indices.(i*3+2) in

        (* vertices coordinates *)
        let x0 = world_vertices.(i0*3)
        and x1 = world_vertices.(i1*3)
        and x2 = world_vertices.(i2*3)

        and y0 = world_vertices.(i0*3+1)
        and y1 = world_vertices.(i1*3+1)
        and y2 = world_vertices.(i2*3+1)

        and z0 = world_vertices.(i0*3+2)
        and z1 = world_vertices.(i1*3+2)
        and z2 = world_vertices.(i2*3+2)
        in

        match world_normals with
        | Some world_normals ->
            (* normals coordinates *)
            let nx0 = world_normals.(i0*3+0)
            and ny0 = world_normals.(i0*3+1)
            and nz0 = world_normals.(i0*3+2)

            and nx1 = world_normals.(i0*3+0)
            and ny1 = world_normals.(i0*3+1)
            and nz1 = world_normals.(i0*3+2)

            and nx2 = world_normals.(i0*3+0)
            and ny2 = world_normals.(i0*3+1)
            and nz2 = world_normals.(i0*3+2)
            in

            glNormal3 nx0 ny0 nz0;  glVertex3 x0 y0 z0;
            glNormal3 nx1 ny1 nz1;  glVertex3 x1 y1 z1;
            glNormal3 nx2 ny2 nz2;  glVertex3 x2 y2 z2;

        | None ->
            glVertex3 x0 y0 z0;
            glVertex3 x1 y1 z1;
            glVertex3 x2 y2 z2;

      done;
      glEnd();
    glPopMatrix();
  glDisable GL_LIGHTING;
  glDisable GL_LIGHT0;
;;


let dsDrawWireTriangles pos rot world_vertices world_indices world_normals color =
  glPolygonMode GL_FRONT_AND_BACK GL_LINE;
    dsDrawTriangles pos rot world_vertices world_indices world_normals color;
  glPolygonMode GL_FRONT_AND_BACK GL_FILL;
;;

(* }}} *)
(* {{{ dsDrawConvex *)

let drawConvex _planes _points _polygons =
  let polyindex = ref 0 in
  let _planecount = (Array.length _planes) / 4 in
  for i=0 to pred _planecount do
    let pointcount = _polygons.(!polyindex) in
      incr polyindex;
      glBegin GL_POLYGON;
       glNormal3 (_planes.((i*4)+0))
                 (_planes.((i*4)+1))
                 (_planes.((i*4)+2));

      for j=0 to pred pointcount do
        glVertex3 (_points.((_polygons.(!polyindex)*3)+0))
                  (_points.((_polygons.(!polyindex)*3)+1))
                  (_points.((_polygons.(!polyindex)*3)+2));
        incr polyindex;
      done;
      glEnd();
  done;
;;

let polyfactor = 1.0
let polyunits  = 1.0
let fill = true

let _drawConvex planes points polygons =
  if (fill) then begin
    glEnable GL_LIGHTING;
    glEnable GL_LIGHT0;
    glEnable GL_POLYGON_OFFSET_FILL;
    glPolygonOffset polyfactor polyunits;
      drawConvex planes points polygons;
    glDisable GL_POLYGON_OFFSET_FILL;
    glDisable GL_LIGHTING;
    glDisable GL_LIGHT0;
  end;

  glColor3  0.0 0.2 1.0;
  glPolygonMode GL_FRONT_AND_BACK GL_LINE;
  glPolygonOffset (-. polyfactor) (-. polyunits);
  if not(fill) then glEnable GL_POLYGON_OFFSET_LINE;
    drawConvex planes points polygons;
  glDisable GL_POLYGON_OFFSET_LINE;
  glPolygonMode GL_FRONT_AND_BACK GL_FILL;

  if not(fill) then begin 
    glEnable GL_LIGHTING;
    glEnable GL_LIGHT0;
      drawConvex planes points polygons;
    glDisable GL_LIGHTING;
    glDisable GL_LIGHT0;
  end;
;;

let dsDrawConvex pos rot planes points polygons (r,g,b) =
  if not(!current_state) then
    dsError "drawing function called outside simulation loop";

  glColor3 r g b;
  glPushMatrix();
    setTransform pos rot;
    _drawConvex planes points polygons;
  glPopMatrix();
;;

(* }}} *)
(* {{{ dsDrawWireCapsule *)

let drawWireCapsule l r (_r,g,b) =
  (* number of sides to the cylinder (divisible by 4): *)
  let n = 3 * 4 in

  let l = l *. 0.5 in
  let a = pi *. 2.0 /. (float n) in
  let sa = sin a
  and ca = cos a in

  glColor3 _r g b;

  (* draw cylinder body *)
  let ny = ref 1. and nz = ref 0. in  (* normal vector = (0,ny,nz) *)
  let li = ref [] in
  for i=0 to n do
    let a = (!ny, !nz, 0., (!ny *. r), (!nz *. r), (l))
    and b = (!ny, !nz, 0., (!ny *. r), (!nz *. r), (-. l))
    in
    li := (a,b) :: !li;
    (* rotate ny,nz *)
    let tmp = ca *. !ny -. sa *. !nz in
    nz := sa *. !ny +. ca *. !nz;
    ny := tmp;
  done;
  let along = function
    (nx1,ny1,nz1, x1,y1,z1),
    (nx2,ny2,nz2, x2,y2,z2) ->
      glNormal3 nx1 ny1 nz1;  glVertex3 x1 y1 z1;
      glNormal3 nx2 ny2 nz2;  glVertex3 x2 y2 z2;
  in
  glBegin GL_LINES;
  List.iter along !li;
  glEnd();

  let along = function
    (nx,ny,nz, x,y,z), _ ->
      glNormal3 nx ny nz;  glVertex3 x y z;
  in
  glBegin GL_LINE_LOOP;
  List.iter along !li;
  glEnd();

  let along = function
    _, (nx,ny,nz, x,y,z) ->
      glNormal3 nx ny nz;  glVertex3 x y z;
  in
  glBegin GL_LINE_LOOP;
  List.iter along !li;
  glEnd();

  (* draw first cylinder cap *)
  let start_nx = ref 0.
  and start_ny = ref 1. in
  for j=0 to pred (n/4) do
    (* get start_n2 = rotated start_n *)
    let start_nx2 = (   ca) *. !start_nx +. sa *. !start_ny
    and start_ny2 = (-. sa) *. !start_nx +. ca *. !start_ny in
    (* get n=start_n and n2=start_n2 *)
    let nx = !start_nx and ny = ref !start_ny and nz = ref 0. in
    let nx2 = start_nx2 and ny2 = ref start_ny2 and nz2 = ref 0. in
    glBegin GL_LINES;
    for i=0 to n do
      glNormal3 !ny2 !nz2 nx2;
      glVertex3 (!ny2 *. r) (!nz2 *. r) (l +. nx2 *. r);
      glNormal3 !ny !nz nx;
      glVertex3 (!ny *. r) (!nz *. r) (l +. nx *. r);
      (* rotate n,n2 *)
      let tmp = ca *. !ny -. sa *. !nz in
      nz := sa *. !ny +. ca *. !nz;
      ny := tmp;
      let tmp = ca *. !ny2 -. sa *. !nz2 in
      nz2 := sa *. !ny2 +. ca *. !nz2;
      ny2 := tmp;
    done;
    glEnd();
    start_nx := start_nx2;
    start_ny := start_ny2;
  done;

  (* draw second cylinder cap *)
  let start_nx = ref 0.
  and start_ny = ref 1. in
  for j=0 to pred (n/4) do
    (* get start_n2 = rotated start_n *)
    let start_nx2 = ca *. !start_nx -. sa *. !start_ny
    and start_ny2 = sa *. !start_nx +. ca *. !start_ny in
    (* get n=start_n and n2=start_n2 *)
    let nx = !start_nx and ny = ref !start_ny and nz = ref 0. in
    let nx2 = start_nx2 and ny2 = ref start_ny2 and nz2 = ref 0. in
    glBegin GL_LINES;
    for i=0 to n do
      glNormal3 !ny !nz nx;
      glVertex3 (!ny *. r) (!nz *. r) (-. l +. nx *. r);
      glNormal3 !ny2 !nz2 nx2;
      glVertex3 (!ny2 *. r) (!nz2 *. r) (-. l +. nx2 *. r);
      (* rotate n,n2 *)
      let tmp = ca *. !ny -. sa *. !nz in
      nz := sa *. !ny +. ca *. !nz;
      ny := tmp;
      let tmp = ca *. !ny2 -. sa *. !nz2 in
      nz2 := sa *. !ny2 +. ca *. !nz2;
      ny2 := tmp;
    done;
    glEnd();
    start_nx := start_nx2;
    start_ny := start_ny2;
  done;
;;

let dsDrawWireCapsule pos rot len rad color =
  glShadeModel GL_FLAT;
  glPushMatrix();
    setTransform pos rot;
    drawWireCapsule len rad color;
  glPopMatrix();
;;

(* }}} *)

(* ======================================================= *)

let dsElapsedTime =
  let prev_time = ref 0.0 in
  function () ->
  let curr = float (glutGet GLUT_ELAPSED_TIME) /. 1000.0 in

  if !sim_pause then (prev_time := curr; 0.01666) else
  begin
    if (!prev_time = 0.0) then prev_time := curr;

    let retval = curr -. !prev_time in
    prev_time := curr;

    let retval = if (retval>1.0) then 1.0 else retval in
    let retval = if (retval<epsilon_float) then epsilon_float else retval in

    (retval)
  end
;;


(* vim: sw=2 sts=2 ts=2 et fdm=marker
 *)
