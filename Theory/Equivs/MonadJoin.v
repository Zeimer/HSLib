Require Import HSLib.Base.
Require Export Control.Functor.
Require Export Control.Applicative.

Class Monad (M : Type -> Type) : Type :=
{
    is_applicative :> Applicative M;
    join : forall {A : Type}, M (M A) -> M A;
    join_fmap_join :
      forall (A : Type) (x : M (M (M A))),
        join (fmap join x) = join (join x);
    join_pure :
      forall (A : Type) (ma : M A), join (pure ma) = ma;
    join_fmap_pure :
      forall (A : Type) (x : M A),
        join (fmap pure x) = x;
    join_fmap_fmap :
      forall (A B : Type) (f : A -> B) (x : M (M A)),
        join (fmap (fmap f) x) = fmap f (join x);
    join_ap :
      forall (A B : Type) (mf : M (A -> B)) (ma : M A),
        mf <*> ma =
        join (pure (fun f : A -> B => join (fmap (f .> pure) ma)) <*> mf)
}.

Coercion is_applicative : Monad >-> Applicative.

Hint Rewrite @join_fmap_join @join_pure @join_fmap_pure @join_fmap_fmap
  @join_ap : join.

Definition bind
  {M : Type -> Type} {inst : Monad M} {A B : Type} (ma : M A) (f : A -> M B)
    : M B := (fmap f .> join) ma.

Definition compM
  {A B C : Type} {M : Type -> Type} {inst : Monad M}
  (f : A -> M B) (g : B -> M C) : A -> M C :=
    f .> fmap g .> join.

Module MonadNotations.

Notation "mx >>= f" := (bind mx f) (at level 40).
Notation "f >=> g" := (compM f g) (at level 40).

Notation "x '<-' e1 ; e2" := (bind e1 (fun x => e2))
  (right associativity, at level 42, only parsing).

Notation "e1 ;; e2" := (constrA e1 e2)
  (right associativity, at level 42, only parsing).

Notation "'do' e" := e (at level 50, only parsing).

End MonadNotations.

Export MonadNotations.

Section MonadicFuns.

Variable M : Type -> Type.
Variable inst : Monad M.
Variables A B C D E F : Type.

Fixpoint foldM (f : A -> B -> M A) (dflt : A) (l : list B)
    : M A :=
match l with
    | [] => pure dflt
    | h :: t => f dflt h >>= fun a : A => foldM f a t
end.

End MonadicFuns.

Arguments foldM {M inst A B} _ _ _.

Section DerivedLaws.

Variables
  (M : Type -> Type)
  (inst : Monad M).

Lemma bind_pure_l :
  forall (A B : Type) (f : A -> M B) (a : A),
    bind (pure a) f = f a.
Proof.
  unfold bind, compose; intros.
  rewrite fmap_pure, join_pure. reflexivity.
Qed.

Lemma bind_pure_r :
  forall (A : Type) (ma : M A),
    bind ma pure = ma.
Proof.
  unfold bind, compose; intros.
  rewrite join_fmap_pure. reflexivity.
Qed.

Lemma assoc :
  forall (A B C : Type) (ma : M A) (f : A -> M B) (g : B -> M C),
    bind (bind ma f) g = bind ma (fun x => bind (f x) g).
Proof.
  unfold bind, compose; intros.
  rewrite <- !join_fmap_fmap.
  change (fun x : A => join (fmap g (f x))) with (f .> fmap g .> join).
  rewrite !fmap_comp. unfold compose. rewrite join_fmap_join.
  reflexivity.
Qed.

Lemma bind_fmap :
  forall (A B C : Type) (f : A -> B) (x : M A) (g : B -> M C),
    bind (fmap f x) g = bind x (f .> g).
Proof.
  unfold bind, compose, id; intros. f_equal.
  rewrite <- fmap_comp'. unfold compose.
  reflexivity.
Qed.

Lemma fmap_bind :
  forall (A B C : Type) (x : M A) (f : A -> M B) (g : B -> C),
    fmap g (bind x f) = bind x (fun x0 : A => fmap g (f x0)).
Proof.
  intros. change (fun x0 : A => fmap g (f x0)) with (f .> fmap g).
  rewrite <- bind_fmap. unfold bind, compose; intros.
  rewrite join_fmap_fmap. reflexivity.
Qed.

Lemma fmap_bind_pure :
  forall (A B : Type) (f : A -> B) (x : M A),
    fmap f x = bind x (fun a : A => pure (f a)).
Proof.
  intros. replace (fun _ => _) with (f .> pure) by functor.
  unfold bind. rewrite fmap_comp. unfold compose.
  rewrite join_fmap_pure. reflexivity.
Qed.

Lemma bind_ap :
  forall (A B : Type) (mf : M (A -> B)) (mx : M A),
    mf <*> mx = bind mf (fun f => bind mx (fun x => pure (f x))).
Proof.
  intros. unfold bind, compose. rewrite join_ap.
  autorewrite with HSLib.
  unfold compose. reflexivity.
Qed.

End DerivedLaws.