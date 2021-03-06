(** Perform RBFS on the indecision sum values

    @author eaburns
    @since 2010-12-02
*)

open Fn
open Lazy

type node = {
  rank : int;
  g : float;				(* and f' *)
  mutable big_f : float;
}


let is_better a b =
  if a.big_f = b.big_f then
    a.rank < b.rank
  else
    a.big_f < b.big_f


let norm_ind vl best =
  assert (if best < 0. then vl < 0. else vl >= 0.);
  let fact = (if best < 0. then
		abs_float (best /. vl)
	      else
		abs_float (vl /. best))
  in fact -. 1.


(** [expand norm wt_d info kid_costs depth node] creates a priority
    queue of the children of the given node based on their big_f
    values. *)
let expand norm wt_d info kid_costs depth ~node ~state =
  let g = node.g and big_f_n = node.big_f in
  let values = kid_costs state in
  let best = match values with | hd :: _ -> hd | [] -> nan in
  let q = Dpq.create_with is_better node in
  let wt = wt_d depth in
  let make_kid i vl =
    let ind = wt *. (if norm then norm_ind vl best else vl -. best) in
      assert (vl >= best);
(*
      begin try
	assert (ind >= 0.)
      with _ ->
	Printf.printf "vl=%g, best=%g, (abs_float (vl /. best))=%g\n"
	  vl best (abs_float (vl /. best));
	failwith (Printf.sprintf "ind=%g\n" ind);
      end;
*)
      assert (i > 0 || ind = 0.);
      let f = g +. ind in
      let big_f = if g < big_f_n then Math.fmax big_f_n f else f in
	Dpq.insert q { rank = i; g = f; big_f = big_f; }
  in
    Wrlist.iteri make_kid values;
    q


(** Performs the RBFS search. *)
let rec do_rbfs norm wt_d opt info kid_costs depth ~node ~state b' =
  if Info.leaf_p info state then begin
    if Info.optimal_p info state then opt := true;
    infinity
  end else
    if (Info.prune_p info state) || (Info.num_children info state) = 0 then
      infinity
    else begin
      Info.incr_branches info;
      handle_kids norm wt_d opt info kid_costs depth ~state b'
	(expand norm wt_d info kid_costs depth ~node ~state)
    end


(** Deals with each child generated by expansion in RBFS. *)
and handle_kids norm wt_d opt info kid_costs depth ~state b' kids =
  let rec loop n1 =
    if Math.finite_p n1.big_f && n1.big_f <= b' && not !opt
      && not (Info.halt_p info)
    then begin
      let fn2 =
	if (Dpq.count kids) = 1 then infinity else (Dpq.peek_second kids).big_f
      in
      let n1_state = Info.get_child info state n1.rank in
	n1.big_f <- (do_rbfs norm wt_d opt info kid_costs
		       (depth + 1) ~node:n1 ~state:n1_state
		       (Math.fmin b' fn2));
	Dpq.see_update kids 0;
	loop (Dpq.peek_first kids)
    end else
      n1.big_f
  in
    loop (Dpq.peek_first kids)


(** [rbfs ?norm ?halt ?log ?prev_best ?is_opt ?prune copy is_better
    is_leaf nkids kid_costs nth_kid root] use recursive-best-first
    search on indecision sum.

    @param indecision_wt is a function of depth that returns the
    weight of the indecision values at the current depth. *)
let rbfs ?(norm=false) ?(halt=[Info.Never]) ?(log=no_op2) ?(prev_best=None)
    ?(is_opt=constantly1 false) ?(prune=constantly2 false)
    ?(indecision_wt=constantly1 1.)
    copy is_better is_leaf nkids kid_costs nth_kid root =
  let info =
    Info.make nkids nth_kid is_leaf is_better is_opt copy prune
      log prev_best halt
  in
  let init_node = { rank = 0; g = 0.; big_f = 0.; } in
  let opt = ref false in
    ignore (do_rbfs norm indecision_wt opt info kid_costs 0
	      ~node:init_node ~state:root infinity);
    let complete = !opt || not (Info.halt_p info) in
      (Info.curr_best info), (Info.stats info), !opt, complete
