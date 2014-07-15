open Camlp4.PreCast

module Id : Camlp4.Sig.Id =
    struct
      let name = "glr"
      let version = "0.1"
    end

module Extension (Syntax : Camlp4.Sig.Camlp4Syntax) =
	struct
include Syntax

let glr_rule = Gram.Entry.mk "glr_rule"
let glr_rules = Gram.Entry.mk "glr_rules"
let glr_rules_aux = Gram.Entry.mk "glr_rules"
let glr_option = Gram.Entry.mk "glr_option"
let glr_cond = Gram.Entry.mk "glr_cond"
let glr_left_member = Gram.Entry.mk "glr_left_member"
let glr_sequence = Gram.Entry.mk "glr_sequence"
let glr_opt_expr = Gram.Entry.mk "glr_opt_expr"
let glr_ident = Gram.Entry.mk "glr_ident"
let glr_action = Gram.Entry.mk "glr_action"

let glr_list_rule = Gram.Entry.mk "glr_list_rule"
let glr_list_rules = Gram.Entry.mk "glr_list_rules"
let glr_list_rules_aux = Gram.Entry.mk "glr_list_rules"
let glr_list_sequence = Gram.Entry.mk "glr_list_sequence"
let glr_list_left_member = Gram.Entry.mk "glr_list_left_member"

let do_locate = ref None

let rec apply _loc ids e =
  let e = match !do_locate with
      None -> e
    | Some(_,merge) ->
      match ids with
      | [] -> e
      | [id] -> <:expr<let $lid:"_loc"$ = $lid:"_loc_"^id$ in $e$>>
      | first::ids ->
	let last = List.hd (List.rev ids) in
	<:expr<let $lid:"_loc"$ = $merge$ $lid:"_loc_"^first$ $lid:"_loc_"^last$ in $e$>>
  in
  List.fold_left (fun e id -> 
    match !do_locate with
      None ->
	<:expr<fun $lid:id$ -> $e$>>
    | Some(_) ->  
      <:expr<fun $lid:id$ -> let $lid:"_loc_"^id$ = fst $lid:id$ in let $lid:id$ = snd $lid:id$ in $e$>>
  ) e (List.rev ids)

let filter _loc r =
  match !do_locate with
    None -> r
  | Some(f,_) -> <:expr<$f$ $r$>>
 
let apply_option _loc opt e = 
  filter _loc (match opt with
    `Once -> e
  | `Option d ->
    (match d with None ->
      <:expr<Glr.option None (Glr.apply (fun x -> Some x) $e$)>>
    | Some d ->
      <:expr<Glr.option $d$ $e$>>)
  | `OptionPrime d ->
    (match d with None ->
      <:expr<Glr.option' None (Glr.apply (fun x -> Some x) $e$)>>
    | Some d ->
      <:expr<Glr.option' $d$ $e$>>)
  | `Fixpoint d ->
    (match d with None ->
      <:expr<Glr.apply List.rev (Glr.fixpoint [] (Glr.apply (fun x l -> [x :: l]) $e$))>>
    | Some d ->
      <:expr<Glr.fixpoint $d$ $e$>>)
  | `FixpointPrime d ->
    (match d with None ->
      <:expr<Glr.apply List.rev (Glr.fixpoint' [] (Glr.apply (fun x l -> [x :: l]) $e$))>>
    | Some d ->
      <:expr<Glr.fixpoint $d$ $e$>>)
  | `Fixpoint1 d ->
   (match d with None ->
       <:expr<Glr.sequence $e$ (Glr.fixpoint [] (Glr.apply (fun x l -> [x :: l]) $e$)) (fun e l -> [e::List.rev l])>>
   | Some d ->
      <:expr<Glr.dependent_sequence $e$ (fun x -> Glr.fixpoint (x $d$) $e$)>>)
  | `Fixpoint1Prime d ->
   (match d with None ->
      <:expr<Glr.sequence $e$ (Glr.fixpoint' [] (Glr.apply (fun x l -> [x :: l]) $e$)) (fun e l -> [e::List.rev l])>>
   | Some d ->
      <:expr<Glr.dependent_sequence $e$ (fun x -> Glr.fixpoint' (x $d$) $e$)>>))

let apply_list_option _loc opt e = 
  filter _loc (match opt with
    `Once -> e
  | `Option d ->
    (match d with None ->
      <:expr<Glr.option [] $e$>>
    | Some d ->
      <:expr<Glr.option [$d$] $e$>>)
  | `OptionPrime d ->
    (match d with None ->
      <:expr<Glr.option' [] $e$>>
    | Some d ->
      <:expr<Glr.option' [$d$] $e$>>)
  | `Fixpoint d ->
    (match d with None ->
      <:expr<Glr.apply (List.map List.rev) (Glr.list_fixpoint [] (Glr.apply (fun x l -> List.map (fun x -> [x :: l]) x) $e$))>>
    | Some d ->
      <:expr<Glr.list_fixpoint $d$ $e$>>)
  | `FixpointPrime d ->
    (match d with None ->
      <:expr<Glr.apply (List.map List.rev) (Glr.list_fixpoint' [] (Glr.apply (fun x l -> List.map (fun x -> [x :: l]) x) $e$))>>
    | Some d ->
      <:expr<Glr.list_fixpoint' $d$ $e$>>)
  | `Fixpoint1 d ->
   (match d with None ->
       <:expr<Glr.list_sequence $e$ (Glr.list_fixpoint [] (Glr.apply (fun x l -> List.map (fun x -> [x :: l]) x) $e$)) (fun e l -> [e::List.rev l])>>
   | Some d ->
      <:expr<Glr.list_dependent_sequence $e$ (fun x -> Glr.list_fixpoint (x $d$) $e$)>>)

  | `Fixpoint1Prime d ->
   (match d with None ->
      <:expr<Glr.list_sequence $e$ (Glr.list_fixpoint' [] (Glr.apply (fun x l -> List.map (fun x -> [x :: l]) x) $e$)) (fun e l -> [e::List.rev l])>>
   | Some d ->
      <:expr<Glr.list_dependent_sequence $e$ (fun x -> Glr.list_fixpoint' (x $d$) $e$)>>))

EXTEND Gram
  expr: LEVEL "simple" [ [
    "glr_locate"; filter = expr LEVEL "simple"; merge = expr LEVEL "simple" ->
      do_locate := Some(filter,merge); <:expr<()>>
  ] ];

  expr: LEVEL "simple" [ [
    "glr"; p = glr_rules; "end" -> p 
  | "glr"; "*"; p = glr_list_rules; "end" -> p 
  ] ];

  glr_option: [ [
    -> `Once
  | "*"; e =  glr_opt_expr -> `Fixpoint e
  | "**"; e =  glr_opt_expr -> `FixpointPrime e
  | "+"; e =  glr_opt_expr -> `Fixpoint1 e
  | "++"; e =  glr_opt_expr-> `Fixpoint1Prime e
  | "?"; e =  glr_opt_expr-> `Option e
  | "??"; e =  glr_opt_expr-> `OptionPrime e
  ] ];

  glr_rules_aux: [ [
    l = LIST1 glr_rule SEP "|" ->
      match l with
	[] -> assert false
      | [e] -> e
      | l -> 
	let l = List.fold_right (fun (cond,x) y -> 
	  match cond with
	    None ->
	      <:expr<[$x$::$y$]>>
          | Some c -> 
	      <:expr<if $c$ then [$x$::$y$] else $y$>>
	) l <:expr<[]>> in
	None, <:expr<Glr.alternatives $l$ >>
  ] ];

  glr_list_rules_aux: [ [
    l = LIST1 glr_list_rule SEP "|" ->
      match l with
	[] -> assert false
      | [e] -> e
      | l -> 
	let l = List.fold_right (fun (cond,x) y -> 
	  match cond with
	    None ->
	      <:expr<[$x$::$y$]>>
          | Some c -> 
	      <:expr<if $c$ then [$x$::$y$] else $y$>>
	) l <:expr<[]>> in
	None, <:expr<Glr.list_alternatives $l$ >>
  ] ];

  glr_rules: [ [
    l = LIST1 glr_rules_aux SEP "||" ->
      match l with
	[] -> assert false
      | [cond,e] -> (
	match cond with
	  None -> e
        | Some c -> 
	      <:expr<if $c$ then $e$ else Glr.fail>>)
      | l -> 
	let l = List.fold_right (fun (cond,x) y -> 
	  match cond with
	    None ->
	      <:expr<[$x$::$y$]>>
          | Some c -> 
	      <:expr<if $c$ then [$x$::$y$] else $y$>>
	) l <:expr<[]>> in
	<:expr<Glr.alternatives' $l$ >>
  ] ];

  glr_list_rules: [ [
    l = LIST1 glr_list_rules_aux SEP "||" ->
      match l with
	[] -> assert false
      | [cond,e] ->  (
	match cond with
	  None -> e
        | Some c -> 
	  <:expr<if $c$ then $e$ else Glr.fail>>)
      | l -> 
	let l = List.fold_right (fun (cond,x) y -> 
	  match cond with
	    None ->
	      <:expr<[$x$::$y$]>>
          | Some c -> 
	      <:expr<if $c$ then [$x$::$y$] else $y$>>
	) l <:expr<[]>> in
	<:expr<Glr.list_alternatives' $l$ >>
  ] ];
  
  glr_action: [ [
    "->"; action = expr LEVEL "apply" -> Some action
  | -> None
  ] ];

  glr_cond: [ [
    "when"; c = expr LEVEL "apply" -> Some c
  | -> None
  ] ];


  glr_rule: [ [
    l = glr_left_member; condition = glr_cond; action = glr_action ->
    let action = match action with
	Some a -> a
      | None ->
	let rec fn = function
        [] -> failwith "No default action can be found"
	  | ("_",_,_)::ls -> fn ls
	  | (id,_,_)::_ -> <:expr<$lid:id$>>
	in fn l
    in	
    let rec fn ids l = match l with
      [] -> assert false
    | [(id:string),e,opt] ->
      let e = apply_option _loc opt e in
      <:expr<Glr.apply $apply _loc (id::ids) action$ $e$>>
    | [ (id,e,opt); (id',e',opt') ] ->
      let e = apply_option _loc opt e in
      let e' = apply_option _loc opt' e' in
      <:expr<Glr.sequence $e'$ $e$ $apply _loc (id'::id::ids) action$>>
    | (id,e,opt) :: ls ->
      let e = apply_option _loc opt e in      
      <:expr<Glr.sequence $fn (id::ids) ls$ $e$ (fun x -> x)>>
    in
    condition, fn [] (List.rev l)
  ] ];

  glr_list_rule: [ [
    l = glr_list_left_member; condition = glr_cond; action = glr_action ->
    let action = match action with
	Some a -> a
      | None ->
	let rec fn = function
        [] -> failwith "No default action can be found"
	  | ("_",_,_)::ls -> fn ls
	  | (id,_,_)::_ -> <:expr<$lid:id$>>
	in fn l
    in	
    let rec fn ids l = match l with
      [] -> assert false
    | [(id:string),e,opt] ->
      let e = apply_list_option _loc opt e in
      <:expr<Glr.apply $apply _loc (id::ids) action$ $e$>>
    | [ (id,e,opt); (id',e',opt') ] ->
      let e = apply_list_option _loc opt e in
      let e' = apply_list_option _loc opt' e' in
      <:expr<Glr.list_sequence $e'$ $e$ $apply _loc (id'::id::ids) action$>>
    | (id,e,opt) :: ls ->
      let e = apply_list_option _loc opt e in      
      <:expr<Glr.list_sequence $fn (id::ids) ls$ $e$ (fun x -> x)>>
    in
    condition, fn [] (List.rev l)
  ] ];

  glr_left_member: [ [
    id = glr_ident; s = glr_sequence; opt = glr_option -> [id, s, opt]
  | id = glr_ident; s = glr_sequence; opt = glr_option; l = glr_left_member -> (id, s, opt)::l
  ] ];

  glr_list_left_member: [ [
    id = glr_ident; s = glr_list_sequence; opt = glr_option -> [id, s, opt]
  | id = glr_ident; s = glr_list_sequence; opt = glr_option; l = glr_list_left_member -> (id, s, opt)::l
  ] ];

  glr_opt_expr: [ [
    -> None
  | "["; e = expr; "]" -> Some e
  ] ];

  glr_ident: [ [
    id = LIDENT; ":" -> id
  | -> "_"
  ] ];

  glr_sequence: [ [
    "{"; r = glr_rules; "}" -> r

  | "EOF"; opt = glr_opt_expr ->
      let e = match opt with None -> <:expr<()>> | Some e -> e in
      <:expr<Glr.eof $e$>>

  | "STR"; str = expr LEVEL "simple"; opt = glr_opt_expr ->
      let e = match opt with None -> <:expr<()>> | Some e -> e in
      <:expr< Glr.string $str$  $e$>>

  | "RE"; str = expr LEVEL "simple"; opt = glr_opt_expr ->
      let e = match opt with None -> <:expr<groupe 0>> | Some e -> <:expr<$e$>> in
      <:expr<Glr.regexp $str$ (fun groupe -> $e$)>>

  | e = expr LEVEL "simple" -> e

  ] ];

  glr_list_sequence: [ [
    "{"; r = glr_list_rules; "}" -> r

  | "EOF"; opt = glr_opt_expr ->
      let e = match opt with None -> <:expr<()>> | Some e -> e in
      <:expr<Glr.list_eof $e$>>

  | "STR"; str = expr LEVEL "simple"; opt = glr_opt_expr ->
      let e = match opt with None -> <:expr<()>> | Some e -> e in
      <:expr< Glr.list_string $str$  $e$>>

  | "RE"; str = expr LEVEL "simple"; opt = glr_opt_expr ->
      let e = match opt with None -> <:expr<groupe 0>> | Some e -> <:expr<$e$>> in
      <:expr<Glr.list_regexp $str$ (fun groupe -> $e$)>>

  | e = expr LEVEL "simple" -> e

  ] ];
	END
;;

end

module M = Camlp4.Register.OCamlSyntaxExtension(Id)(Extension)
