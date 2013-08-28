#load "unix.cma"
#load "str.cma"

let () =
  let ic, oc = Unix.open_process "ode-config --version" in
  let r = input_line ic in
  let rs = r ^ ".0.0.0" in
  let pat = Str.regexp "\\([0-9]+\\)[.]\\([0-9]+\\)[.]\\([0-9]+\\).*" in
  if not(Str.string_match pat rs 0)
  then failwith "error while matching ode version"
  else begin
    let ode_major = Str.matched_group 1 rs
    and ode_minor = Str.matched_group 2 rs
    and ode_micro = Str.matched_group 3 rs
    in
    let argv = Array.to_list Sys.argv in
    if List.mem "-major" argv then print_string ode_major else
    if List.mem "-minor" argv then print_string ode_minor else
    if List.mem "-micro" argv then print_string ode_micro
  end
;;

(* vim: sw=2 sts=2 ts=2 et fdm=marker
 *)
