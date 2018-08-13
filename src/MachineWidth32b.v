Require Import Coq.ZArith.ZArith.
Require Import Coq.micromega.Lia.
Require Import Coq.Logic.ProofIrrelevance.
Require Import riscv.Utility.
Require Import riscv.util.div_mod_to_quot_rem.
Local Open Scope Z_scope.


Ltac make_mod_nonzero :=
  let C := fresh in
  match goal with
  | |- ?a mod ?m = ?b mod ?m =>
    assert (m = 0 \/ m <> 0) as C by omega;
    destruct C as [C | C];
    [ rewrite C in *; do 2 rewrite Zmod_0_r; reflexivity | ]
  end.

Lemma mod_eq_from_diff: forall a b m,
    (a - b) mod m = 0 ->
    a mod m = b mod m.
Proof.
  intros.
  make_mod_nonzero.
  apply Z.mod_divide in H; [|assumption].
  unfold Z.divide in H. destruct H as [k E].
  replace a with (b + k * m) by omega.
  apply Z_mod_plus_full.
Qed.

Lemma add_mod_0: forall a b m : Z,
    a mod m = 0 ->
    b mod m = 0 ->
    (a + b) mod m = 0.
Proof.
  intros *. intros E1 E2.
  rewrite Zplus_mod.
  rewrite E1. rewrite E2.
  reflexivity.
Qed.

Lemma sub_mod_0: forall a b m : Z,
    a mod m = 0 ->
    b mod m = 0 ->
    (a - b) mod m = 0.
Proof.
  intros *. intros E1 E2.
  rewrite Zminus_mod.
  rewrite E1. rewrite E2.
  reflexivity.
Qed.

Lemma Z_mod_mult': forall a b : Z,
    (a * b) mod a = 0.
Proof.
  intros. rewrite Z.mul_comm. apply Z_mod_mult.
Qed.

Ltac prove_mod_0 :=
  match goal with
  | |- ?a mod ?m = 0 => ring_simplify a
  end;
  rewrite? Zplus_mod_idemp_l;
  rewrite? Zplus_mod_idemp_r;
  rewrite? Zminus_mod_idemp_l;
  rewrite? Zminus_mod_idemp_r;
  rewrite? Zmult_mod_idemp_l;
  rewrite? Zmult_mod_idemp_r;
  match goal with
  | |- ?a mod ?m = 0 => ring_simplify a
  end;
  rewrite? Z.pow_2_r;
  first
    (* base cases: *)
    [ apply Z_mod_mult
    | apply Z_mod_mult'
    | apply Z_mod_same_full
    | apply Zmod_0_l
    (* cases with recursion (the last two might turn a true goal into a false one): *)
    | apply Z_mod_zero_opp_full
    | apply add_mod_0
    | apply sub_mod_0
 (* | match goal with
      | |- ?G => fail 1000 "failed to solve" G
      end *)
    ];
  [> prove_mod_0 .. ].


Definition word(sz: Z) := { x: Z | x mod 2 ^ sz = x }.

Definition ZToWord(sz: Z)(x: Z): word sz := 
  exist _ (x mod 2 ^ sz) (Zmod_mod x (2 ^ sz)).

Definition uwordToZ{sz: Z}: word sz -> Z := @proj1_sig Z (fun x => x mod 2 ^ sz = x).

Definition wmsb{sz: Z}(a: word sz): bool := Z.testbit (uwordToZ a) (sz - 1).

Definition swordToZ{sz: Z}(a: word sz): Z :=
  if wmsb a then uwordToZ a - 2 ^ sz else uwordToZ a.

Definition wu_unop(f: Z -> Z)(sz: Z)(a: word sz): word sz :=
  ZToWord sz (f (uwordToZ a)).

Definition wu_binop(f: Z -> Z -> Z)(sz: Z)(a b: word sz): word sz :=
  ZToWord sz (f (uwordToZ a) (uwordToZ b)).

Definition wu_binop_t{T: Type}(f: Z -> Z -> T)(sz: Z)(a b: word sz): T :=
  f (uwordToZ a) (uwordToZ b).

Definition ws_unop(f: Z -> Z)(sz: Z)(a: word sz): word sz :=
  ZToWord sz (f (swordToZ a)).

Definition ws_binop(f: Z -> Z -> Z)(sz: Z)(a b: word sz): word sz :=
  ZToWord sz (f (swordToZ a) (swordToZ b)).

Definition ws_binop_t{T: Type}(f: Z -> Z -> T)(sz: Z)(a b: word sz): T :=
  f (swordToZ a) (swordToZ b).

Hint Unfold ZToWord uwordToZ wmsb swordToZ
            wu_unop wu_binop wu_binop_t
            ws_unop ws_binop ws_binop_t
            proj1_sig
: unf_word_all.


Section ArithOps.

  Context {sz: Z}.

  Definition wopp := ws_unop Z.opp sz.

  Definition wadd := wu_binop Z.add sz.
  Definition wsub := wu_binop Z.sub sz.
  Definition wmul := wu_binop Z.mul sz.

  Definition wsadd := ws_binop Z.add sz.
  Definition wssub := ws_binop Z.sub sz.
  Definition wsmul := ws_binop Z.mul sz.

End ArithOps.

Hint Unfold wopp wadd wsub wmul wsadd wssub wsmul : unf_word_all.

Ltac word_destruct :=
  intuition idtac;
  repeat autounfold with unf_word_all in *;
  repeat match goal with
         | w: word _ |- _ => let H := fresh "M" w in destruct w as [w H]
         end;
  repeat match goal with
         | H: (?x =? ?y) = true |- _ =>
           apply Z.eqb_eq in H; try subst x; try subst y
         | H: exist _ ?x _ = exist _ ?y _ |- _ =>
           apply EqdepFacts.eq_sig_fst in H; try subst x; try subst y
  end;
  repeat match goal with
         | |- context[if ?b then _ else _] => let E := fresh "E" in destruct b eqn: E
         end.

Ltac word_eq_pre :=  
  try apply subset_eq_compat;
  try apply Z.eqb_refl;
  auto;
  match goal with
  | H: ?b mod ?m = ?b |- ?a mod ?m = ?b => refine (eq_trans _ H)
  | H: ?a mod ?m = ?a |- ?a = ?b mod ?m => refine (eq_trans (eq_sym H) _)
  | _ => idtac
  end;
  rewrite? Zplus_mod_idemp_l;
  rewrite? Zplus_mod_idemp_r;
  rewrite? Zminus_mod_idemp_l;
  rewrite? Zminus_mod_idemp_r;
  rewrite? Zmult_mod_idemp_l;
  rewrite? Zmult_mod_idemp_r;
  apply mod_eq_from_diff.

Ltac word_solver := word_destruct; word_eq_pre; prove_mod_0.


Section ArithOpsEquiv.

  Context {sz: Z}.

  Lemma wadd_wsadd: forall a b: word sz,
      wadd a b = wsadd a b.
  Proof. word_solver. Qed.

  Lemma wsub_wssub: forall a b: word sz,
      wsub a b = wssub a b.
  Proof. word_solver. Qed.

  Lemma wmul_wsmul: forall a b: word sz,
      wmul a b = wsmul a b.
  Proof. word_solver. Qed.

End ArithOpsEquiv.


Section MoreOps.

  Context {sz: Z}.

  Definition wudiv  := wu_binop Z.div sz.
  Definition wuquot := wu_binop Z.quot sz.
  Definition wumod  := wu_binop Z.modulo sz.
  Definition wurem  := wu_binop Z.rem sz.

  Definition wsdiv  := ws_binop Z.div sz.
  Definition wsquot := ws_binop Z.quot sz.
  Definition wsmod  := ws_binop Z.modulo sz.
  Definition wsrem  := ws_binop Z.rem sz.
  
  Definition wor   := wu_binop Z.lor sz.
  Definition wand  := wu_binop Z.land sz.
  Definition wxor  := wu_binop Z.lxor sz.

  Definition weqb := wu_binop_t Z.eqb sz.

  Definition wuleb := wu_binop_t Z.leb sz.
  Definition wultb := wu_binop_t Z.ltb sz.
  Definition wugeb := wu_binop_t Z.geb sz.
  Definition wugtb := wu_binop_t Z.gtb sz.

  Definition wsleb := ws_binop_t Z.leb sz.
  Definition wsltb := ws_binop_t Z.ltb sz.
  Definition wsgeb := ws_binop_t Z.geb sz.
  Definition wsgtb := ws_binop_t Z.gtb sz.

  Definition wshiftl  := wu_binop Z.shiftl sz.
  Definition wshiftr  := wu_binop Z.shiftr sz.
  Definition wshiftra := ws_binop Z.shiftr sz.

End MoreOps.

Hint Unfold
    wudiv wuquot wumod wurem
    wsdiv wsquot wsmod wsrem
    wor wand wxor
    weqb
    wuleb wultb wugeb wugtb
    wsleb wsltb wsgeb wsgtb
    wshiftl wshiftr wshiftra
: unf_word_all.


Definition wsplit_lo{sz: Z}(count: Z)(w: word sz): word count :=
  ZToWord count (uwordToZ w).

Definition wzext{sz: Z}(sz': Z)(w: word sz): word sz' :=
  ZToWord sz' (uwordToZ w).

Definition wsext{sz: Z}(sz': Z)(w: word sz): word sz' :=
  ZToWord sz' (swordToZ w).

Lemma word_ring: forall sz,
    ring_theory (ZToWord sz 0) (ZToWord sz 1) wadd wmul wsub wopp eq.
Proof.
  intros. constructor; word_solver.
Qed.

Lemma word_ring_morph_Z: forall sz,
    ring_morph (ZToWord sz 0) (ZToWord sz 1) wadd  wmul  wsub  wopp  eq
               0              1              Z.add Z.mul Z.sub Z.opp Z.eqb
               (ZToWord sz).
Proof.
  intros. constructor; word_solver.
Qed.

Lemma weqb_spec: forall sz (a b : word sz),
    weqb a b = true <-> a = b.
Proof. word_solver. Qed.

Lemma mod_pow2_same_cases: forall a n,
    a mod 2 ^ n = a ->
    2 ^ n = 0 /\ a = 0 \/ 0 <= a < 2 ^ n.
Proof.
  intros.
  assert (n < 0 \/ 0 <= n) as C by omega. destruct C as [C | C].
  - left. rewrite (Z.pow_neg_r 2 n C) in *. rewrite ZLib.mod_0_r in H. auto.
  - right.
    rewrite <- H. apply Z.mod_pos_bound.
    apply Z.pow_pos_nonneg; omega.
Qed.    

Lemma mod_pow2_same_bounds: forall a n,
    0 < n ->
    a mod 2 ^ n = a ->
    0 <= a < 2 ^ n.
Proof.
  intros. rewrite <- H0. apply Z.mod_pos_bound.
  apply Z.pow_pos_nonneg; omega.
Qed.    

Lemma pow2_nonneg: forall n,
    0 <= 2 ^ n.
Proof.
  intros. apply Z.pow_nonneg. omega.
Qed.

Lemma pow2_pos: forall n,
    0 <= n ->
    0 < 2 ^ n.
Proof.
  intros. apply Z.pow_pos_nonneg; omega.
Qed.

Lemma div_mul_undo_le: forall a b,
    0 <= a ->
    0 < b ->
    a / b * b <= a.
Proof.
  intros.
  pose proof (Zmod_eq_full a b) as P.
  pose proof (Z.mod_bound_pos a b) as Q.
  omega.
Qed.

Lemma testbit_true_nonneg: forall a i,
    0 <= a ->
    0 <= i ->
    Z.testbit a i = true ->
    2 ^ i <= a.
Proof.
  intros.
  apply Z.testbit_true in H1; [|assumption].
  pose proof (pow2_pos i H0).
  eapply Z.le_trans; [| apply (div_mul_undo_le a (2 ^ i)); omega].
  replace (2 ^ i) with (1 * 2 ^ i) at 1 by omega.
  apply Z.mul_le_mono_nonneg_r; [omega|].
  pose proof (Z.div_pos a (2 ^ i)).
  assert (a / 2 ^ i <> 0); [|omega].
  intro E. rewrite E in H1. cbv in H1. discriminate H1.
Qed.

Lemma pow2_times2: forall i,
    0 < i ->
    2 ^ i = 2 * 2 ^ (i - 1).
Proof.
  intros.
  rewrite <- Z.pow_succ_r by omega.
  f_equal.
  omega.
Qed.

Lemma swordToZ_bound: forall sz (a : word sz),
    0 < sz ->
    - 2 ^ (sz - 1) <= swordToZ a < 2 ^ (sz - 1).
Proof.
  word_destruct.
  + apply mod_pow2_same_bounds in Ma; [|assumption].
    pose proof (pow2_times2 sz).
    apply testbit_true_nonneg in E; omega.
  + apply mod_pow2_same_bounds in Ma; [|assumption].
    pose proof (pow2_times2 sz).
Abort.

(*
subgoal 3 (ID 157) is:
 forall a : word sz, 0 <= uwordToZ a < 2 ^ sz
subgoal 4 (ID 158) is:
 forall n : Z, - 2 ^ (sz - 1) <= n < 2 ^ (sz - 1) -> swordToZ (ZToWord sz n) = n
subgoal 5 (ID 159) is:
 forall a : word sz, ZToWord sz (uwordToZ a) = a
subgoal 6 (ID 160) is:
 forall a : word sz, ZToWord sz (swordToZ a) = a
*)

Definition tobbv{sz: Z}(w: word sz): bbv.Word.word (Z.to_nat sz) :=
  bbv.Word.ZToWord _ (uwordToZ w).

Definition frombbv{sz: nat}(w: bbv.Word.word sz): word (Z.of_nat sz) :=
  ZToWord _ (bbv.Word.uwordToZ w).

Coercion tobbv: word >-> bbv.Word.word.
Coercion frombbv: bbv.Word.word >-> word.

Instance MachineWidth: MachineWidth (word 32) := {|
  add := @wadd 32;
  sub := @wsub 32;
  mul := @wmul 32;
  div := @wsquot 32;
  rem := @wsrem 32;
  negate := @wopp 32;
  signed_less_than := @wsltb 32;
  reg_eqb := @weqb 32;
  xor := @wxor 32;
  or := @wor 32;
  and := @wand 32;
  XLEN := 32;
  regToInt8  := wsplit_lo 8;
  regToInt16 := wsplit_lo 16;
  regToInt32 := id;
  regToInt64 := @wzext 32 64;
  uInt8ToReg  := @wzext  8 32;
  uInt16ToReg := @wzext 16 32;
  uInt32ToReg := id;
  uInt64ToReg := wsplit_lo 32; (* unused *)
  int8ToReg  := wsext 32;
  int16ToReg := wsext 32;
  int32ToReg := id;
  int64ToReg := wsplit_lo 32; (* unused *)
  s32 := id;
  u32 := id;
  regToZ_signed := @swordToZ 32;
  regToZ_unsigned := @uwordToZ 32;
  sll w n := ZToWord 32 (Z.shiftl (uwordToZ w) n);
  srl w n := ZToWord 32 (Z.shiftr (uwordToZ w) n);
  sra w n := ZToWord 32 (Z.shiftr (swordToZ w) n);
  ltu := @wultb 32;
  divu := @wuquot 32;
  remu := @wurem 32;
  maxSigned := ZToWord 32 (2 ^ 31 - 1);
  maxUnsigned := ZToWord 32 (2 ^ 32 - 1);
  minSigned := ZToWord 32 (- 2 ^ 31);
  regToShamt5 x := (uwordToZ x) mod 2 ^ 5;
  regToShamt  x := (uwordToZ x) mod 2 ^ 5;
  highBits x := ZToWord 32 (bitSlice x 32 64);
  ZToReg := ZToWord 32;
  regRing := @word_ring 32;
  ZToReg_morphism := @word_ring_morph_Z 32;
(*
  reg_eqb_spec := @weqb_true_iff 32;
  regToZ_signed_bounds := @wordToZ_size'' 32 ltac:(lia);
  regToZ_unsigned_bounds := @uwordToZ_bound 32;
*)
  add_def_signed := @wadd_wsadd 32;
  sub_def_signed := @wsub_wssub 32;
  mul_def_signed := @wmul_wsmul 32;
(*
  regToZ_ZToReg_signed := @wordToZ_ZToWord'' 32 ltac:(lia);
*)
  regToZ_ZToReg_unsigned_mod _ := eq_refl; (*
  ZToReg_regToZ_unsigned := @ZToWord_uwordToZ 32;
  ZToReg_regToZ_signed := @ZToWord_wordToZ 32; *)
  XLEN_lbound := ltac:(lia);
  div_def  _ _ := eq_refl;
  rem_def  _ _ := eq_refl;
  divu_def _ _ := eq_refl;
  remu_def _ _ := eq_refl;  
|}.

Abort.