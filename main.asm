; Kickstart 1.0 - 1.3: 256kB $00fc0000 – $00ffffff
; Kickstart 2.0 - 3.1: 512kB $00f80000 – $00ffffff
  org       $fc0000

CUSTOM EQU $DFF000

START
  jmp       begin
  ;  nop
  ;  nop
  ;  nop
  ;  nop

begin:
  move.l    #CUSTOM,a6
loop:
  addq.w    #1,d0
  and.w     #$0fff,d0      ; keep 12 bit
  move.w    d0,$180(a6)    ; COLOR00
  jmp       loop
