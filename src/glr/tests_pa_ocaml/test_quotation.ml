
let e = <:expr<2+2>>

let f x y t p = <:expr<3 * $x$ * (match $y$ : $t$ with $p$ -> $y$ | _ -> $x$) + 2>> 

let g a x y = <:str_item<let $lid:a$ = $x$ and b = $lid:y$>>

let h x y = <:sig_item<val $lid:x$ : $y$>>

let j a b c d e f g h = <:expr<$bool:a$, $int:b$, $int32:c$, $int64:d$, $natint:e$, $char:f$, $string:g$, $float:h$>>

let k a b c1 c2 = <:str_item<type ('$ident:a$) $lid:b$ = $uid:c1$ | $uid:c2$ of '$ident:a$>>

let l a b = <:type<[ `$ident:a$ | `$ident:b$ ]>> 
