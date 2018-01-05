Add Rec LoadPath "/home/zeimer/Code/Coq".

Require Import HSLib.Base.
Require Import HSLib.MonadBind.Monad.
Require Import HSLib.MonadBind.MonadInst.

(** * Monadic Parser Combinators *)

(** This file is a Coq translation of code taken from the paper "Monadic
    Parser Combinators" by Graham Hutton and Erik Meijer. *)

Require Import Ascii.
Require Import String.

(** ** 1 Introduction *)

(** ** 2 Combinator parsers *)

(** *** 2.1 The type of parsers *)

Definition Parser (A : Type) : Type := string -> list (A * string).

(** *** 2.2 Primitive parsers *)

Definition result {A : Type} (x : A) : Parser A :=
  fun input : string => [(x, input)].

Definition zero {A : Type} : Parser A :=
  fun _ => [].

Definition item : Parser ascii :=
  fun input : string =>
  match input with
      | EmptyString => []
      | String c cs => [(c, cs)]
  end.

(** *** 2.3 Parser combinators *)

Fixpoint join {A : Type} (lla : list (list A)) : list A :=
match lla with
    | [] => []
    | l :: ls => l ++ join ls
end.

Definition bind_Parser
  {A B : Type} (p : Parser A) (f : A -> Parser B) : Parser B :=
  fun input : string =>
    join (map (fun '(v, input') => f v input') (p input)).

(* BEWARE: monad stuff moved here *)
Definition fmap_Parser {A B : Type} (f : A -> B) (p : Parser A) : Parser B :=
  fun input : string =>
    map (fun p => (f (fst p), snd p)) (p input).

Instance FunctorParser : Functor Parser :=
{
    fmap := @fmap_Parser;
}.
Proof.
  intros. unfold fmap_Parser, id. ext p; ext s.
    induction (p s) as [| [r s'] rs]; cbn; rewrite ?IHrs; reflexivity.
  intros. unfold fmap_Parser, compose. ext p; ext s.
    induction (p s) as [| [r s'] rs]; cbn; rewrite ?IHrs; reflexivity.
Defined.

Instance MonadParser : Monad Parser :=
{
    is_functor := FunctorParser;
    ret := @result;
    bind := @bind_Parser
}.
Proof.
  all: intros; unfold bind_Parser, result.
    ext s. cbn. rewrite app_nil_r. reflexivity.
    ext s. induction (ma s) as [| [x s'] rs];
      cbn in *; rewrite ?IHrs; reflexivity.
    Focus 2. trivial.
    Axiom wut : False. all: destruct wut.
Defined.

Definition seq
  {A B : Type} (pa : Parser A) (pb : Parser B) : Parser (A * B) :=
    pa >>= fun a => pb >>= fun b => ret (a, b).

Definition sat (p : ascii -> bool) : Parser ascii :=
  item >>= fun c : ascii => if p c then ret c else zero.

Require Import Bool.

Definition ascii_eqb (x y : ascii) : bool :=
  if ascii_dec x y then true else false.

Lemma ascii_eqb_spec :
  forall x y : ascii, reflect (x = y) (ascii_eqb x y).
Proof.
  intros. unfold ascii_eqb.
  destruct (ascii_dec x y); firstorder.
Qed.

Definition char (c : ascii) : Parser ascii :=
  sat (fun c' : ascii => ascii_eqb c c').

Open Scope char_scope.
Open Scope string_scope.

Require Import Arith.

Definition digit : Parser ascii :=
  sat (fun c : ascii =>
    Nat.leb 48 (nat_of_ascii c) && Nat.leb (nat_of_ascii c) 57).

Definition lower : Parser ascii :=
  sat (fun c : ascii =>
    Nat.leb 97 (nat_of_ascii c) && Nat.leb (nat_of_ascii c) 122).

Definition upper : Parser ascii :=
  sat (fun c : ascii =>
    Nat.leb 65 (nat_of_ascii c) && Nat.leb (nat_of_ascii c) 90).

Open Scope list_scope.

Definition plus {A : Type} (p1 p2 : Parser A) : Parser A :=
  fun input : string => (p1 input) ++ (p2 input).

Definition letter : Parser ascii :=
  plus lower upper.

Definition alphanum : Parser ascii :=
  plus letter digit.

(** All words of length less than or equal to n. *)
Fixpoint words (n : nat) : Parser string :=
match n with
    | 0 => result ""
    | S n' => plus
                (bind_Parser letter (fun c =>
                 bind_Parser (words n') (fun cs =>
                   result (String c cs))))
                (result "")
end.

(** A word of any length. *)
Definition word : Parser string :=
  fun input : string => words (String.length input) input.

(** ** 3 Parsers and monads *)

(** *** 3.1 The parser monad *)

(* TODO *)

(* beware: moved to the beginning *)
(** *** 3.2 Monad comprehension syntax *)

Fixpoint str (s : string) : Parser string :=
(*  fun input : string =>*)
match s with
    | "" => result ""
    | String c cs =>
        (*bind_Parser (char c) (fun _ =>
          bind_Parser (str cs) (fun _ => result (String c cs)))*)
        liftM2 String (char c) (str cs)
end.

Compute str "abc" "abcd".

(** ** 4 Combinators for repetition *)

(** *** 4.1 Simple repetition *)

Fixpoint many' {A : Type} (n : nat) (p : Parser A) : Parser (list A) :=
match n with
    | 0 => result []
    | S n' => plus
                (bind_Parser p (fun h =>
                 bind_Parser (many' n' p) (fun t =>
                   result (h :: t))))
                (result [])
end.

Open Scope char_scope.

Compute many' 5 letter "asdsd"%string.

Definition many {A : Type} (p : Parser A) : Parser (list A) :=
  fun input : string => many' (String.length input) p input.

Compute many digit "123"%string.

Definition fmap {A B : Type} (f : A -> B) (p : Parser A) : Parser B :=
  fun input : string =>
    map (fun p => (f (fst p), snd p)) (p input).

Fixpoint toString (l : list ascii) : string :=
match l with
    | [] => ""
    | c :: cs => String c (toString cs)
end.

Definition word' : Parser string :=
  fmap toString (many letter).

Compute word "abc"%string.
Compute word' "abc"%string.

Definition ident : Parser string := do
  c <- lower;
  cs <- fmap toString (many alphanum);
  ret (String c cs).

Compute ident "wut123"%string.

Definition many1 {A : Type} (p : Parser A) : Parser (list A) :=
  liftM2 cons p (many p).

Compute many1 (char "a") "aaab"%string.

Fixpoint eval (cs : list ascii) : nat :=
match cs with
    | [] => 0
    | c :: cs' => nat_of_ascii c - 48 + 10 * eval cs'
end.

Definition parseNat : Parser nat :=
  fmap (fun l => eval (rev l)) (many1 digit).

Compute parseNat "123"%string.

Require Import ZArith.

Definition parseNeg : Parser nat := do
  char "-";;
  r <- many1 digit;
  ret $ eval (rev r).

Definition parseZ : Parser Z :=
  plus
    (fmap Z_of_nat parseNat)
    (fmap (fun n => Z.sub 0%Z (Z_of_nat n)) parseNeg).

Compute parseZ "-12345"%string.

Definition parseSign : Parser (Z -> Z) :=
  plus
    (char "-" >> ret (fun k => Z.sub 0%Z k))
    (ret id).

(*  liftM2 (fun f x => f x) parseSign (fmap Z_of_nat parseNat).*)
Definition parseZ' : Parser Z := do
  sgn <- parseSign;
  n <- parseNat;
  ret $ sgn (Z_of_nat n).

Compute parseZ' "-12345"%string.

(** *** 4.2 Repetition with separators *)

Definition sepby1 {A B : Type} (p : Parser A) (sep : Parser B) : 
  Parser (list A) := do
    h <- p;
    t <- many (sep >> p);
    ret (h :: t).
(*    bind_Parser p (fun h =>
    bind_Parser (many (bind_Parser sep (fun _ => p))) (fun t =>
      result (h :: t))).*)

Definition bracket {A B C : Type}
  (open : Parser A) (content : Parser B) (close : Parser C) : Parser B := do
    open;;
    res <- content;
    close;;
    ret res.
(*    bind_Parser open (fun _ =>
    bind_Parser content (fun res =>
    bind_Parser close (fun _ =>
      result res))).*)

Definition ints : Parser (list Z) :=
  bracket (char "[") (sepby1 parseZ (char ",")) (char "]").

Compute ints "[1,2]"%string.

Definition sepby {A B : Type}
  (item : Parser A) (sep : Parser B) : Parser (list A) :=
    plus (sepby1 item sep) (result []).

(** *** 4.3 Repetition with meaningful separators *)

(**
    expr    ::= expr addop factor | factor
    addop   ::= + | -
    factor  ::= nat | ( expr )
*)

Fixpoint exprn (n : nat) : Parser Z :=
match n with
    | 0 => result 42%Z
    | S n' =>
        let
          addop := plus (char "+" >> ret Z.add)
                        (char "-" >> ret Z.sub)
        in let
          factor := plus parseZ
                         (bracket (char "(") (exprn n') (char ")"))
        in
          plus
            (*(do
              x <- exprn n';
              op <- addop;
              y <- factor;
              ret $ op x y)*)
            (liftM3 (fun x op y => op x y) (exprn n') addop factor)
            factor
end.

Definition expr : Parser Z :=
  fun input : string => exprn (String.length input) input.

Compute expr "2+2"%string.

Compute expr "0-5)"%string.

Notation "a |: b" := (plus a b) (at level 50).

(*Definition chainl1
  {A : Type} (p : Parser A) (p_op : Parser (A -> A -> A)) : Parser A :=
    bind_Parser p (fun start =>
    bind_Parser (many (bind_Parser p_op (fun op =>
                bind_Parser p (fun arg =>
                  result (op, arg)))))
         (fun l => result (fold_left (fun x p => fst p x (snd p)) l start))).
*)

(*Definition chainl1
  {A : Type} (p : Parser A) (p_op : Parser (A -> A -> A)) : Parser A :=
  do
    h <- p;
    t <- many $ do
      op <- p_op;
      arg <- p;
      ret (op, arg);
    ret $ fold_left (fun x '(f, y) => f x y) t h.*)

Definition chainl1
  {A : Type} (obj : Parser A) (op : Parser (A -> A -> A)) : Parser A :=
  do
    h <- obj;
    t <- many $ liftM2 pair op obj;
    ret $ fold_left (fun x '(f, y) => f x y) t h.

Definition parseNat_chainl : Parser nat :=
  let op m n := 10 * m + n in
    chainl1 (fmap (fun d => nat_of_ascii d - nat_of_ascii "0") digit) (ret op).

Compute parseNat_chainl "211"%string.

Locate "$$".
Fixpoint chainr1_aux {A : Type} (arg : Parser A) (op : Parser (A -> A -> A))
  (n : nat) : Parser A :=
match n with
    | 0 => zero
    | S n' => do
        x <- arg;
        plus (op $$ ret x $$ chainr1_aux arg op n') (ret x)
end.

Definition chainr1 {A : Type} (arg : Parser A) (op : Parser (A -> A -> A))
  : Parser A :=
    fun input : string => chainr1_aux arg op (String.length input) input.

Definition parseNat_chainr : Parser nat :=
  let op m n := m + 10 * n in
    chainr1 (fmap (fun d => nat_of_ascii d - nat_of_ascii "0") digit) (ret op).

Compute parseNat_chainr "211"%string.

Fixpoint exprn'' (n : nat) : Parser Z :=
match n with
    | 0 => result 0%Z
    | S n' =>
        let
          op := do (char "+";; ret Z.add) |:
                do (char "-";; ret Z.sub)
        in let
          factor := parseZ |: bracket (char "(") (exprn'' n') (char ")")
        in
          chainl1 factor op
end.

Definition expr'' : Parser Z :=
  fun input : string => exprn'' (String.length input) input.

Compute expr'' "3-2"%string.

Definition ops
  {A B : Type} (start : Parser A * B) (l : list (Parser A * B)) : Parser B :=
match l with
    | [] => let '(p, op) := start in p >> ret op
    | h :: t =>
        let '(p, op) := start in
          fold_right plus (p >> ret op)
            (map (fun '(p, op) => p >> ret op) l)
end.

Fixpoint exprn3 (n : nat) : Parser Z :=
match n with
    | 0 => result 0%Z
    | S n' =>
        let
          op := ops (char "+", Z.add) [(char "-", Z.sub)]
        in let
          factor := parseZ |: bracket (char "(") (exprn3 n') (char ")")
        in
          chainl1 factor op
end.

Definition expr3 : Parser Z :=
  fun input : string => exprn3 (String.length input) input.

Compute expr'' "1-(2-(3-4)-5)"%string.

(* TODO: chainl1 alternative *)

Fixpoint exprn4 (n : nat) : Parser Z :=
match n with
    | 0 => zero
    | S n' =>
        let
          addop := ops (char "+", Z.add) [(char "-", Z.sub)]
        in let
          expop := ops (char "^", Z.pow) []
        in let
          factor := parseZ |: bracket (char "(") (exprn4 n') (char ")")
        in let
          term := chainr1 factor expop
        in
          chainl1 term addop
end.

Definition expr4 : Parser Z :=
  fun input : string => exprn4 (String.length input) input.

Compute expr4 "(1-2)^3"%string.

Definition chainl {A : Type} (p : Parser A) (op : Parser (A -> A -> A))
  (default : A) : Parser A :=
    chainl1 p op |: ret default.

Definition chainr {A : Type} (p : Parser A) (op : Parser (A -> A -> A))
  (default : A) : Parser A :=
    (chainr1 p op) |: ret default.

(** ** 5 Efficiency of parsers *)

(** *** 5.1 Left factorising *)

(** *** 5.2 Improving laziness *)

Definition force {A : Type} (p : Parser A) : Parser A :=
  fun input : string =>
match p input with
    | [] => []
    | h :: t => (fst h, snd h) :: t
end.

Theorem force_makes_no_sense_in_Coq :
  forall (A : Type) (p : Parser A), force p = p.
Proof.
  intros. unfold force. extensionality input.
  destruct (p input) as [| [h1 h2] t]; cbn; reflexivity.
Qed.

(** *** 5.3 Limiting the number of results *)

Definition number : Parser nat :=
  parseNat |: ret 0.

Definition first {A : Type} (p : Parser A) : Parser A :=
  fun input : string =>
match p input with
    | [] => []
    | h :: _ => [h]
end.

Compute number "123"%string.
Compute first number "123"%string.

Compute number "hello"%string.
Compute first number "hello"%string.

Definition plus_det {A : Type} (p q : Parser A) : Parser A :=
  first (plus p q).

Notation "p +++ q" := (plus_det p q) (at level 42).

Theorem plus_det_spec :
  forall (A : Type) (p q : Parser A),
    p |: q = (fun _ => []) \/
    (exists x : A * string, p |: q = fun _ => [x]) ->
      p +++ q = p |: q.
Proof.
  intros. extensionality input. unfold plus_det, first.
  destruct H as [H | [x H]]; rewrite H; reflexivity.
Qed.

(** ** 6 Handling lexical issues *)

(** *** 6.1 White-space, comments, and keywords *)

Definition isSpace (c : ascii) : bool :=
  leb (nat_of_ascii c) 32.

Definition spaces : Parser unit :=
  many1 (sat isSpace) >> ret tt.

Definition comment : Parser unit :=
  first
    (str "--" >> many (sat (fun c => negb (ascii_eqb c "013"))) >> ret tt).

Compute comment "-- haskellowy komentarz polityczny"%string.

Definition junk : Parser unit :=
  many (spaces +++ comment) >> ret tt.

Definition parse {A : Type} (p : Parser A) : Parser A :=
  junk >> p.

Definition token {A : Type} (p : Parser A) : Parser A :=
  do
    x <- p;
    junk;;
    ret x.

Definition natural : Parser nat :=
  token parseNat.

Definition integer : Parser Z :=
  token parseZ.

Definition symbol (s : string) : Parser string :=
  token (str s).

Definition in_decb {A : Type} (eq_dec : forall x y : A, {x = y} + {x <> y})
  (x : A) (l : list A) : bool :=
    if in_dec eq_dec x l then true else false.

Definition identifier (keywords : list string) : Parser string :=
  do
    id <- token ident;
    if in_decb string_dec id keywords then zero else ret id.

Compute natural "123"%string.

(* My own stuff *)

(*Definition nonzeroDigit : Parser ascii :=
  sat (fun c : ascii => leb 49 (nat_of_ascii c) && leb (nat_of_ascii c) 58).

Definition parsePositive : Parser positive :=
  parseNat >>= fun n =>
  match n with
      | 0 => zero
      | S n' => ret $ Pos.of_nat n
  end.

Require Import QArith.

Definition parseQ : Parser Q := do
  a <- parseZ;
  char "/";;
  b <- parsePositive;
  ret (a # b).

Compute parseQ "1/5"%string.*)

(** *** 6.2 A parser for λ-expressions *)

Inductive Expr : Type :=
    | App : Expr -> Expr -> Expr
    | Lam : string -> Expr -> Expr
    | Let : string -> Expr -> Expr -> Expr
    | Var : string -> Expr.

(* Lambda calculus parser for Coq-like syntax. *)
Fixpoint parseExprn (n : nat) : Parser Expr :=
match n with
    | 0 => zero
    | S n' =>
        let
          id := identifier ["let"; "fun"; "in"]%string
        in let
          app := do
            token $ char "(";;
            e1 <- parseExprn n';
            e2 <- parseExprn n';
            token $ char ")";;
            ret $ App e1 e2
        in let
          lam := do
            token $ str "fun";;
            var <- id;
            token $ str "=>";;
            body <- parseExprn n';
            ret $ Lam var body
        in let
          parseLet := do
            token $ str "let";;
            var <- id;
            token $ str ":=";;
            body <- parseExprn n';
            token $ str "in";;
            let_body <- parseExprn n';
            ret $ Let var body let_body
        in let
          var := fmap Var id
        in
          app +++ lam +++ parseLet +++ var
end.

Definition parseExpr : Parser Expr :=
  fun input : string => parseExprn (String.length input) input.

Compute parseExpr
  "(x x)"%string.

Compute parseExpr
  "fun f => fun x => (f x)"%string.

Compute parseExpr
  "let x := (x x) in x"%string.

(** Parser for lambda calculus with Haskell-like syntax taken directly
    from the paper. *)
Fixpoint parseExprn' (n : nat) : Parser Expr :=
match n with
    | 0 => zero
    | S n' =>
        let
          variable := identifier ["let"; "in"]%string
        in let
          paren := bracket (char "(") (parseExprn' n') (char ")")
        in let
          var := fmap Var variable
        in let
          local := do
            symbol "let";;
            x <- variable;
            symbol "=";;
            e <- parseExprn' n';
            symbol "in";;
            e' <- parseExprn' n';
            ret $ Let x e e'
        in let
          lam := do
            symbol "\";;
            x <- variable;
            symbol "->";;
            e <- parseExprn' n';
            ret $ Lam x e
        in let
          atom := token (lam +++ local +++ var +++ paren)
        in
          chainl1 atom (ret App)
end.

Definition parseExpr' : Parser Expr :=
  fun input : string => parseExprn' (String.length input) input.

Compute parseExpr'
  "(x x)"%string.

Compute parseExpr'
  "\f -> \x -> (f x)"%string.

Compute parseExpr'
  "let x = (x x) in x"%string.

(** ** 7 Factorising the parser monad *)