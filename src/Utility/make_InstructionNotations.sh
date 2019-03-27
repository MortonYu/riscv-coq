#!/bin/sh

F="./InstructionNotations.v"

echo "(* File generated by ./make_InstructionNotations.sh, do not edit *)" > "$F"
echo "Require Export riscv.Decode." >> "$F"
echo "Require Export riscv.InstructionCoercions." >> "$F"
echo 'Notation "!RISCV:! x  y  ..  z" := (@cons Instruction x (@cons Instruction y .. (@cons Instruction z nil) ..)) (at level 10).' | tr '!' "'" >> "$F"

echo "" >> "$F"

grep ./Decode.v -E -e '^ *\|.*Instruction(M64|M|I64|I|CSR|A64|A)$' \
    | sed -E \
	  -e 's/ *\| *(.)([^ ]+) : Register -> Register -> Register -> Z -> Instruction.*/Notation "!\L\1\2! !x! r1 , !x! r2 , !x! r3 , i" := (\U\1\L\2 r1 r2 r3 i) (at level 10, i at level 200, format "!\/\/!     !\L\1\2!%fill%!x! r1 ,  !x! r2 ,  !x! r3 ,  i")./g' \
	  -e 's/ *\| *(.)([^ ]+) : Register -> Register -> Register -> Instruction.*/Notation "!\L\1\2! !x! r1 , !x! r2 , !x! r3" := (\U\1\L\2 r1 r2 r3) (at level 10, format "!\/\/!     !\L\1\2!%fill%!x! r1 ,  !x! r2 ,  !x! r3")./g' \
	  -e 's/ *\| *(.)([^ ]+) : Register -> Register -> Z -> Instruction.*/Notation "!\L\1\2! !x! r1 , !x! r2 , i" := (\U\1\L\2 r1 r2 i) (at level 10, i at level 200, format "!\/\/!     !\L\1\2!%fill%!x! r1 ,  !x! r2 ,  i")./g' \
	  -e 's/ *\| *(.)([^ ]+) : Register -> Z -> Z -> Instruction.*/Notation "!\L\1\2! !x! r1 , i , j" := (\U\1\L\2 r1 i j) (at level 10, i at level 200, j at level 200, format "!\/\/!     !\L\1\2!%fill%!x! r1 ,  i ,  j")./g' \
	  -e 's/ *\| *(.)([^ ]+) : Register -> Register -> Instruction.*/Notation "!\L\1\2! !x! r1 , !x! r2" := (\U\1\L\2 r1 r2) (at level 10, format "!\/\/!     !\L\1\2!%fill%!x! r1 ,  !x! r2")./g' \
	  -e 's/ *\| *(.)([^ ]+) : Register -> Z -> Instruction.*/Notation "!\L\1\2! !x! r1 , i" := (\U\1\L\2 r1 i) (at level 10, i at level 200, format "!\/\/!     !\L\1\2!%fill%!x! r1 ,  i")./g' \
	  -e 's/ *\| *(.)([^ ]+) : Z -> Z -> Instruction.*/Notation "!\L\1\2! i , j" := (\U\1\L\2 i j) (at level 10, i at level 200, j at level 200, format "!\/\/!     !\L\1\2!%fill%i ,  j")./g' \
	  -e 's/ *\| *(.)([^ ]+) : Instruction.*/Notation "!\L\1\2!" := (\U\1\L\2) (at level 10, format "!\/\/!     !\L\1\2!")./g' \
	  -e 's/(remove this text to debug) *\| *(.*)/(*\0*)/g' \
	  -e 's/\!(.)\!%fill%/!\1!        /g' \
	  -e 's/\!(..)\!%fill%/!\1!       /g' \
	  -e 's/\!(...)\!%fill%/!\1!      /g' \
	  -e 's/\!(....)\!%fill%/!\1!     /g' \
	  -e 's/\!(.....)\!%fill%/!\1!    /g' \
	  -e 's/\!(......)\!%fill%/!\1!   /g' \
	  -e 's/\!(.+)\!%fill%/!\1! /g' \
    | tr '!' "'" >> "$F"