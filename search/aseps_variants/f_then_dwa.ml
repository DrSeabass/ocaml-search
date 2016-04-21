(** An A* epsilon variant which orders the focal list on dwA* criteria
    instead of d.
    Jordan - July 2009
*)


type 'a node = {
  f : float;
  g : float;
  fp : float;
  (* position in q if applicable, or presence on closed *)
  mutable q_pos : int;
  data : 'a;
}


let just_f a b =
  (** quality ordering predicate.  distinctions between nodes with the same
    f are made by the convenience ordering predicate. *)
  a.f <= b.f

let fp_then_f_then_g a b =
  (** convenience ordering predicate *)
  (a.fp < b.fp) ||
  ((a.fp = b.fp) && ((a.f < b.f) ||
		   ((a.f = b.f) && (a.g >= b.g))))


let get_q_pos n =
  (** returns the position of node [n] in the dpq maintained by the geq*)
  n.q_pos

let set_q_pos n pos =
  (** sets the position of node [n] to [pos] *)
  n.q_pos <- pos


let make_close_enough_p weight =
  (** builds the close enough predicate required by the geq *)
  assert (weight >= 1.);
  (fun a b ->
     (** is b good enough compared to the benchmark a? *)
     b.f <= (a.f *. weight))



let make_root initial =
  (** builds the root of the search tree *)
  { f = neg_infinity;
    g = 0.;
    fp = neg_infinity;
    q_pos = Dpq.no_position;
    data = initial; }


let unwrap n =
  (** takes the solution found by the search and returns it in a format that
      the domain expects *)
  match n with
      Limit.Incumbent (q,n) -> Some (n.data, n.g)
    | _ -> None



let wrap fn =
  (** wraps the function [fn] which is made to operate on domain objects so
      that it can be applied to search objects *)
  (fun n -> fn n.data)



let wrap_expand expand hd wt rt =
  (** takes a domain [expand] function and a cost and distance estimator [hd]
      and returns a node expand function.  [Wt] is the weight to be used on
      the focal cost function, and [rt] is the root of the search space. *)
  let _,goal_depth = hd rt in
  (fun n ->
     List.map (fun (n, g) ->
		 let h,d = hd n in
		   { f = g +. h;
		     g = g;
		     fp = g +. (wt *. d /. goal_depth) *. h;
		     q_pos = Dpq.no_position;
		     data = n; })
     (expand n.data n.g))


(****************** Searches *******************)


let no_dups sface args =
  (** A* epsilon search on domains without many duplicates.
      [sface] the domain interface
      [wt] the desired suboptimality bound
      [agg] tells us how aggressive the focal ordereing should be *)
  let wt = Search_args.get_float "F_then_dwa.no_dups" args 0
  and agg = Search_args.get_float "F_then_dwa.no_dups" args 1 in
  let search_interface = Search_interface.make
    ~node_expand:(wrap_expand sface.Search_interface.domain_expand
		    sface.Search_interface.hd agg
		    sface.Search_interface.initial)
    ~key:(wrap sface.Search_interface.key)
    ~goal_p:(wrap sface.Search_interface.goal_p)
    ~halt_on:sface.Search_interface.halt_on
    ~hash:sface.Search_interface.hash
    ~equals:sface.Search_interface.equals
    sface.Search_interface.domain
    (make_root sface.Search_interface.initial)
    just_f
    (Limit.make_default_logger (fun n -> n.f)
       (wrap sface.Search_interface.get_sol_length))
  in
  Limit.unwrap_sol5 unwrap
    (Focal_search.search
       search_interface
       just_f
       (make_close_enough_p wt)
       fp_then_f_then_g
       just_f
       set_q_pos
       get_q_pos)


let dups sface args =
  (** A* epsilon search on domains with many duplicates.
      [sface] the domain interface
      [wt] the desired suboptimality bound
      [agg] tells us how aggressive the focal ordereing should be *)
  let wt = Search_args.get_float "F_then_dwa.no_dups" args 0
  and agg = Search_args.get_float "F_then_dwa.no_dups" args 1 in
  let search_interface = Search_interface.make
    ~node_expand:(wrap_expand sface.Search_interface.domain_expand
		    sface.Search_interface.hd agg
		    sface.Search_interface.initial)
    ~key:(wrap sface.Search_interface.key)
    ~goal_p:(wrap sface.Search_interface.goal_p)
    ~halt_on:sface.Search_interface.halt_on
    ~hash:sface.Search_interface.hash
    ~equals:sface.Search_interface.equals
    sface.Search_interface.domain
    (make_root sface.Search_interface.initial)
    just_f
    (Limit.make_default_logger (fun n -> n.f)
       (wrap sface.Search_interface.get_sol_length)) in
  Limit.unwrap_sol6 unwrap
    (Focal_search.search_dups
       search_interface
       just_f
       (make_close_enough_p wt)
       fp_then_f_then_g
       just_f
       set_q_pos
       get_q_pos)


(* Drop dups would not be admissible and so is not included *)

(* EOF *)
