Add Rec LoadPath "/home/zeimer/Code/Coq".

Require Import HSLib.Base.
Require Export HSLib.Functor.Functor.
Require Export HSLib.Applicative.Applicative.
Require Import HSLib.Alternative.Alternative.
Require Import HSLib.MonadBind.Monad.
Require Import HSLib.MonadPlus.MonadPlus.

(* Rose Trees *)
Inductive RT (A : Type) : Type :=
    | Leaf : A -> RT A
    | Node : RT A -> RT A -> RT A.

Arguments Leaf [A] _.
Arguments Node [A] _ _.

Fixpoint fmap_RT {A B : Type} (f : A -> B) (t : RT A) : RT B :=
match t with
    | Leaf x => Leaf (f x)
    | Node l r => Node (fmap_RT f l) (fmap_RT f r)
end.

Instance Functor_RT : Functor RT :=
{
    fmap := @fmap_RT
}.
Proof.
  all: intros; ext t;
  induction t as [x | l IHl r IHr]; cbn; rewrite ?IHl, ?IHr; reflexivity.
Defined.

Definition ret_RT {A : Type} (x : A) : RT A := Leaf x.

Fixpoint ap_RT {A B : Type} (tf : RT (A -> B)) (ta : RT A) : RT B :=
match tf with
    | Leaf f => fmap f ta
    | Node l r => Node (ap_RT l ta) (ap_RT r ta)
end.

Instance Applicative_RT : Applicative RT :=
{
    ret := @ret_RT;
    ap := @ap_RT;
}.
Proof.
  all: cbn; intros.
    cbn. rewrite (@fmap_pres_id _ Functor_RT). reflexivity.
    induction ag as [g | gl IHgl gr IHgr]; cbn.
      induction af as [f | fl IHfl fr IHfr]; cbn.
        rewrite (@fmap_pres_comp' _ Functor_RT). reflexivity.
        rewrite IHfl, IHfr. reflexivity.
      rewrite IHgl, IHgr. reflexivity.
    reflexivity.
    induction f as [f | l IHl r IHr]; cbn; rewrite ?IHl, ?IHr; reflexivity.
    reflexivity.
Defined.

Theorem RT_not_Alternative :
  Alternative RT -> False.
Proof.
  destruct 1. induction (aempty False); contradiction.
Qed.

Fixpoint bind_RT {A B : Type} (ta : RT A) (tf : A -> RT B) : RT B :=
match ta with
    | Leaf x => tf x
    | Node l r => Node (bind_RT l tf) (bind_RT r tf)
end.

Instance Monad_RT : Monad RT :=
{
    bind := @bind_RT
}.
Proof.
  all: cbn; intros.
    reflexivity.
    induction ma as [a | l IHl r IHr]; cbn; rewrite ?IHl, ?IHr; reflexivity.
    induction ma as [a | l IHl r IHr]; cbn; rewrite ?IHl, ?IHr; reflexivity.
    induction x as [a | l IHl r IHr]; cbn; rewrite ?IHl, ?IHr; reflexivity.
    induction mf as [f | fl IHfl fr IHfr]; cbn.
      induction mx as [x | xl IHxl xr IHxr]; cbn.
        reflexivity.
        rewrite IHxl, IHxr. reflexivity.
      rewrite IHfl, IHfr. reflexivity.
Defined.

Theorem RT_not_MonadPlus :
  MonadPlus RT -> False.
Proof.
  destruct 1. apply RT_not_Alternative. assumption.
Qed.