(**

    @author jtd7
    @since 2011-01-28

   SACH - Algorithm from "Learning While Solving Problems in Single
   Angent Search: Preliminary Results", Davis et al.  Implemented
   here as a single problem search algorithm.
*)

type 'a node = {
  data : 'a;
  g : float;
  f : float;
  d : float;
  fhat : float;
  depth : int;
  mutable q_pos : int;
  parent : 'a node;
}

type observation =
{ di : float;
  hdiff : float;
  ddiff : float;
  length : float; }

type observation_table =
{ cb : int;
  mutable size : int;
  mutable observations : int array; }


let make_observation_table cb size =
  {cb = cb;
   size = size;
   observations = Array.create size 0; }

let make_root data hd =
  let h, d = hd data in
  let rec n = { data = data;
		g = 0.;
		f = h;
		fhat = h;
		d = d;
		depth = 0;
		q_pos = Dpq.no_position;
		parent = n; } in n

let ordered a b = a.fhat < b.fhat ||
  ((a.fhat = b.fhat) && a.f < b.f) ||
  (a.fhat = b.fhat && a.f = b.f && a.g >= b.g)

let better a b = a.g < b.g
let set_pos a i = a.q_pos <- i

let display_node n =
  Verb.pe Verb.always "%f %f %f %f %i\n%!" n.g n.f n.fhat n.d n.depth

let make_expand dom_expand hd compute_hhat =
  (fun n ->
     let depth' = n.depth + 1 in
       (List.map (fun (data, g) ->
		    let h,d = hd data in
		    let f = g +. h in
		      { data = data;
			f = f;
			fhat = Math.fmax (g +. (compute_hhat [|h; d; 1.|])) f;
			g = g;
			d = d;
			depth = depth';
			q_pos = Dpq.no_position;
			parent = n;}) (dom_expand n.data n.g)))



let unwrap_sol s =
  (** Unwraps a solution which is in the form of a search node and presents
      it in the format the domain expects it, which is domain data followed
      by cost *)
  match s with
    | Limit.Nothing -> None
    | Limit.Incumbent (q,n) -> Some (n.data, n.g)


let is_root n = n.parent == n


let make_do_samples show_example table =
  let rec do_samples start node =
    let di = start.g -. node.g in
    let ind = int_of_float di in
      if table.size <= ind
      then (table.observations <- (Wrarray.extend table.observations
				     table.size 0);
	    table.size <- table.size * 2);

      if table.observations.(ind) < table.cb
      then (table.observations.(ind) <- table.observations.(ind) + 1;
	    let hdiff =  abs_float ((node.f -. node.g) -. (start.f -. start.g))
	    and ddiff = abs_float (node.d -. start.d) in
	      ignore(show_example [|hdiff; ddiff; 1.|] di));
      if node.parent != node
      then do_samples start node.parent in
    (fun source -> do_samples source source.parent)


let search ?(cb = 1000) root expand_root goal_p info key hash eq =
  (** Creates a function for performing a single iterration of the SACH
      algorithm, ignoring the backoff to weighted A* search.  Lifted from
      the psuedo code on page 59 *)
  let openlist = Dpq.create ordered set_pos 100 root
  and closed = Htable.create hash eq 100
  and obs_table = make_observation_table cb ((int_of_float root.f) * 2) in
  let show_example, estimate, _ =
    Lms.init_nlms_momentum ~initial_weights:(Some [|1.; 0.; 0.;|]) 3 in
  let expand = expand_root estimate in
  let sample = make_do_samples show_example obs_table in
  let consider_child parent c =
    Limit.incr_gen info;
    if not (Limit.promising_p info c) then Limit.incr_prune info
    else (let state = key c in
	    try
	      (let prev = Htable.find closed state in
		 Limit.incr_dups info;
		 if better c prev
		 then (Htable.replace closed state c;
		       let pos = prev.q_pos in
			 if pos = Dpq.no_position
			 then Dpq.insert openlist c
			 else Dpq.swap openlist pos c))
	    with Not_found ->
	      Dpq.insert openlist c;
	      Htable.add closed state c) in
  let rec expand_best () =
    if (not (Dpq.empty_p openlist)) && (not (Limit.halt_p info))
    then (let next = Dpq.extract_first openlist in
	    next.q_pos <- Dpq.no_position;
	    if not (Limit.promising_p info next)
	    then (Limit.incr_prune info;
		  Htable.remove closed (key next);
		  expand_best ())
	    else if goal_p next
	    then Limit.new_incumbent info (Limit.Incumbent (0., next))
	    else (sample next;
		  let children = expand next in
		    Limit.incr_exp info;
		    List.iter (consider_child next) children;
		    Limit.curr_q info (Dpq.count openlist);
		    expand_best ())) in
    Dpq.insert openlist root;
    expand_best ()


let search_dd ?(cb = 1000) root expand_root goal_p info key hash eq =
  (** Creates a function for performing a single iterration of the SACH
      algorithm, ignoring the backoff to weighted A* search.  Lifted from
      the psuedo code on page 59 *)
  let openlist = Dpq.create ordered set_pos 100 root
  and closed = Htable.create hash eq 100
  and obs_table = make_observation_table cb ((int_of_float root.f) * 2) in
  let show_example, estimate, _ =
    Lms.init_nlms_momentum ~initial_weights:(Some [|1.; 0.; 0.;|]) 3 in
  let expand = expand_root estimate in
  let sample = make_do_samples show_example obs_table in
  let consider_child parent c =
    Limit.incr_gen info;
    if not (Limit.promising_p info c) then Limit.incr_prune info
    else (let state = key c in
	    try
	      (let prev = Htable.find closed state in
		 Limit.incr_dups info;
		 if better c prev
		 then (Htable.replace closed state c;
		       let pos = prev.q_pos in
			 if pos != Dpq.no_position
			 then Dpq.swap openlist pos c))
	    with Not_found ->
	      Dpq.insert openlist c;
	      Htable.add closed state c) in
  let rec expand_best () =
    if (not (Dpq.empty_p openlist)) && (not (Limit.halt_p info))
    then (let next = Dpq.extract_first openlist in
	    next.q_pos <- Dpq.no_position;
	    if not (Limit.promising_p info next)
	    then (Limit.incr_prune info;
		  Htable.remove closed (key next);
		  expand_best ())
	    else if goal_p next
	    then Limit.new_incumbent info (Limit.Incumbent (0., next))
	    else (sample next;
(*		  display_node next;*)
		  let children = expand next in
		    Limit.incr_exp info;
		    List.iter (consider_child next) children;
		    Limit.curr_q info (Dpq.count openlist);
		    expand_best ())) in
    Dpq.insert openlist root;
    expand_best ()


let dups sface args =
  (** Performs an A* search from the initial state to a goal,
      for domains where duplicates are frequently encountered. *)
  Search_args.is_empty "Sach.dups" args;
  let module SI = Search_interface in
  let hd = sface.SI.hd
  and key n = sface.SI.key n.data
  and goal n = sface.SI.goal_p n.data
  and hash = sface.SI.hash
  and eq = sface.SI.equals in
  let root = make_root sface.SI.initial sface.SI.hd in
  let info = (Limit.make Limit.Nothing sface.SI.halt_on better
		(Limit.make_default_logger (fun n -> n.f)
		   (fun n -> n.depth))) in
  let expand = make_expand sface.SI.domain_expand hd in
    search root expand goal info key hash eq;
    Limit.unwrap_sol6 unwrap_sol (Limit.results6 info)


let dd sface args =
  (** Performs an A* search from the initial state to a goal,
      for domains where duplicates are frequently encountered. *)
  Search_args.is_empty "Sach.dups" args;
  let module SI = Search_interface in
  let hd = sface.SI.hd
  and key n = sface.SI.key n.data
  and goal n = sface.SI.goal_p n.data
  and hash = sface.SI.hash
  and eq = sface.SI.equals in
  let root = make_root sface.SI.initial sface.SI.hd in
  let info = (Limit.make Limit.Nothing sface.SI.halt_on better
		(Limit.make_default_logger (fun n -> n.f)
		   (fun n -> n.depth))) in
  let expand = make_expand sface.SI.domain_expand hd in
    search_dd root expand goal info key hash eq;
    Limit.unwrap_sol6 unwrap_sol (Limit.results6 info)


(* EOF *)
