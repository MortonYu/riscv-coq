Require Import Coq.Lists.List. Import ListNotations.
Require Import Coq.Arith.PeanoNat.


Class Monad(M: Type -> Type) := mkMonad {
  Bind: forall {A B}, M A -> (A -> M B) -> M B;
  Return: forall {A}, A -> M A;
}.

Notation "x <- m1 ; m2" := (Bind m1 (fun x => m2))
  (right associativity, at level 60) : monad_scope.
Notation "m1 ;; m2" := (Bind m1 (fun _ => m2))
  (right associativity, at level 60) : monad_scope.

Open Scope monad_scope.


Definition Id: Type -> Type := id.

Instance Id_monad: Monad Id := {|
  Bind{A B}(m: A)(f: A -> B) := f m;
  Return{A}(a: A) := a;
|}.


Record optionT(M: Type -> Type)(A: Type): Type := mkOptionT {
  runOptionT: M (option A)
}.
Arguments mkOptionT {M} {A} (_).
Arguments runOptionT {M} {A} (_).

Instance OptionT_Monad(M: Type -> Type){MM: Monad M}: Monad (optionT M) := {|
  Bind{A}{B}(m: optionT M A)(f: A -> optionT M B) :=
    mkOptionT (Bind (runOptionT m) (fun (o: option A) =>
                                      match o with
                                      | Some a => runOptionT (f a)
                                      | None => Return None
                                      end));
  Return{A}(a: A) := mkOptionT (Return (Some a));
|}.

Definition lift_into_optionT{M: Type -> Type}{MM: Monad M}{A: Type}(m: M A): optionT M A :=
  mkOptionT (Bind m (fun a => Return (Some a))).

Definition fail{A: Type}{M: Type -> Type}{MM: Monad M}: optionT M A :=
  mkOptionT (Return None).


Definition State(S A: Type) := S -> (A * S).

Record StateT(S: Type)(M: Type -> Type)(A: Type): Type := mkStateT {
  runStateT: S -> M (A * S)%type
}.
Arguments mkStateT {S} {M} {A} (_).
Arguments runStateT {S} {M} {A} (_).

Instance StateT_Monad(M: Type -> Type){MM: Monad M}(S: Type): Monad (StateT S M) := {|
  Bind{A B: Type}(m: StateT S M A)(f: A -> StateT S M B) :=
    mkStateT (fun (s: S) => Bind ((runStateT m) s) (fun '(a, s) => runStateT (f a) s));
  Return{A: Type}(a: A) :=
    mkStateT (fun (s: S) => Return (a, s));
|}.

Definition lift_into_StateT{S: Type}{M: Type -> Type}{MM: Monad M}{A: Type}(m: M A): StateT S M A :=
  mkStateT (fun s => Bind m (fun a => Return (a, s))).

Definition get{S: Type}{M: Type -> Type}{MM: Monad M}: StateT S M S :=
  mkStateT (fun (s: S) => Return (s, s)).

Definition put{S: Type}{M: Type -> Type}{MM: Monad M}(s: S): StateT S M unit :=
  mkStateT (fun _ => Return (tt, s)).


Record listT(M: Type -> Type)(A: Type): Type := mkListT {
  runListT: M (list A)
}.
Arguments mkListT {M} {A} (_).
Arguments runListT {M} {A} (_).

Instance listT_Monad(M: Type -> Type){MM: Monad M}: Monad (listT M) := {|
  Bind{A B: Type}(m: listT M A)(f: A -> listT M B) :=
    mkListT (la <- runListT m;
             List.fold_left
               (fun res a =>
                  res' <- res;
                  a' <- runListT (f a);
                  Return (res' ++ a'))
               la
               (Return (@nil B)));
  Return{A: Type}(a: A) :=
    mkListT (Return (cons a nil));
|}.


Definition lift_into_listT{M: Type -> Type}{MM: Monad M}{A: Type}(m: M A): listT M A :=
  mkListT (Bind m (fun a => (Return (cons a nil)))).

Definition pick{A: Type}{M: Type -> Type}{MM: Monad M}(options: list A): listT M A :=
  mkListT (Return options).

Definition comp1: listT Id (nat * bool) :=
  x1 <- pick [3; 4];
  x2 <- pick [true; false];
  Return (x1, x2).

Compute (runListT comp1).

Definition comp2: (listT (optionT Id)) nat :=
  b <- pick [true; false];
  if (b: bool) then
    pick [3; 4]
  else
    lift_into_listT fail.

Compute (runOptionT (runListT comp2)).

Definition comp3: (optionT (listT Id)) nat :=
  b <- lift_into_optionT (pick [true; false]);
  if (b: bool) then
    lift_into_optionT (pick [3; 4])
  else
    fail.

Compute (runListT (runOptionT comp3)).

Definition comp4: StateT nat Id unit :=
  x <- get;
  put (x + 1).

Compute (runStateT comp4 4).


Definition comp5: StateT nat (listT Id) unit :=
  x <- get;
  y <- lift_into_StateT (pick [2; 3]);
  put (x + y).

Compute (runListT (runStateT comp5 4)).

Compute (seq 0 4).

Definition comp6: StateT nat (listT Id) unit :=
  x <- get;
  y <- lift_into_StateT (pick (seq 0 x));
  put y.

Compute (runListT (runStateT comp6 4)).


Definition comp7: StateT nat (listT Id) unit :=
  x <- get;
  y <- lift_into_StateT (pick (seq 0 x));
  if Nat.eq_dec y 2 then
    put 22
  else
    put 11.

(* Why is composition of transformers dangerous? Here is a broken example *)

Definition comp7': (listT (StateT (nat * nat)  Id) (nat * nat)) :=
  y <- pick (seq 0 2);
    (if Nat.eq_dec y 0 then
       ( thepair <- lift_into_listT get;
                 lift_into_listT (put (0, snd thepair));;
                 lift_into_listT get
       )
     else
       ( thepair <- lift_into_listT get;
           lift_into_listT (put (fst thepair, 0 ));;
                        lift_into_listT get))
.

Compute (runStateT (runListT comp7') (1,1)). (* 0,0 is an invalid state, reached here *)


Definition comp8: (listT (StateT nat Id) nat) :=
  x <- lift_into_listT get;
  y <- pick (seq 0 x);
  lift_into_listT (put y);;
  lift_into_listT get.

Compute (runStateT (runListT comp8) 4).


Definition comp9: (listT (StateT nat Id) nat) :=
  x <- lift_into_listT get;
  y <- pick (seq 0 x);
  lift_into_listT (put y);;
  (if Nat.eq_dec y 2 then
    (c <- lift_into_listT get;
     lift_into_listT (put (c * 3)))
  else
    (c <- lift_into_listT get;
     lift_into_listT (put (c * 5))));;
  lift_into_listT get.

Compute (runStateT (runListT comp9) 4).

Record Regs := mkRegs {
  reg1: nat;
  reg2: nat;
  reg3: nat;
}.

Notation "<< x1 , x2 , x3 >>" := (mkRegs x1 x2 x3) (format "<< x1 , x2 , x3 >>").

Inductive Reg := r1 | r2 | r3.

Definition getReg(r: Reg): StateT Regs Id nat :=
  s <- get;
  Return (match r with
          | r1 => s.(reg1)
          | r2 => s.(reg2)
          | r3 => s.(reg3)
          end).

Definition setReg(r: Reg)(v: nat): StateT Regs Id unit :=
  s <- get;
  put (match r with
       | r1 => mkRegs v        s.(reg2) s.(reg3)
       | r2 => mkRegs s.(reg1) v        s.(reg3)
       | r3 => mkRegs s.(reg1) s.(reg2) v
       end).

Definition assign(ra rb: Reg): StateT Regs Id unit :=
  x <- getReg rb;
  setReg ra x.

Definition swap12: StateT Regs Id unit :=
  assign r3 r1;;
  assign r1 r2;;
  assign r2 r3.

Compute (runStateT swap12 (mkRegs 10 20 30)).

Definition test1: listT (StateT Regs Id) Regs :=
  x <- lift_into_listT (getReg r1);
  y <- pick (seq 0 x);
  lift_into_listT (setReg r1 y);;
  lift_into_listT get.

(* returns a list of all final states as "answer"
   and one implementation-chosen final state as "state" *)
Compute (runStateT (runListT test1) (mkRegs 3 20 30)).

Definition test2: listT (StateT Regs Id) Regs :=
  lift_into_listT swap12;; test1.

Compute (runStateT (runListT test2) (mkRegs 11 4 33)).