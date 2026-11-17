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
  lea       $07FF00,sp                                   ; Initialize stack pointer in Chip RAM


  lea       CUSTOM,a6
  move.w    #$7FFF,DMACON(a6)                            ; Disable all DMA initially


; Fill 5 bitplanes ($020000 - $03387F, 16000 bytes each: 8000B pattern + 8000B wrap copy)
    lea     Bitplane1,a0
    move.l  #$ACE1B5E3,d1           ; Non-zero 32-bit seed (must never be 0)
    move.l  #$D0000001,d2           ; 32-bit maximal-length LFSR feedback polynomial
    moveq   #5-1,d4                 ; 5 bitplanes

.fill_plane:
    move.l  a0,a1                   ; Save start of this plane's 8000-byte pattern
    move.w  #8000/4-1,d0            ; 2,000 longwords (8,000 bytes) per plane
.fill_rnd:
    lsr.l   #1,d1                   ; Shift right, LSB goes into Carry/X flag
    bcc.s   .no_xor
    eor.l   d2,d1                   ; Apply feedback taps if shifted-out bit was 1
.no_xor:
    moveq   #0,d3                   ; Default: empty (black)
    cmp.l   #$04000000,d1           ; ~1.5% chance of a star per 32-bit longword
    bhs.s   .no_star
    move.w  d1,d5
    and.w   #31,d5                  ; Pick 1 random bit (0..31) in the longword
    bset    d5,d3                   ; Single-pixel star
.no_star:
    move.l  d3,(a0)+                ; Write 32 bits to Chip RAM
    dbf     d0,.fill_rnd

    move.w  #8000/4-1,d0            ; Duplicate 8000-byte pattern for seamless vertical wrap
.copy_wrap:
    move.l  (a1)+,(a0)+
    dbf     d0,.copy_wrap
    dbf     d4,.fill_plane


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
  add.l     #16000,a0
  addq.l    #8,a1
  dbf       d0,.set_planes

    ; 3. Set a visible color for COLOR01 so bitplane pixels aren't black
  move.w    #$0FFF,$182(a6)                              ; COLOR01 = White

    ; 4. Load Chip RAM Copper list and enable DMA
  move.l    #ChipCopper,COP1LCH(a6)
  move.w    #0,COPJMP1(a6)
  move.w    #$8380,DMACON(a6)                            ; Master + Bitplane + Copper DMA

  move.l    d1,d7                                        ; Preserve non-zero LFSR state in d7
  move.l    #$D0000001,d6                                ; LFSR polynomial in d6
  moveq     #0,d4                                        ; Frame counter for bitplane scrolling

loop:
.wait_vbl:
  move.l    $004(a6),d0                                  ; Read VPOSR/VHPOSR
  and.l     #$0001FF00,d0
  cmp.l     #$00010000,d0                                ; Wait for raster line 256
  bne.s     .wait_vbl

  addq.w    #1,d4                                        ; Advance frame counter
  lea       Bitplane1,a0
  lea       ChipCopper+(CopBPL1H-CopperList_ROM)+2,a1
  moveq     #1,d2                                        ; Speed multiplier (1..5 lines/frame)
  moveq     #5-1,d0
.scroll_planes:
  move.w    d4,d1
  mulu      d2,d1                                        ; frame * speed
  divu      #200,d1                                      ; mod 200 lines
  swap      d1
  neg.w     d1
  add.w     #199,d1                                      ; Reverse direction: 199 -> 0

  ; Generate new random stars on the newly-entering scanlines (d2 lines at d1)
  movem.l   d0-d2,-(sp)                                  ; Save plane counter, line offset, speed
  move.w    d1,d5                                        ; d5 = current line index
  subq.w    #1,d2                                        ; Loop d2 lines (0..speed-1)
.new_lines:
  cmp.w     #200,d5
  blo.s     .line_ok
  sub.w     #200,d5
.line_ok:
  move.w    d5,-(sp)
  mulu      #40,d5
  lea       (a0,d5.l),a2                                 ; a2 = plane + line*40
  lea       8000(a2),a3                                  ; a3 = wrap copy + line*40
  moveq     #10-1,d5                                     ; 10 longwords (40 bytes) per scanline
.new_stars:
  lsr.l     #1,d7
  bcc.s     .no_xor2
  eor.l     d6,d7
.no_xor2:
  moveq     #0,d0                                        ; Default: empty (black)
  cmp.l     #$04000000,d7
  bhs.s     .write_star
  move.w    d7,d1
  and.w     #31,d1
  bset      d1,d0                                        ; Single-pixel star
.write_star:
  move.l    d0,(a2)+
  move.l    d0,(a3)+
  dbf       d5,.new_stars
  move.w    (sp)+,d5
  addq.w    #1,d5
  dbf       d2,.new_lines
  movem.l   (sp)+,d0-d2                                  ; Restore plane counter, line offset, speed

  mulu      #40,d1                                       ; Convert line offset to bytes (40 bytes/line)
  add.l     a0,d1                                        ; Bitplane base + scroll offset
  move.w    d1,4(a1)                                     ; Low word -> BPLxPTL
  swap      d1
  move.w    d1,(a1)                                      ; High word -> BPLxPTH
  add.l     #16000,a0
  addq.l    #8,a1
  addq.w    #1,d2                                        ; Next plane scrolls faster
  dbf       d0,.scroll_planes

  jmp       loop

  include   "copper.i"