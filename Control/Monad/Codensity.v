Require Import Control.

Definition Codensity
  (F : Type -> Type) (A : Type) : Type :=
    forall {R : Type}, (A -> F R) -> F R.

Definition fmap_Codensity
  (F : Type -> Type) {A B : Type} (f : A -> B) (x : Codensity F A)
    : Codensity F B := fun (R : Type) (y : B -> F R) =>
      x R (fun a : A => y (f a)).

Instance FunctorCodensity
  (F : Type -> Type) : Functor (Codensity F) :=
{
    fmap := @fmap_Codensity F
}.
Proof. all: reflexivity. Defined.

Definition pure_Codensity
  (F : Type -> Type) {A : Type} (a : A) : Codensity F A :=
    fun (R : Type) (f : A -> F R) => f a.

Definition ap_Codensity
  (F : Type -> Type) {A B : Type} (f : Codensity F (A -> B))
  (x : Codensity F A) : Codensity F B :=
    fun (R : Type) (y : B -> F R) =>
      f R (fun h : A -> B => x R (fun a : A => y (h a))).

Instance Applicative_Codensity
  (F : Type -> Type) : Applicative (Codensity F) :=
{
    is_functor := FunctorCodensity F;
    pure := @pure_Codensity F;
    ap := @ap_Codensity F;
}.
Proof. all: reflexivity. Defined.

Definition bind_Codensity
  (F : Type -> Type) {A B : Type} (ca : Codensity F A) (f : A -> Codensity F B)
    : Codensity F B := fun (R : Type) (g : B -> F R) =>
      ca R (fun x : A => f x R g).

Theorem Codensity_not_Alternative :
  (forall F : Type -> Type, Alternative (Codensity F)) -> False.
Proof.
  intro H. destruct (H id). unfold Codensity in *.
  apply (aempty False). intro. assumption.
Qed.

Instance MonadCodensity
  (F : Type -> Type) : Monad (Codensity F) :=
{
    is_applicative := @Applicative_Codensity F;
    bind := @bind_Codensity F;
}.
Proof. all: reflexivity. Defined.

Lemma id_to_homotopy :
  forall (A : Type) (P : forall x : A, Type) (f g : forall x : A, P x),
    f = g -> forall x : A, f x = g x.
Proof.
  intros. rewrite H. reflexivity.
Qed.

Require Import Control.Monad.Identity.

Theorem Codensity_not_CommutativeApplicative :
  (forall F : Type -> Type,
    CommutativeApplicative _ (Applicative_Codensity F)) -> False.
Proof.
  intros.
  specialize (H list).
  destruct H. cbn in *. compute in *.
  specialize (ap_comm bool bool bool (fun a b => andb a b)). cbn in *.
  specialize (ap_comm (fun R f => f false ++ f true)
                      (fun _ f => f true ++ f false)).
  cbn in *.
  apply (f_equal (fun f => f bool)) in ap_comm.
  apply (f_equal (fun f => f (fun b => [b]))) in ap_comm.
  cbn in ap_comm. inv ap_comm.
Qed.

Definition callCC_Type : Type :=
  forall (F : Type -> Type) (A B : Type),
    ((A -> Codensity F B) -> Codensity F A) -> Codensity F A.

(*
Require Import Control.Monad.Identity.

Theorem no_callCC :
  callCC_Type -> False.
Proof.
  unfold callCC_Type, Codensity. intro.
  specialize (X Identity). unfold Identity in X.
  apply (X unit unit).
    firstorder.
    intros.
Restart.
  unfold callCC_Type, Codensity. intro.
  specialize (X option False False ltac:(firstorder)).
Restart.
  unfold callCC_Type, Codensity. intro.
  specialize (X (Writer Monoid_unit) unit False ltac:(firstorder)).
  specialize (X False). unfold Writer in X.
Restart.
  unfold callCC_Type, Codensity. intro.
  specialize (X list False False).
Restart.
  unfold callCC_Type, Codensity. intro.
  specialize (X Identity). unfold Identity in X.
  eapply (X False False).
    2: auto.
    intros _ R _. eapply (X (R + (R -> False))%type True).
      firstorder. admit.
      destruct 1.
        assumption.
        eapply (X (R + ((R -> False) -> False))%type True).

Abort.
*)

Section CodensityFuns.

Variable M : Type -> Type.
Variable inst : Monad M.

Definition inject
  {A : Type} (x : M A) : Codensity M A :=
    fun _ c => x >>= c.

Definition extract
  {A : Type} (x : Codensity M A) : M A := x _ pure.

Definition improve
  {A : Type} (x : M A) : M A :=
    extract (inject x).

Hint Unfold
  Codensity fmap_Codensity pure_Codensity ap_Codensity bind_Codensity
  inject extract : HSLib.

Lemma extract_pure :
  forall (A : Type) (x : A),
    extract (pure x) = pure x.
Proof. monad. Qed.

Lemma extract_pure' :
  forall (A : Type) (x : M A),
    extract (fun _ c => x >>= c) = x.
Proof. monad. Qed.

Lemma extract_inject :
  forall (A : Type) (x : M A),
    extract (inject x) = x.
Proof. monad. Qed.

Lemma improve_spec :
  forall (A : Type) (x : M A),
    improve x = x.
Proof. apply extract_inject. Qed.

Lemma inject_extract :
  forall (A : Type) (x : Codensity M A),
    inject (extract x) = x.
Proof.
  intros. unfold inject, extract. ext2 R c.
  unfold Codensity in *.
  
Abort.

End CodensityFuns.

Arguments improve {M inst A } _.

Require Import Control.Monad.Class.MonadFree.

Print MonadFree.

Definition wrap_Codensity
  {F M : Type -> Type} {instF : Functor F} {instM : Monad M}
  {instMF : MonadFree F M instF instM} {A : Type}
  (x : F (Codensity M A)) : Codensity M A :=
    fun R g => wrap (fmap (fun f => f R g) x).

Hint Unfold
  Codensity fmap_Codensity pure_Codensity ap_Codensity bind_Codensity
  wrap_Codensity : HSLib.

Instance MonadFree_Codensity
  {F M : Type -> Type} {instF : Functor F} {instM : Monad M}
  {instMF : MonadFree F M instF instM}
  : MonadFree F (Codensity M) instF (MonadCodensity M) :=
{
    wrap := @wrap_Codensity F M instF instM instMF
}.
Proof.
  monad. rewrite <- !fmap_comp'. unfold compose. reflexivity.
Defined.