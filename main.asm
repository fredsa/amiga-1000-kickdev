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
  org       $F80000
  dc.l      $11114EF9,$00F80008                          ; Valid Kickstart ROM header + JMP $F80008

CUSTOM     equ $DFF000
BPLCON0    equ $100
BPLCON1    equ $102
BPLCON2    equ $104
BPL1MOD    equ $108
BPL2MOD    equ $10A
DIWSTRT    equ $08E
DIWSTOP    equ $090
DDFSTRT    equ $092
DDFSTOP    equ $094
BPL1PTH    equ $0E0
DMACON     equ $096
COP1LCH    equ $080
COPJMP1    equ $088

ChipCopper equ $010000                                   ; Writable Chip RAM for Copper list
Bitplane1  equ $020000                                   ; Writable Chip RAM for Bitplanes

begin:
  move.b    #3,$BFE201                                   ; Set CIA-A PRA bits 0-1 as outputs
  move.b    #2,$BFE001                                   ; Clear OVL (unmap ROM from $000000, expose Chip RAM)

  lea       CUSTOM,a6
  move.w    #$7FFF,DMACON(a6)                            ; Disable all DMA initially

    ; 1. Copy Copper list from ROM ($F8xxxx) to Chip RAM ($010000)
  lea       CopperList_ROM(pc),a0
  lea       ChipCopper,a1
  moveq     #(CopperList_End-CopperList_ROM)/2-1,d0
.copy_cop:
  move.w    (a0)+,(a1)+
  dbf       d0,.copy_cop

    ; 2. Patch bitplane pointers inside the Chip RAM Copper list
  lea       Bitplane1,a0
  lea       ChipCopper+(CopBPL1H-CopperList_ROM)+2,a1
  moveq     #5-1,d0
.set_planes:
  move.l    a0,d1
  move.w    d1,4(a1)                                     ; Low word -> BPLxPTL
  swap      d1
  move.w    d1,(a1)                                      ; High word -> BPLxPTH
  add.l     #8000,a0
  addq.l    #8,a1
  dbf       d0,.set_planes

    ; 3. Set a visible color for COLOR01 so bitplane pixels aren't black
  move.w    #$0FFF,$182(a6)                              ; COLOR01 = White

    ; 4. Load Chip RAM Copper list and enable DMA
  move.l    #ChipCopper,COP1LCH(a6)
  move.w    #0,COPJMP1(a6)
  move.w    #$8380,DMACON(a6)                            ; Master + Bitplane + Copper DMA

loop:
  addq.w    #1,d3
  and.w     #$0FFF,d3
  move.w    d3,$180(a6)                                  ; Cycle COLOR00
  jmp       loop

; --- Copper List Template in ROM ---
CopperList_ROM:
  dc.w      DIWSTRT,$2C81
  dc.w      DIWSTOP,$F4C1
  dc.w      DDFSTRT,$0038
  dc.w      DDFSTOP,$00D0
  dc.w      BPLCON0,$5200                                ; 5 bitplanes + Color burst
  dc.w      BPLCON1,$0000
  dc.w      BPLCON2,$0024
  dc.w      BPL1MOD,$0000
  dc.w      BPL2MOD,$0000

CopBPL1H:
  dc.w      BPL1PTH,0,    BPL1PTH+2,0
  dc.w      BPL1PTH+4,0,  BPL1PTH+6,0
  dc.w      BPL1PTH+8,0,  BPL1PTH+10,0
  dc.w      BPL1PTH+12,0, BPL1PTH+14,0
  dc.w      BPL1PTH+16,0, BPL1PTH+18,0

  dc.w      $FFFF,$FFFE
CopperList_End: