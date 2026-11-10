; --------------------------------------------------------
; Kickdev - Copyright 2026 Fred Sauer
;   Software development environment for Amiga 1000
; --------------------------------------------------------
; Amiga 1000
;   Boot ROM: 8kB $00f80000 - $00f81fff
;   Kickstart 1.0 - 1.3: 256kB $00fc0000 - $00ffffff
;   Kickstart 2.0 - 3.1: 512kB $00f80000 - $00ffffff
;
; Boot ROM is mirrored to $00000000 where 68000 reads:
;   $00000000 Supervisor Stack Pointer (SSP), here $11114e49
;   $00000004 Initial Program Counter (PC), here $00f80008
;
; These 8 bytes provide $f80008 effective start address: 
;   dc.w      $1111 ; $1111.w
;   dc.w      $4ef9 ; jmp
;   dc.l      begin ; $00f80008.l

; --------------------------------------------------------
; Uncomment to build boot or Kickstart ROM:
; --------------------------------------------------------
;  org       $f80000
;  dc.l      $11114ef9,$00f80008

; --------------------------------------------------------
; Program start.
; --------------------------------------------------------

CUSTOM EQU $dff000

begin:
  move.l    #CUSTOM,a6
loop:
  addq.w    #1,d0
  and.w     #$0fff,d0              ; keep 12 bit
  move.w    d0,$180(a6)            ; COLOR00
  jmp       loop
