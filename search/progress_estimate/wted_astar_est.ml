(**

    @author jtd7
    @since 2012-03-23
*)


type fp_values = {
  d     : float;
  d_err : float;
  h     : float;
  h_err : float;
  g     : float;
  est_d : float;
  est_h : float;
  wf : float;
  f : float;
}

type int_vals = {
mutable  open_pos : int;
  depth : int;
  generated : int;
}

type 'a node = {
  data : 'a;
  ints : int_vals;
  fp : fp_values;
}

let glob_d_err = ref 0.
and glob_h_err = ref 0.

(**************** Ordering Predicates *********************)

let focal_sort a b =
  a.fp.wf <= b.fp.wf


let better_p a b = (a.fp.f) <= (b.fp.f)


(***************  Utility functions **************)

let unwrap_sol = function
  | Limit.Incumbent (q, n) -> Some (n.data, n.fp.g)
  | _ -> None


let wrap fn = (fun n -> fn n.data)

let setpos n i = n.ints.open_pos <- i
and getpos n = n.ints.open_pos

(************** Search functions **************)

let make_initial initial hd w =
  let np = Dpq.no_position in
  let h,d = hd initial in
  let fp = {d = d; d_err = 0.; h_err = 0.; g = 0.; est_d = d; est_h = h;
	    wf = w *. h; h = h; f = h;}
  and iv = {open_pos = np; depth = 0; generated = 0;} in
  let rec n = { data = initial;
		ints = iv;
		fp = fp; } in n


let epsilon = 0.0001

let make_expand i expand hd w =
  let no_pos = Dpq.no_position in
  let expand n =
    let nd = n.ints.depth + 1
    and pf = n.fp.f -. n.fp.h_err
    and pd = n.fp.d -. 1. -. n.fp.d_err in
    let fnd = float nd in
      List.map (fun (s, g) ->
      let h,d = hd s in
      let f = g +. h in
      let h_err = f -. pf (* becomes f -. nfp.f +. nfp.h_err *)
      and d_err = d -. pd (* becomes d -. n.d +. 1. +. nfp.d_err *) in
      let d_err = (if Math.finite_p d_err
		   then d_err
		   else n.fp.d_err) in
      let dstep = d_err /. fnd in
      let hstep = h_err /. fnd in
      let est_d = Math.fmax d (if dstep >= 1. then d /. epsilon
	                       else d /. (1. -. dstep)) in
      let est_h = h +. (Math.fmax 0. (hstep *. est_d)) in
	glob_d_err := !glob_d_err +. dstep;
	glob_h_err := !glob_h_err +. hstep;
	let fp = {d = d; d_err = d_err;  h_err = h_err; est_h = est_h;
		  g = g; est_d = est_d; f = f; wf = g +. w *. h; h = h;}
	and ints = { open_pos = no_pos; depth = nd;
		     generated = i.Limit.expanded} in
	  assert (est_d >= 0.);
	  { data = s; ints = ints; fp = fp;})
	(expand n.data n.fp.g) in expand


(*********** The search algorithm itself **************)
let search ?(est = (fun i n oplst child -> (fun _ -> nan,nan)))
    i key hash equals goal expand initial =
  let max_guess = 200 in
  let openlist = Dpq.create focal_sort setpos max_guess initial
  and nodes = Htable.create hash equals max_guess in
  let sample, fop, output = (Progress_est.make_output_stream
			       Progress_est.output_row) in

  let consider_child n =
    Limit.incr_gen i;
    if not (Limit.promising_p i n)
    then Limit.incr_prune i
    else (let state = key n in
	    try
	      let prev = Htable.find nodes state in
		Limit.incr_dups i;
		if n.fp.g < prev.fp.g
		then (Htable.replace nodes state n;
		      let pos = getpos prev in
			if pos != Dpq.no_position
			then Dpq.swap openlist pos n)
	    with Not_found -> (* new state *)
	      Dpq.insert openlist n;
	      Htable.add nodes state n) in

  let rec expand_best () =
    if (not (Dpq.empty_p openlist)) && (not (Limit.halt_p i))
    then (let n = Dpq.extract_first openlist in
	    (* here is where you would do the estimation I guess. *)
	    setpos n Dpq.no_position;
	    if not (Limit.promising_p i n)
	    then (Limit.incr_prune i;
		  Htable.remove nodes (key n);
		  expand_best ())
	    else if goal n
	    then (Limit.new_incumbent i (Limit.Incumbent (0.,n));
		  fop();
		  output i.Limit.expanded n.ints.depth (0.,1.))
	    else (let children = expand n in
		    sample i.Limit.expanded n.ints.depth
		      (est i n openlist children);
		    Limit.incr_exp i;
		    List.iter consider_child children;
		    Limit.curr_q i (Dpq.count openlist);
		    expand_best ()))
  in
    Progress_est.output_row 0 0 (initial.fp.d,0.);
    consider_child initial;
    expand_best ();
    i.Limit.log i;
    Limit.results6 i
