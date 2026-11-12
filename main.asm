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


; Fill all 5 bitplanes ($020000 - $029C3F) with 32-bit LFSR pseudo-random data
    lea     Bitplane1,a0
    move.w  #(8000*5)/4-1,d0        ; 10,000 longwords (40,000 bytes)
    move.l  #$ACE1B5E3,d1           ; Non-zero 32-bit seed (must never be 0)
    move.l  #$D0000001,d2           ; 32-bit maximal-length LFSR feedback polynomial

.fill_rnd:
    lsr.l   #1,d1                   ; Shift right, LSB goes into Carry/X flag
    bcc.s   .no_xor
    eor.l   d2,d1                   ; Apply feedback taps if shifted-out bit was 1
.no_xor:
    move.l  d1,(a0)+                ; Write 32 random bits to Chip RAM
    dbf     d0,.fill_rnd


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

COLOR00    equ $180

; --- Inside CopperList_ROM (before $FFFF,$FFFE) ---
  dc.w      COLOR00+$00,$0000                            ; 00: Black (background)
  dc.w      COLOR00+$02,$0FFF                            ; 01: White
  dc.w      COLOR00+$04,$0F00                            ; 02: Red
  dc.w      COLOR00+$06,$00F0                            ; 03: Green
  dc.w      COLOR00+$08,$000F                            ; 04: Blue
  dc.w      COLOR00+$0A,$0FF0                            ; 05: Yellow
  dc.w      COLOR00+$0C,$00FF                            ; 06: Cyan
  dc.w      COLOR00+$0E,$0F0F                            ; 07: Magenta
  dc.w      COLOR00+$10,$0888                            ; 08: Mid Gray
  dc.w      COLOR00+$12,$0CCC                            ; 09: Light Gray
  dc.w      COLOR00+$14,$0444                            ; 10: Dark Gray
  dc.w      COLOR00+$16,$0F80                            ; 11: Orange
  dc.w      COLOR00+$18,$0840                            ; 12: Brown
  dc.w      COLOR00+$1A,$0F88                            ; 13: Pink
  dc.w      COLOR00+$1C,$08F8                            ; 14: Light Green
  dc.w      COLOR00+$1E,$088F                            ; 15: Light Blue
  dc.w      COLOR00+$20,$0200                            ; 16: Dark Red
  dc.w      COLOR00+$22,$0500                            ; 17: Medium-Dark Red
  dc.w      COLOR00+$24,$0900                            ; 18: Medium Red
  dc.w      COLOR00+$26,$0D00                            ; 19: Bright Red
  dc.w      COLOR00+$28,$0020                            ; 20: Dark Green
  dc.w      COLOR00+$2A,$0050                            ; 21: Medium-Dark Green
  dc.w      COLOR00+$2C,$0090                            ; 22: Medium Green
  dc.w      COLOR00+$2E,$00D0                            ; 23: Bright Green
  dc.w      COLOR00+$30,$0002                            ; 24: Dark Blue
  dc.w      COLOR00+$32,$0005                            ; 25: Medium-Dark Blue
  dc.w      COLOR00+$34,$0009                            ; 26: Medium Blue
  dc.w      COLOR00+$36,$000D                            ; 27: Bright Blue
  dc.w      COLOR00+$38,$0222                            ; 28: Ramp Gray 1
  dc.w      COLOR00+$3A,$0666                            ; 29: Ramp Gray 2
  dc.w      COLOR00+$3C,$0AAA                            ; 30: Ramp Gray 3
  dc.w      COLOR00+$3E,$0EEE                            ; 31: Near White

  dc.w      $FFFF,$FFFE
CopperList_End: