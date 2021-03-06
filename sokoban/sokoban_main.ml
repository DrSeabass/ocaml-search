(* Main file for the sokoban solver *)

let run_alg alg b limit =
  (** writes results to stdout. assumes that header stuff like problem
    attrs are already written.  This is the main function for the stand-alone
    solver. *)
  let do_run = alg b limit in
  let (s, e, g, p, m, d), t = Wrsys.with_time do_run in
    (match s with
	 None -> Datafile.write_pairs stdout ["found solution", "no"]
       | Some (p,f) -> Datafile.write_pairs stdout ["found solution", "yes"]);
  let cost, len = (match s with
		       None -> infinity, 0
		     | Some (p, f) ->
			 f, List.length p) in
    let trail_pairs = ["final sol cost", string_of_float cost;
		       "final sol length", string_of_int len;
		       "total raw cpu time", string_of_float t;
		       "total nodes expanded", string_of_int e;
		       "total nodes generated", string_of_int g] @
      (Limit.to_trailpairs limit) in
      Datafile.write_pairs stdout trail_pairs



let select_interface heuristic alg_name move_cost push_cost =
  match heuristic with
    | "simple_manhattan" -> Soko_interfaces.simple_manhattan
    | "true_target_overlap" -> Soko_interfaces.true_target_distance_overlap
    | "single_box_solved" -> Soko_interfaces.solve_single_box
    | "bipartied_box_solved" -> Soko_interfaces.solve_single_box_bi
    | _ -> failwith (Wrutils.str "Unrecognized heuristic %s" heuristic)


let get_alg heuristic name move push =
  let sh = Soko_interfaces.with_path6
  and ib = select_interface heuristic name move push
  and arg_count,alg_call = (Wrlist.get_entry
			      (Alg_table_dups.table @ Alg_table_dd.table)
			      "alg" name) in
    arg_count, (Alg_initializers.string_array_init alg_call sh ib)



let set_up_alg heuristic move push args =
  (** looks at command line.  returns alg_func (which is world -> node
      option * int * int) and list of string pairs for logging parameters. *)
  let n = Array.length args in
    if n < 1 then
      (Wrutils.pr "expects a board on stdin, writes to stdout.\n";
       Wrutils.pr "First arg must be an algorithm name (such as \"a_star\"),\n";
       Wrutils.pr "second arg must be either \"4-way\" or \"8-way\",\n";
       Wrutils.pr "other args depend on alg (eg, \"max_dim\").\n";
       failwith "not enough command line arguments")
    else
      let alg_name = args.(1) in
      let count, initer = get_alg heuristic alg_name move push in
	if n <> (1 + count) then
	  failwith (Wrutils.str "%s takes %d arguments after alg name" alg_name (count - 1));
	let args = Array.sub args 1 count in
	  initer args

let parse_non_alg_args () =
  let v = ref 3
  and limit = ref [Limit.Never]
  and heuristic = ref "simple_manhattan"
  and move = ref 1.
  and push = ref 1.
  and others = ref ["pad"] in
    Arg.parse
      [ "-v", Arg.Set_int v,
	"verbosity setting (between 1=nothing and 5=everything, default 3)";

	"--wall", Arg.Float
	  (fun l -> limit := (Limit.WallTime l)::!limit),
	"wall time limit (in seconds, default no limit)";

	"--time", Arg.Float (fun l -> limit := (Limit.Time l)::!limit),
	"search time limit (in seconds, default no limit)";

	"--gen", Arg.Int (fun l -> limit := (Limit.Generated l)::!limit),
	"search generation limit";

	"--exp", Arg.Int (fun l -> limit := (Limit.Expanded l)::!limit),
	"search expansion limit";

	"--heuristic", Arg.Set_string heuristic,
	"selects the heuristic to be used during the search";

	"--move", Arg.Set_float move, "Sets cost of a move, default 1.";
	"--push", Arg.Set_float push, "Sets cost of a push, default 1.";]
      (fun s -> Wrutils.push s others) "";
    !v, !limit, !heuristic, !move, !push, Array.of_list (List.rev !others)


let main () =
  (** alg from command line, board from stdin, results to stdout *)
  let v,limit,heuristic, move, push, args = parse_non_alg_args () in
  let a = set_up_alg heuristic move push args
  and b = Sokoban_instance.read stdin in
    Verb.with_level v
      (fun () ->
	 run_alg a b limit)


let _ = main ()
