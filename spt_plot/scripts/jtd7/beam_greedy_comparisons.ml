(**
   @author jtd7
   @since 2010-05-31
*)

let loc = ref Legend.Upper_right
let use_color = ref true
let log = ref true
let xlog = ref false
let rm_fails = ref false

let do_logs xkey ykey dset =
  let dset' = (if !log
	       then Dataset.numeric_transform ykey
		 (fun v -> if v = 0. then -5. else log10 v) dset
	       else dset) in
  if !xlog
  then (Dataset.numeric_transform xkey
	  (fun v -> if v = 0. then -5. else log10 v) dset')
  else dset'

let do_xlog xkey dset =
  Dataset.numeric_transform xkey
    (fun v -> if v = 0. then -5. else log10 v) dset

let remove_failures dsets =
  List.filter
    (fun d -> not (Dataset.ds_exists "found solution" "no" d))
    dsets


let xy_plot ~title ~xlabel ~xkey datasets ykey =
  let has_wt = List.filter (Dataset.is_key "wt") datasets
  and has_beam = List.filter (Dataset.is_key "beam_width") datasets
  and others = List.filter (fun ds ->
    not (Dataset.is_key "wt" ds ||
	   Dataset.is_key "beam_width" ds )) datasets in
  let dl = do_logs xkey ykey in
  let has_wt = List.map dl has_wt
  and has_beam = List.map dl has_beam
  and others = List.map dl others in
  let glyph_factory = (Dataset_to_spt.make_or_use_glyph_factory
			 !use_color None) in
  let dash_factory = Dataset_to_spt.make_or_use_dash_factory None in
  let fn = (Dataset_to_spt.scatter_err_lines ~use_color:!use_color
	      ~glyph_factory ~dash_factory
	      ~line_width:(Length.Pt 1.) (*~labeled:true*)
	      ~point_radius:(Length.Pt 5.) ~xkey ~ykey) in
  let wt_dset = (Verb.pe Verb.always "makin wt dset\n%!";
		 fn ~group_key:"wt" has_wt)
  and beam_dset = (Verb.pe Verb.always "makin beam dset\n%!";
		   fn ~group_key:"beam_width" has_beam)
  and alg_dset = (Verb.pe Verb.always "makin alg dset\n%!";
		  fn ~group_key:"alg" others) in
  let dset = wt_dset @ beam_dset @ alg_dset  in
    Verb.pe Verb.always "Dataset Constructed\n%!";
    let plot = (Num_by_num.plot ~legend_loc:!loc
		  ~title
		  ~xlabel:(if !log
			   then "log10 " ^ xlabel
			   else xlabel)
		  (*~ylabel:"Solution Quality" *)
		  ~ylabel:(if false (*!log*)
			   then "log10 Solution Quality"
			   else "Solution Quality")
		  dset) in
      plot#display



let table_entries ~title ~xlabel ~xkey datasets ykey =
  Printf.fprintf stderr "ds length %d\n" (List.length datasets);
  flush stderr;


  let has_wt = List.filter (Dataset.is_key "wt") datasets
  and has_beam = List.filter (Dataset.is_key "beam_width") datasets
  and others = List.filter (fun ds ->
			      not (Dataset.is_key "wt" ds ||
				     Dataset.is_key "beam_width" ds )) datasets in
  let dl = do_logs xkey ykey in
  let has_wt = if !log then List.map dl has_wt else has_wt
  and has_beam = if !log then List.map dl has_beam else has_beam
  and others = if !log then List.map dl others else others in
  let dset = has_wt @ has_beam @ others  in
    Printf.fprintf stderr "ds length %d\n" (List.length dset);
    flush stderr;
    Verb.pe Verb.always "Dataset Constructed\n%!";
    Verb.pe Verb.always "alg\t%s\t%s\n%!" xkey ykey;
    List.iter (fun ds ->
		 Verb.pe Verb.always "%s & $%f \\pm %f$ & $%f \\pm %f$ \\\\\n"
		   (Dataset.get_name ds)
		   (Dataset.get_mean xkey ds)
		   (Dataset.get_stdev xkey ds)
		   (Dataset.get_mean ykey ds)
		   (Dataset.get_stdev ykey ds)) dset



let load_agnostic ?(ykey = "final sol cost") ld title xkey alg_list =
  let dat = List.map (Jtd7_helpers.load_wrap ld) alg_list in
    Verb.pe Verb.always "Data loaded\n%!";
  let ndat = Normalize_dataset.norm_min "num" ykey dat in
    Verb.pe Verb.always "Data normalized\n%!";
    xy_plot ~title ~xlabel:xkey ~xkey ndat ykey


let load_raw ?(ykey = "final sol cost") ld title xkey alg_list =
  let dat = List.map (Jtd7_helpers.load_wrap ld) alg_list in
    Verb.pe Verb.always "Data loaded\n%!";
    xy_plot ~title ~xlabel:xkey ~xkey dat ykey


let table_raw ?(ykey = "final sol cost") ld title xkey alg_list =
  let dat = List.map (Jtd7_helpers.load_wrap ld) alg_list in
    Verb.pe Verb.always "Data loaded\n%!";
    table_entries ~title ~xlabel:xkey ~xkey dat ykey


let table_agnostic ?(ykey = "final sol cost") ld title xkey alg_list =
  let dat = List.map (Jtd7_helpers.load_wrap ld) alg_list in
    Verb.pe Verb.always "Data loaded\n%!";
  let ndat = Normalize_dataset.norm_min "num" ykey dat in
    Verb.pe Verb.always "Data normalized\n%!";
    table_entries ~title ~xlabel:xkey ~xkey ndat ykey


(************************************************************************)

let tiles ?(xkey = "total raw cpu time") alg_list =
   table_raw Load_dataset.korf_100_tiles "Korf's 100 15 Puzzles"
    xkey alg_list

let tiles_plot ?(xkey = "total raw cpu time") alg_list =
  load_agnostic Load_dataset.korf_100_tiles "Korf's 100 15 Puzzles"
    xkey alg_list

let inv_tiles ?(xkey = "total raw cpu time") alg_list =
  load_agnostic (Load_dataset.korf_100_tiles ~cost:"inverse")
    "15 Puzzles - Inverse Cost" xkey alg_list

let inv_tiles_plot ?(xkey = "total raw cpu time") alg_list =
  load_raw (Load_dataset.korf_100_tiles ~cost:"inverse")
    "Korf's 100 15 Puzzles - Inverse Cost"
    xkey alg_list

let tiles_7 ?(skip_fails=false) ?(xkey = "total raw cpu time")
    ?(heuristic="manhattan")
    alg_list =
  load_agnostic (Load_dataset.seven_tiles
		   ~heuristic:heuristic
		   ~skip_fails:skip_fails)
    "Random 7x7 tile puzzles"
    xkey alg_list


let custom_tiles ?(skip_fails=false) ?(xkey = "total raw cpu time")
    ?(heuristic="manhattan")
    ?(cost="unit")
    ?(table = false)
    model rows cols
    alg_list =
  let lf = match table with
      true -> table_raw
    | false -> load_agnostic in
    lf (Load_dataset.custom_tiles
		   ~heuristic:heuristic
		   ~skip_fails:skip_fails
		   ~cost:cost
		   model rows cols)
    (Printf.sprintf "%s %dx%d tile puzzles (%s)" model rows cols cost)
    xkey alg_list


let wted_tiles ?(xkey = "total raw cpu time") cost alg_list =
  load_agnostic (Load_dataset.wted_korf_100_tiles cost)
    ("Korf sliding tiles with "^cost^" cost")
    xkey alg_list


let chess ?(xkey = "total raw cpu time") ?(skip_fails=false)
    rows cols n_pieces alg_list =
  load_agnostic (Load_dataset.chess ~skip_fails:skip_fails rows cols n_pieces)
    (Printf.sprintf "Solitaire Chess %dx%d %d pieces" rows cols
    n_pieces)
    xkey alg_list

let hanoi ?(xkey = "total raw cpu time") ?(skip_fails=false)
    ?(pdb_type="Felner_packed")
    up
    down
    pegs
    disks
    alg_list =
  load_agnostic
    (Load_dataset.hanoi
       ~skip_fails:skip_fails ~pdb_type:pdb_type
       up down pegs disks)
    ("Towers of Hanoi ("^(string_of_int disks)^")")
    xkey alg_list


let topspin ?(xkey = "total raw cpu time") ?(skip_fails=false)
    ?(heuristic="h_b")
    ~flipper
    ~disks
    alg_list =
  load_agnostic
    (Load_dataset.topspin
       ~skip_fails:skip_fails ~heuristic:heuristic
       ~disks ~flipper)
    ("Topspin ("^(string_of_int disks)^", "^(string_of_int flipper)^")")
    xkey alg_list



let eight ?(xkey = "total raw cpu time") alg_list =
  table_raw (Load_dataset.eight_puzzles 1) "Eight Puzzles"
    xkey alg_list


let macro_tiles ?(xkey = "total raw cpu time") alg_list =
  table_raw Load_dataset.macro_korf_100_tiles "Macro Korf's 100 15 Puzzles"
    xkey alg_list

let u4grid ?(xkey = "total raw cpu time") alg_list =
  table_raw Load_dataset.standard_unit_4_grids
    "Unit Four-way Grids 35% Obstacles" xkey alg_list


let u8grid ?(xkey = "total raw cpu time") alg_list =
  table_raw Load_dataset.standard_unit_8_grids
    "Unit Eight-way Grids 45% Obstacles" xkey alg_list


let l4grid ?(xkey = "total raw cpu time") alg_list =
  table_raw Load_dataset.standard_life_4_grids
    "Life Four-way Grids 35% Obstacles" xkey alg_list

let l4grid_plot ?(xkey = "total raw cpu time") alg_list =
  load_agnostic Load_dataset.standard_life_4_grids
    "Life Four-way Grids 35% Obstacles" xkey alg_list


let u4grid_plot ?(xkey = "total raw cpu time") alg_list =
  load_agnostic Load_dataset.standard_unit_4_grids
    "Unit Four-way Grids 35% Obstacles" xkey alg_list


let small_life ?(xkey = "total raw cpu time") alg_list =
  table_raw Load_dataset.small_life_4_grids
    "Life Four-way Grids 35% Obstacles" xkey alg_list



let l8grid ?(xkey = "total raw cpu time") alg_list =
  load_agnostic Load_dataset.standard_life_8_grids
    "Life Eight-way Grids 45% Obstacles" xkey alg_list


let robots ?(xkey = "total raw cpu time") alg_list =
  table_raw Load_dataset.standard_robots "Dynamic Robot Navigation"
    xkey alg_list


let pancakes ?(xkey = "total raw cpu time") alg_list =
  load_agnostic Load_dataset.standard_pancakes "Pancake Puzzle"
    xkey alg_list


let pkhard ?(xkey = "total raw cpu time") alg_list =
  table_raw Load_dataset.standard_pkhard "100 City TSP - PK Hard"
    xkey alg_list


let usquare ?(xkey = "total raw cpu time") alg_list =
  table_raw Load_dataset.standard_usquare "100 City TSP - Unit Square"
    xkey alg_list


let vacuum ?(xkey = "total raw cpu time") alg_list =
  load_agnostic Load_dataset.standard_vacuum "Unit Vacuum Problem"
    xkey alg_list


let heavy_vacuum ?(xkey = "total raw cpu time") alg_list =
  table_raw Load_dataset.heavy_vacuum "Heavy Vacuum Problem"
    xkey alg_list


let small_vacuum ?(xkey = "total raw cpu time") alg_list =
  load_raw Load_dataset.small_vacuum "Unit Vacuum Problem"
    xkey alg_list


let tiny_vacuum ?(xkey = "total raw cpu time") alg_list =
  table_raw Load_dataset.tiny_vacuum "Vacuum Problem"
    xkey alg_list

let tiny_heavy_vacuum ?(xkey = "total raw cpu time") alg_list =
  table_raw Load_dataset.tiny_heavy_vacuum "Vacuum Problem"
    xkey alg_list



let dock_robot_plot ?(xkey = "total raw cpu time") alg_list =
  load_agnostic Load_dataset.dock_robot "Dockyard Robots"
    xkey alg_list

let dock_robot ?(xkey = "total raw cpu time") alg_list =
  table_raw Load_dataset.dock_robot "Dockyard Robots"
    xkey alg_list

let big_dock_robot ?(xkey = "total raw cpu time") alg_list =
  table_raw Load_dataset.big_dock_robot "Dockyard Robots"
    xkey alg_list


(* EOF *)
