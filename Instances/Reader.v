Add Rec LoadPath "/home/Zeimer/Code/Coq".

Require Import HSLib.Base.
Require Import HSLib.Functor.Functor.
Require Import HSLib.Applicative.Applicative.

Definition Reader (R A : Type) : Type := R -> A.

Definition fmap_Reader
  {R A B : Type} (f : A -> B) (ra : Reader R A) : Reader R B :=
    fun r : R => f (ra r).

Instance FunctorReader (R : Type) : Functor (Reader R) :=
{
    fmap := @fmap_Reader R
}.
Proof. all: reflexivity. Defined.

Definition ret_Reader
  {R A : Type} (a : A) : Reader R A :=
    fun _ : R => a.

Definition ap_Reader
  {R A B : Type} (f : Reader R (A -> B)) (ra : Reader R A) : Reader R B :=
    fun r : R => f r (ra r).

Instance ApplicativeReader (R : Type) : Applicative (Reader R) :=
{
    is_functor := FunctorReader R;
    ret := @ret_Reader R;
    ap := @ap_Reader R
}.
Proof. all: reflexivity. Defined.

Instance CommutativeApplicative_Reader (R : Type) :
  CommutativeApplicative _ (ApplicativeReader R) := {}.
Proof. reflexivity. Qed.

Definition join_Reader
  {R A : Type} (rra : Reader R (Reader R A)) : Reader R A :=
    fun r : R => rra r r.

Definition bind_Reader
  {R A B : Type} (ra : Reader R A) (f : A -> Reader R B) : Reader R B :=
    fun r : R => f (ra r) r.

Definition compM_Reader
  {R A B C : Type} (f : A -> Reader R B) (g : B -> Reader R C) (x : A)
    : Reader R C := fun r : R => g (f x r) r.