Add Rec LoadPath "/home/Zeimer/Code/Coq".

Require Export HSLib.Control.Monad.

Class MonadTrans (T : (Type -> Type) -> Type -> Type) : Type :=
{
    is_monad : forall (M : Type -> Type), Monad M -> Monad (T M);
    lift : forall {M : Type -> Type} {_inst : Monad M} {A : Type},
      M A -> T M A;
    lift_ret :
      forall (M : Type -> Type) {_inst : Monad M} (A : Type) (x : A),
        lift (ret x) = ret x;
    lift_bind :
      forall {M : Type -> Type} {_inst : Monad M} (A B : Type) (x : M A)
        (f : A -> M B), lift (x >>= f) = lift x >>= (f .> lift)
}.

(* Tactic for dealing with functor instances specific to monad
   transformers. *)
Ltac mtrans := intros; try
match goal with
    | |- fmap (fun x : ?A => ?e) = _ =>
          let x := fresh "x" in
          replace (fun x : A => e) with (@id A);
          [rewrite fmap_pres_id | ext x; induction x]; try reflexivity
    | |- context [fmap ?f = fmap ?g .> fmap ?h] =>
          let x := fresh "x" in
          replace f with (g .> h);
          [rewrite fmap_pres_comp | ext x; induction x]; try reflexivity
end.