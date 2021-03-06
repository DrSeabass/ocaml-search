(** Anytime A* or Anytime Heuristic Search, proposed by Rong and Eric,
    implemented in our search interface
    Jordan - July 2009 *)


type 'a node = {
  data : 'a;          (* Data Payload *)
  mutable wf: float;          (* Search order w/ a weighted heuristic value *)
  f : float;          (* Total cost of a node*)
  g : float;          (* Cost of reaching a node *)
  h : float;
  depth : int;        (* Depth of node in tree.  Root @ 0 *)
  mutable pos : int;  (* Position info for dpq *)
}


let wrap f =
  (** takes a function to be applied to the data payload
      such as the goal-test or the domain heuristic and
      wraps it so that it can be applied to the entire
      node *)
  (fun n -> f n.data)


let unwrap_sol s =
  (** Unwraps a solution which is in the form of a search node and presents
      it in the format the domain expects it, which is domain data followed
      by cost *)
  match s with
      Limit.Nothing -> None
    | Limit.Incumbent (q,n) -> Some (n.data, n.g)


let ordered_p a b =
  (** Ordered predicate used for search.  Compares f', then f, then g.
      true if a is better than b.
  *)
  (a.wf < b.wf) ||
  ((a.wf = b.wf) &&
   ((a.f < b.f) ||
    ((a.f = b.f) &&
     (a.g >= b.g))))


let just_f a b =
  (** Sorts nodes solely on total cost information *)
  a.f <= b.f


let setpos n i =
  (** Sets the location of a node, used by dpq's *)
  n.pos <- i


let getpos n =
  (** Returns the position of the node in its dpq.
      Useful for swapping nodes around on the open list *)
  n.pos


let make_expand expand h =
  (** Takes the domain [expand] function and a [h]euristic calculator.
      Needs the [wt] which will be applied to the heuristic.
      Creates an expand function which returns search nodes. *)
  (fun n ->
     List.map (fun (d, g) ->
		 let hv = h d in
		   { data = d;
		     wf = neg_infinity;
		     f = g +. hv;
		     g = g;
		     h = hv;
		     depth = n.depth + 1;
		     pos = Dpq.no_position; }) (expand n.data n.g))


let update wt n =
  (** Updates the weighted f value of a node based on the new weight *)
  n.wf <- n.g +. wt *. n.h(*;
  Verb.pe Verb.debug "%f %f\n" wt n.wf*)


(********************* Searches *********************************)
let make_iface sface =
  let def_log = Limit.make_default_logger (fun n -> n.f)
    (wrap sface.Search_interface.get_sol_length) in
    Search_interface.make
      ~node_expand:(make_expand sface.Search_interface.domain_expand
		      sface.Search_interface.h)
      ~goal_p:(wrap sface.Search_interface.goal_p)
      ~halt_on:sface.Search_interface.halt_on
      ~hash:sface.Search_interface.hash
      ~equals:sface.Search_interface.equals
      sface.Search_interface.domain
      { data = sface.Search_interface.initial;
	wf = neg_infinity;
	f = neg_infinity;
	g = 0.;
	h = neg_infinity;
	depth = 0;
	pos = Dpq.no_position;}
      just_f
      (fun i ->
	 sface.Search_interface.info.Limit.log
	   (Limit.unwrap_info (fun n -> n.data) i);
	 def_log i)


let no_dups sface args =
  (** Performs a weighted A* search from the initial state to a goal,
      for domains with no duplicates. *)
  let wtlist = Array.to_list
    (Search_args.get_float_array "Anytime_astar_wtlist.no_dups" args) in
  let search_interface = make_iface sface in
    Limit.unwrap_sol5 unwrap_sol
      (Continued_wtlist.no_dups
	 search_interface
	 ordered_p
	 (List.rev wtlist)
	 update)


let dups sface args =
  (** Performs a weighted A* search from the initial state to a goal,
      for domains where duplicates are frequently encountered. *)
  let wtlist = Array.to_list
    (Search_args.get_float_array "Anytime_astar_wtlist.dups" args) in
  let search_interface = make_iface sface in
    Limit.unwrap_sol6 unwrap_sol
      (Continued_wtlist.dups
	 (* must have g=0 as base for others, and
	    f < others to prevent re-opening *)
	 search_interface
	 ordered_p
	 just_f
	 setpos
	 getpos
	 (List.rev wtlist)
	 update)


let delay_dups sface args =
  (** Performs a weighted A* search from the initial state to a goal,
      for domains where duplicates are frequently encountered. *)
  let wtlist = Array.to_list
    (Search_args.get_float_array "Anytime_astar_wtlist.delay_dups" args) in
  let search_interface = make_iface sface in
    Limit.unwrap_sol6 unwrap_sol
      (Continued_wtlist.delay_dups
	 (* must have g=0 as base for others, and
	    f<others to prevent re-opening *)
	 search_interface
	 ordered_p
	 just_f
	 setpos
	 getpos
	 wtlist
	 update)

(* EOF *)
