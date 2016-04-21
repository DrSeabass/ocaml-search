(* $Id: problem.ml,v 1.2 2003/07/07 21:20:50 ruml Exp ruml $

   medium-level interface for emitting postscript.  defines some commands.
*)


open Box


type cap_style = Butt | Round | Square

type join_style = Miter | Smooth | Bevel

type justification = Left | Right | Center

type t = {
  ch : out_channel;
}


(**** utils *****)


let in2pt x =
  x *. 72.


let pr pso =
  (** takes [t] and then arguments like [printf].  Emits direectly
    into postscript stream without any checking or newlines **)
  Printf.fprintf pso.ch


let max_ps_int = 32760.
let min_ps_int = -32760.

let prnum pso x =
  (if (Math.integral_p x) && (x < max_ps_int) && (x > min_ps_int) then
     pr pso "%d" (truncate x)
   else
     let s1 = Wrutils.str "%.1f" x in
     let s1 = if Wrstr.ends_as ".0" s1 then Wrstr.chop ~n:2 s1 else s1 in
     let s2 = Wrutils.str "%.4e" x in
     let s2 = Wrstr.replace_strings s2 ["0e", "e";
					"e+", "e";
					"e00", ""; "e-00", "";
					"e0", "e"; "e-0", "e-"] in
     let s = if (String.length s2) < (String.length s1) then s2 else s1 in
       output_string pso.ch s);
  pr pso " "


let prnums pso nums =
  List.iter (prnum pso) nums


let psstr s =
  (** translates string using any necessary postscript escape sequences *)
  Wrstr.replace_strings s ["\\", "\\\\";
			   "(", "\\(";
			   ")", "\\)";
			   "\n", "\\n";
			   "\r", "\\r";
			   "\t", "\\t"]


let gray lightness =
  (** returns an RGB triplet *)
  lightness, lightness, lightness


let black = gray 0.
let dark_gray = gray 0.3
let med_gray = gray 0.5
let light_gray = gray 0.7
let white = gray 1.

let solid = [], 0.


(****** prolog and trailer ******)


type orientation = Portrait | Landscape


let process_title s =
  let s = String.sub s 0 (min 40 (String.length s)) in
    Wrstr.replace_strings s ["\n", " "; "\r", " "]


let header pso bbox title orientation =
  pr pso "%%!PS-Adobe-3.0 EPSF-3.0\n";
  pr pso "%%%%BoundingBox: %d %d %d %d\n"
    (Math.floor_int bbox.llx)
    (Math.floor_int bbox.lly)
    (Math.ceil_int bbox.urx)
    (Math.ceil_int bbox.ury);
  pr pso "%%%%Title: %s\n" (process_title title);
  pr pso "%%%%Creator: psout.ml OCaml package by Wheeler Ruml (ruml@parc.com).\n";
  pr pso "%%%%CreationDate: %s\n" (Wrsys.time_string ());
  pr pso "%%%%Pages: 0\n";
  pr pso "%%%%Orientation: %s\n" (match orientation with
				    Portrait -> "Portrait"
				  | Landscape -> "Landscape");
  pr pso "%%%%EndComments\n"


let prolog pso =
  output_string pso.ch "%%BeginProlog
100 dict begin

% these are only the standard operators,
% more may be defined in the script...

% avoid run-time lookup of procedure names
/bdef {bind def} bind def

% sx sy ex ey LINE -   line from s to e
/line {4 2 roll moveto lineto stroke} bdef

% x y L -   shorthand for lineto
/l {lineto} bdef

% x y w h RECT -   rectangle of w and h with lower-left corner at x and y.
/rect {4 2 roll moveto 1 index 0 rlineto 0 exch rlineto neg 0 rlineto
closepath stroke} bdef

% x y w h FRECT -  filled rectangle
/frect {4 2 roll moveto 1 index 0 rlineto 0 exch rlineto neg 0 rlineto
closepath fill} bdef

% x y r CIRCLE -   centered circle
/circle {newpath 0 360 arc stroke} bdef

% x y r FCIRCLE -   filled circle
/fcircle {newpath 0 360 arc fill} bdef

% fontname size DOFONT -   set font
/dofont {exch findfont exch scalefont setfont} bdef

% str CSHOW -   write string centered
/cshow {dup stringwidth pop 2 div neg 0 rmoveto show} bdef

% str RSHOW -  write string right justified
/rshow {dup stringwidth pop neg 0 rmoveto show} bdef

% x y str TEXT -  write string at point
/text {3 1 roll moveto show} bdef

% x y str CTEXT -  write string centered at point
/ctext {3 1 roll moveto cshow} bdef

% x y str RTEXT -  write string right justified
/rtext {3 1 roll moveto rshow} bdef

% x y angle str ROTEXT -  write string rotated at point
/rotext {gsave 4 2 roll translate 0 0 moveto
          exch rotate show grestore} bdef

% x y angle str CROTEXT -  write string centered and rotated at point
/crotext {gsave 4 2 roll translate 0 0 moveto
          exch rotate cshow grestore} bdef

%%EndProlog

"


let start_body pso =
  pr pso "gsave\n\n"


let end_body pso showpage_p =
  pr pso "\ngrestore\n";
  if showpage_p then pr pso "showpage\n";
  pr pso "end %% matches `XXX dict begin' from prolog\n";
  pr pso "%%%%EOF\n"


(***** constructors *****)


let to_ch bbox title orientation showage_p f ch =
  let pso = { ch = ch } in
    header pso bbox title orientation;
    prolog pso;
    start_body pso;
    let res = f pso in
      end_body pso showage_p;
      res


let to_file path bbox title orientation showpage_p f =
  Wrio.with_outfile path
    (to_ch bbox title orientation showpage_p f)


(****** low level ********)


let setfont pso (name, size) =
  pr pso "/%s %.1f dofont\n" name size

let setwidth pso width =
  pr pso "%.2f setlinewidth\n" width

let setcolor pso (r,g,b) =
  pr pso "%.3f %.3f %.3f setrgbcolor\n" r g b

let setdash pso (pat, offset) =
  pr pso "[";
  List.iter (fun x -> pr pso "%.2f " x) pat;
  pr pso "] %.2f setdash\n" offset

let setcap pso cap =
  pr pso "%d setlinecap\n"
    (match cap with Butt -> 0 | Round -> 1 | Square -> 2)

let setjoin pso join =
  pr pso "%d setlinejoin\n"
    (match join with Miter-> 0 | Smooth -> 1 | Bevel -> 2)


(******* medium level *******)


let may f = function
    None -> ()
  | Some x -> f x


let line pso ?width ?color ?dash ?cap startx starty endx endy =
  may (setwidth pso) width;
  may (setcolor pso) color;
  may (setdash pso) dash;
  may (setcap pso) cap;
  prnums pso [startx; starty; endx; endy];
  pr pso " line\n"


let path pso pts =
  match pts with
   (x,y)::((_,_)::_ as rest) ->
      prnums pso [x; y]; pr pso "moveto\n";
      List.iter (fun (x,y) ->
		   prnums pso [x; y]; pr pso "l\n")
	rest
  | _ -> invalid_arg "fewer than two points to Psout.path"


let polyline pso ?width ?color ?dash ?cap ?join pts =
  may (setwidth pso) width;
  may (setcolor pso) color;
  may (setdash pso) dash;
  may (setcap pso) cap;
  may (setjoin pso) join;
  path pso pts;
  pr pso "stroke\n"


let fpolyline pso ?color pts =
  may (setcolor pso) color;
  path pso pts;
  pr pso "fill\n"


let rect pso ?width ?color ?dash ?join llx lly w h =
  may (setwidth pso) width;
  may (setcolor pso) color;
  may (setdash pso) dash;
  may (setjoin pso) join;
  prnums pso [llx; lly; w; h]; pr pso "rect\n"


let frect pso ?color llx lly w h =
  may (setcolor pso) color;
  prnums pso [llx; lly; w; h]; pr pso "frect\n"


let circle pso ?width ?color ?dash x y r =
  may (setwidth pso) width;
  may (setcolor pso) color;
  may (setdash pso) dash;
  prnums pso [x; y; r]; pr pso "circle\n"


let fcircle pso ?color x y r =
  may (setcolor pso) color;
  prnums pso [x; y; r]; pr pso "fcircle\n"


let text pso ?font ?(justify = Left) ?(rotation = 0.) ?color x y s =
  may (setfont pso) font;
  may (setcolor pso) color;
  prnums pso [x; y];
  let s = psstr s in
    if rotation = 0. then
      pr pso "(%s) %s\n" s
	(match justify with
	   Left -> "text" | Right -> "rtext" | Center -> "ctext")
    else
      (prnum pso rotation;
       pr pso "(%s) %s\n" s
	 (match justify with
	    Left -> "rotext" | Center -> "crotext"
	  | Right -> failwith "rotated right-justified text not implemented"))


(********* viewing **********)


let view path =
  let r = Sys.command ("gv " ^ path) in
    if r != 0 then
      failwith (Wrutils.str "gv returned exit code %d"  r)


(* EOF *)
