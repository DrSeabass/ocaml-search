(** Repairing Three Queued Search Jordan - Feb 2010 *)

exception Not_in_f
exception Not_in_geq
exception Not_in_either

let no_record = (fun _ _ _ -> ())

let make_eq key =
  (fun a b ->
     (key a) = (key b))


(* Three queue search w/o duplicate delaying.  Duplicates are put back into
   the search *)
let search ?(record = no_record) wtlist sface f_order ordered_focal
    ordered_fhat close_enough better_p set_qpos get_qpos set_fhpos get_fhpos
    set_geqe get_geqe get_node update_node get_cost =
  let wts = ref wtlist in
  let openlist = (Geq.create_with ordered_fhat ordered_focal
		    (close_enough (List.hd !wts))
		    set_fhpos get_fhpos sface.Search_interface.initial)
  and fq = Dpq.create f_order set_qpos 100 sface.Search_interface.initial
  and closed = (Htable.create sface.Search_interface.hash
		  sface.Search_interface.equals 250)
  and incos = (Htable.create sface.Search_interface.hash
		 sface.Search_interface.equals 250)
  and i = sface.Search_interface.info
  and prev_it = -17 in

  let insert n state =
    Dpq.insert fq n;
    let ge = Geq.insert openlist n in
      set_geqe n ge;
      Htable.replace closed state ge in

  let add_node n =
    Limit.incr_gen i;
    if not (Limit.promising_p i n)
    then Limit.incr_prune i
    else
      (let state = sface.Search_interface.key n in
	 try
	   let entry = Htable.find closed state in
	     Limit.incr_dups i;
	     let prev = Geq.data entry in
	       if not (better_p prev n)
	       then (if (get_qpos prev) >= 0
		     then (Dpq.remove fq (get_qpos prev);
			   Geq.remove openlist (get_geqe prev);
			   insert n state)
		     else (if get_qpos prev = prev_it
			   then insert n state
			   else
			     (try (* Inconsistent node *)
				let prev_i = Htable.find incos state in
				  if not (better_p prev_i n )
				  then Htable.replace incos state n
			      with Not_found -> Htable.add incos state n)))
	 with Not_found -> insert n state) in

  let do_expand n =
    if not (Limit.promising_p i n)
    then (Limit.incr_prune i;
	  [])
    else
      (let reorder,children = sface.Search_interface.resort_expand n in
	 (if reorder then Geq.resort openlist set_geqe update_node);
	 Limit.incr_exp i;
	 children) in

  let compute_eps wt =
    match i.Limit.incumbent with
	Limit.Nothing -> wt
      | Limit.Incumbent (q,n) ->
	  if Dpq.empty_p fq
	  then wt
	  else min wt ((get_cost n) /. (get_cost (Dpq.peek_first fq))) in

  let rec do_loop wt =
    if not (Limit.halt_p i) && (List.length !wts > 0)
    then
      (record i fq openlist;
       if (not (Geq.empty_p openlist)) && (not (Dpq.empty_p fq))
       then
	 (let n = get_node wt fq openlist i in
	    Geq.remove openlist (get_geqe n);
	    Dpq.remove fq (get_qpos n);
	    set_fhpos n Dpq.no_position;
	    set_qpos n Dpq.no_position;
	    if not (Limit.promising_p i n)
	    then (Limit.incr_prune i;
		  do_loop wt)
	    else
	      (if sface.Search_interface.goal_p n
	       then (Limit.new_incumbent i (Limit.Incumbent (0.,n));
		     wts := List.tl !wts;
		     if (List.length !wts) > 0
		     then
		       (let new_wt = compute_eps (List.hd !wts) in
			  Geq.update_close_enough openlist (close_enough new_wt);
			  Htable.iter
			    (fun key ele ->
			       if get_qpos (Geq.data ele) = Dpq.no_position
			       then set_qpos (Geq.data ele) prev_it) closed;
			  Htable.iter (fun key ele -> insert ele key) incos;
			  Htable.clear incos;
			  do_loop new_wt)
		     else(Htable.iter
			    (fun key ele ->
			       if get_qpos (Geq.data ele) = Dpq.no_position
			       then set_qpos (Geq.data ele) prev_it) closed;
			  Htable.iter (fun key ele -> insert ele key) incos;
			  Htable.clear incos;
			  do_loop (compute_eps 1.)))
	       else (let children = do_expand n in
		       List.iter add_node children;
		       Limit.curr_q i (Geq.count openlist);
		       do_loop wt)))
       else (wts := List.tl !wts;
	     if (List.length !wts) > 0
	     then
	       (Geq.update_close_enough openlist (close_enough (List.hd !wts));
		Htable.iter
		  (fun key ele ->
		     if get_qpos (Geq.data ele) = Dpq.no_position
		     then set_qpos (Geq.data ele) prev_it) closed;
		Htable.iter (fun key ele -> insert ele key) incos;
		Htable.clear incos;
		do_loop (compute_eps (List.hd !wts)))
	     else do_loop (compute_eps 1.)))
  in

    Dpq.insert fq sface.Search_interface.initial;
    set_geqe sface.Search_interface.initial
      (Geq.insert openlist sface.Search_interface.initial);
    Htable.add closed (sface.Search_interface.key
			 sface.Search_interface.initial)
      (get_geqe sface.Search_interface.initial);
    do_loop (List.hd !wts);
    i


let wrap_record clean_record geq_record =
  (fun i clean geq ->
     clean_record i clean geq;
     geq_record i clean geq)


(************************** Searches **********************************)
let no_dups ?(clean_record = no_record) ?(geq_record = no_record) wtlist
    sface f_order ordered_focal ordered_fhat close_enough better_p
    set_qpos get_qpos set_fhpos get_fhpos set_geqe get_geqe get_node update
    get_cost =
  (** Performs the F hat epsilon search on domains with few / no duplicates *)
  Limit.results5
    (search ~record:(wrap_record clean_record geq_record) wtlist
       sface f_order ordered_focal ordered_fhat
       close_enough better_p set_qpos get_qpos set_fhpos get_fhpos set_geqe
       get_geqe get_node update get_cost)


and dups ?(clean_record = no_record) ?(geq_record = no_record) wtlist
    sface f_order ordered_focal ordered_fhat close_enough better_p
    set_qpos get_qpos set_fhpos get_fhpos set_geqe get_geqe get_node update
    get_cost =
  (** Performs the F hat epsilon search on domains with many duplicates *)
  Limit.results6
    (search ~record:(wrap_record clean_record geq_record) wtlist
       sface f_order ordered_focal ordered_fhat
       close_enough better_p set_qpos get_qpos set_fhpos get_fhpos set_geqe
       get_geqe get_node update get_cost )


(* EOF *)
