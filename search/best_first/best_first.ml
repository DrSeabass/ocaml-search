(** Best first searches *)

let no_record = (fun _ _ -> ())
and closed_pos = -2

let init_lists pred sface setpos =
  let key = sface.Search_interface.key
  and initial = sface.Search_interface.initial in
  let openlist = Dpq.create pred setpos 100 initial
  and nodes = Htable.create sface.Search_interface.hash
    sface.Search_interface.equals 100 in
    Dpq.insert openlist initial;
    Htable.add nodes (key initial) initial;
    openlist, nodes


let search ?(record = no_record) sface ordered_p better_p =
  (** Needs some commenting *)
  let q = Dpq.create_with ordered_p sface.Search_interface.initial
  and i = sface.Search_interface.info in
    Dpq.insert q sface.Search_interface.initial;
    let rec expand_best () =
      if (not (Dpq.empty_p q)) && (not (Limit.halt_p i))
      then
	(record i q;
	 let n = Dpq.extract_first q in
	   if not (Limit.promising_p i n) then
	     (Limit.incr_prune i;
	      expand_best ())
	   else if sface.Search_interface.goal_p n then
	     Limit.new_incumbent i (Limit.Incumbent (0.,n))
	   else
	     (Limit.incr_exp i;
	      List.iter (fun n ->
			   Limit.incr_gen i;
			   if Limit.promising_p i n then
			     Dpq.insert q n
			   else
			     Limit.incr_prune i)
		(sface.Search_interface.node_expand n);
	      Limit.curr_q i (Dpq.count q);
	      expand_best ())) in
      expand_best ();
      Limit.results5 i


let memory_limited_search
    ?(record = no_record)
    sface ordered_p better_p node_storage_limit =
  (** Needs some commenting *)
  let q = Dpq.create_with ordered_p sface.Search_interface.initial
  and i = sface.Search_interface.info in
    Dpq.insert q sface.Search_interface.initial;
    let rec expand_best () =
      if (not (Dpq.empty_p q)) && (not (Limit.halt_p i))
	&& ((Dpq.count q) <= node_storage_limit)
      then
	(record i q;
	 let n = Dpq.extract_first q in
	   if not (Limit.promising_p i n) then
	     (Limit.incr_prune i;
	      expand_best ())
	   else if sface.Search_interface.goal_p n then
	     Limit.new_incumbent i (Limit.Incumbent (0.,n))
	   else
	     (Limit.incr_exp i;
	      List.iter (fun n ->
			   Limit.incr_gen i;
			   if Limit.promising_p i n then
			     Dpq.insert q n
			   else
			     Limit.incr_prune i)
		(sface.Search_interface.node_expand n);
	      Limit.curr_q i (Dpq.count q);
	      expand_best ())) in
      expand_best ();
      Limit.results5 i



let search_dups ?(record = no_record) sface ordered_p better_p setpos getpos =
  (** [ordered_p] is true if in order or equal, [better_p] is true if
      superior or equal (eg, for comparing duplicates), [key] gives
      state data for detecting duplicates, [setpos] and [getpos] are
      for efficient swapping into the openlist.  This function is
      intended to be a building block for others - it expects an
      [expand] that takes the openlist as the first argument (in case
      [expand] wants to mess with it). *)
  (* openlist reflects ordering.  nodes has all nodes.  pos is [closedpos]
     for nodes on the closed list. *)
  let openlist, nodes = init_lists ordered_p sface setpos
  and i = sface.Search_interface.info in
  let consider_child n =
    Limit.incr_gen i;
    if not (Limit.promising_p i n) then
      Limit.incr_prune i
    else
      let state = sface.Search_interface.key n in
	(* if heuristic is consistent (monotone) then
	   first instance of node is always best path. *)
	try
	  let prev = Htable.find nodes state in
	    Limit.incr_dups i;
	    if not (better_p prev n) then
	      (* better path to previous state *)
	      (Htable.replace nodes state n;
	       let pos = getpos prev in
		 if pos == closed_pos
		 then Dpq.insert openlist n
		 else Dpq.swap openlist pos n)
	with Not_found -> (* new state *)
	  Dpq.insert openlist n;
	  Htable.add nodes state n in

  let rec expand_best () =
    if (not (Dpq.empty_p openlist)) && (not (Limit.halt_p i))
    then
      (record i openlist;
       let n = Dpq.extract_first openlist in
	 setpos n closed_pos;
	 if not (Limit.promising_p i n) then
	   (Limit.incr_prune i;
	    Htable.remove nodes (sface.Search_interface.key n);
	    expand_best ())
	 else if sface.Search_interface.goal_p n then
	   Limit.new_incumbent i (Limit.Incumbent (0.,n))
	 else
	   (let children = sface.Search_interface.node_expand n in
	      Limit.incr_exp i;
	      List.iter consider_child children;
	      Limit.curr_q i (Dpq.count openlist);
	      expand_best ()))
  in
    expand_best ();
    (*
      if Verb.level Verb.debug then begin
      let fill, num, min, med, max = Htable.bucket_stats nodes in
      Printf.printf "hash table bucket sizes:\n";
      Printf.printf "\tfill: %d\n" fill;
      Printf.printf "\tbuckets: %d\n" num;
      Printf.printf "\tmin bucket: %d\n" min;
      Printf.printf "\tmed bucket: %d\n" med;
      Printf.printf "\tmax bucket: %d\n" max;
      end;
    *)
    i.Limit.log i;
    Limit.results6 i



let memory_limited_search_dups
    ?(record = no_record)
    sface ordered_p better_p setpos getpos node_storage_capacity =
  (** [ordered_p] is true if in order or equal, [better_p] is true if
      superior or equal (eg, for comparing duplicates), [key] gives
      state data for detecting duplicates, [setpos] and [getpos] are
      for efficient swapping into the openlist.  This function is
      intended to be a building block for others - it expects an
      [expand] that takes the openlist as the first argument (in case
      [expand] wants to mess with it). *)
  (* openlist reflects ordering.  nodes has all nodes.  pos is [closedpos]
     for nodes on the closed list. *)
  let openlist, nodes = init_lists ordered_p sface setpos
  and i = sface.Search_interface.info in
  let consider_child n =
    Limit.incr_gen i;
    if not (Limit.promising_p i n) then
      Limit.incr_prune i
    else
      let state = sface.Search_interface.key n in
	(* if heuristic is consistent (monotone) then
	   first instance of node is always best path. *)
	try
	  let prev = Htable.find nodes state in
	    Limit.incr_dups i;
	    if not (better_p prev n) then
	      (* better path to previous state *)
	      (Htable.replace nodes state n;
	       let pos = getpos prev in
		 if pos == closed_pos
		 then Dpq.insert openlist n
		 else Dpq.swap openlist pos n)
	with Not_found -> (* new state *)
	  Dpq.insert openlist n;
	  Htable.add nodes state n in

  let rec expand_best () =
    if (not (Dpq.empty_p openlist)) && (not (Limit.halt_p i))
      && ((Htable.length nodes) <= node_storage_capacity)
    then
      (record i openlist;
       let n = Dpq.extract_first openlist in
	 if not (Limit.promising_p i n) then
	   (Limit.incr_prune i;
	    Htable.remove nodes (sface.Search_interface.key n);
	    expand_best ())
	 else if sface.Search_interface.goal_p n then
	   Limit.new_incumbent i (Limit.Incumbent (0.,n))
	 else
	   (setpos n closed_pos;
	    let children = sface.Search_interface.node_expand n in
	      Limit.incr_exp i;
	      List.iter consider_child children;
	      Limit.curr_q i (Dpq.count openlist);
	      expand_best ()))
  in
    expand_best ();
(*
    if Verb.level Verb.debug then begin
      let fill, num, min, med, max = Htable.bucket_stats nodes in
	Printf.printf "hash table bucket sizes:\n";
	Printf.printf "\tfill: %d\n" fill;
	Printf.printf "\tbuckets: %d\n" num;
	Printf.printf "\tmin bucket: %d\n" min;
	Printf.printf "\tmed bucket: %d\n" med;
	Printf.printf "\tmax bucket: %d\n" max;
    end;
*)
    Limit.results6 i



let search_dups_seeded ?(record = no_record) inits sface ordered_p better_p setpos getpos =
  (** [ordered_p] is true if in order or equal, [better_p] is true if
      superior or equal (eg, for comparing duplicates), [key] gives
      state data for detecting duplicates, [setpos] and [getpos] are
      for efficient swapping into the openlist.  This function is
      intended to be a building block for others - it expects an
      [expand] that takes the openlist as the first argument (in case
      [expand] wants to mess with it). *)
  (* openlist reflects ordering.  nodes has all nodes.  pos is [closedpos]
     for nodes on the closed list. *)
  let openlist = Dpq.create ordered_p setpos 100 sface.Search_interface.initial
  and nodes = Htable.create sface.Search_interface.hash sface.Search_interface.equals 100
  and i = sface.Search_interface.info in


  let consider_child n =
    Limit.incr_gen i;
    if not (Limit.promising_p i n) then
      Limit.incr_prune i
    else
      let state = sface.Search_interface.key n in
	(* if heuristic is consistent (monotone) then
	   first instance of node is always best path. *)
	try
	  let prev = Htable.find nodes state in
	    Limit.incr_dups i;
	    if not (better_p prev n) then
	      (* better path to previous state *)
	      (Htable.replace nodes state n;
	       let pos = getpos prev in
		 if pos == closed_pos
		 then Dpq.insert openlist n
		 else Dpq.swap openlist pos n)
	with Not_found -> (* new state *)
	  Dpq.insert openlist n;
	  Htable.add nodes state n in

  let rec expand_best () =
    if (not (Dpq.empty_p openlist)) && (not (Limit.halt_p i))
    then
      (record i openlist;
       let n = Dpq.extract_first openlist in
	 if not (Limit.promising_p i n) then
	   (Limit.incr_prune i;
	    Htable.remove nodes (sface.Search_interface.key n);
	    expand_best ())
	 else if sface.Search_interface.goal_p n then
	   Limit.new_incumbent i (Limit.Incumbent (0.,n))
	 else
	   (setpos n closed_pos;
	    let children = sface.Search_interface.node_expand n in
	      Limit.incr_exp i;
	      List.iter consider_child children;
	      Limit.curr_q i (Dpq.count openlist);
	      expand_best ()))
  in
    List.iter (fun e -> Dpq.insert openlist e;
		 Htable.replace nodes (sface.Search_interface.key e) e) inits;
    expand_best ();
    Limit.results6 i


let search_drop_dups ?(record = no_record) sface ordered_p better_p
    setpos getpos =
  (** [pred] is true if in order or equal (both for expansion and for
      testing which duplicate is superior), [key] gives state data for
      detecting duplicates, [setpos] and [getpos] are for efficient swapping
      into the openlist.  *)
  (* openlist reflects ordering.  nodes has all nodes.  pos is [closedpos]
     for nodes on the closed list. *)
  let openlist, nodes = init_lists ordered_p sface setpos
  and i = sface.Search_interface.info in
  let consider_child n =
    Limit.incr_gen i;
    if not (Limit.promising_p i n) then
      Limit.incr_prune i
    else
      let state = sface.Search_interface.key n in
	(* if heuristic is consistent (monotone) then
	   first instance of node is always best path. *)
	try
	  let prev = Htable.find nodes state in
	    Limit.incr_dups i;
	    if not (better_p prev n) then
	      (* better path to previous state *)
	      (let pos = getpos prev in
		 if not (pos == Dpq.no_position) then
		   (Dpq.swap openlist pos n;
		    Htable.replace nodes state n))
	with Not_found ->
	  (* new state *)
	  Dpq.insert openlist n;
	  Htable.add nodes state n in
  let rec expand_best () =
    if (not (Dpq.empty_p openlist)) && (not (Limit.halt_p i)) then
      (record i openlist;
       let n = Dpq.extract_first openlist in
	 if not (Limit.promising_p i n) then
	   (Limit.incr_prune i;
	    (* any future duplicate will be pruned by bound *)
	    Htable.remove nodes (sface.Search_interface.key n);
	    expand_best ())
	 else if sface.Search_interface.goal_p n then
	   Limit.new_incumbent i (Limit.Incumbent (0., n))
	 else
	   (setpos n Dpq.no_position;
	    Limit.incr_exp i;
	    List.iter consider_child (sface.Search_interface.node_expand n);
	    Limit.curr_q i (Dpq.count openlist);
	    expand_best ()))
  in
    expand_best ();
    Limit.results6 i


let memory_limited_search_drop_dups
    ?(record = no_record) sface ordered_p better_p
    setpos getpos node_storage_capacity=
  (** [pred] is true if in order or equal (both for expansion and for
      testing which duplicate is superior), [key] gives state data for
      detecting duplicates, [setpos] and [getpos] are for efficient swapping
      into the openlist.  *)
  (* openlist reflects ordering.  nodes has all nodes.  pos is [closedpos]
     for nodes on the closed list. *)
  let openlist, nodes = init_lists ordered_p sface setpos
  and i = sface.Search_interface.info in
  let consider_child n =
    Limit.incr_gen i;
    if not (Limit.promising_p i n) then
      Limit.incr_prune i
    else
      let state = sface.Search_interface.key n in
	(* if heuristic is consistent (monotone) then
	   first instance of node is always best path. *)
	try
	  let prev = Htable.find nodes state in
	    Limit.incr_dups i;
	    if not (better_p prev n) then
	      (* better path to previous state *)
	      (let pos = getpos prev in
		 if not (pos == Dpq.no_position) then
		   (Dpq.swap openlist pos n;
		    Htable.replace nodes state n))
	with Not_found ->
	  (* new state *)
	  Dpq.insert openlist n;
	  Htable.add nodes state n in
  let rec expand_best () =
    if (not (Dpq.empty_p openlist)) && (not (Limit.halt_p i))
      && ((Htable.length nodes) <= node_storage_capacity) then
      (record i openlist;
       let n = Dpq.extract_first openlist in
	 if not (Limit.promising_p i n) then
	   (Limit.incr_prune i;
	    (* any future duplicate will be pruned by bound *)
	    Htable.remove nodes (sface.Search_interface.key n);
	    expand_best ())
	 else if sface.Search_interface.goal_p n then
	   Limit.new_incumbent i (Limit.Incumbent (0., n))
	 else
	   (setpos n Dpq.no_position;
	    Limit.incr_exp i;
	    List.iter consider_child (sface.Search_interface.node_expand n);
	    Limit.curr_q i (Dpq.count openlist);
	    expand_best ()))
  in
    expand_best ();
    Limit.results6 i



(* EOF *)
