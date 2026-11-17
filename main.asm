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
SPR0PTH    equ $120
DMACON     equ $096
COP1LCH    equ $080
COPJMP1    equ $088

ChipCopper  equ $010000                                  ; Writable Chip RAM for Copper list
ChipSprite  equ $010200                                  ; Writable Chip RAM for Ship Sprite 0
ChipNullSpr equ $010300                                  ; Null sprite (dc.l 0) for Sprites 1-7
ShipX       equ $010308                                  ; Ship X position (long, 16.16 fixed-point)
ShipY       equ $01030C                                  ; Ship Y position (long, 16.16 fixed-point)
ShipVX      equ $010310                                  ; Ship X velocity (long, 16.16 fixed-point)
ShipVY      equ $010314                                  ; Ship Y velocity (long, 16.16 fixed-point)
KeyState    equ $010318                                  ; Held keys (bit 0:U, 1:D, 2:L, 3:R, 4:Space)
FireCool    equ $010319                                  ; Fire cooldown counter (byte)
ChipBullets equ $010400                                  ; 3 bullet sprites (Sprites 1-3, 32 bytes each)
ChipAliens  equ $010460                                  ; 4 alien sprites (Sprites 4-7, 64 bytes each)
Bullets     equ $010580                                  ; 3 bullet states (X.w, Y.w; X=-1 = inactive)
Aliens      equ $0105A0                                  ; 4 alien states (X.w, Y.w, VX.w, Respawn.w)

SHIP_ACCEL  equ $00008000                                ; 0.5 px/frame^2
SHIP_DECEL  equ $00002000                                ; 0.125 px/frame^2
SHIP_MAXVEL equ $00060000                                ; 6.0 px/frame
Bitplane1   equ $020000                                  ; Writable Chip RAM for Bitplanes

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
  move.w    #(CopperList_End-CopperList_ROM)/2-1,d0
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

    ; 3. Copy Ship Sprite to Chip RAM, init Null Sprite, and patch Copper sprite pointers
  lea       ShipSprite_ROM(pc),a0
  lea       ChipSprite,a1
  moveq     #(ShipSprite_End-ShipSprite_ROM)/2-1,d0
.copy_spr:
  move.w    (a0)+,(a1)+
  dbf       d0,.copy_spr

  clr.l     ChipNullSpr
  move.l    #152<<16,ShipX
  move.l    #160<<16,ShipY
  clr.l     ShipVX
  clr.l     ShipVY
  clr.b     KeyState
  clr.b     FireCool

  lea       ChipCopper+(CopSPR0H-CopperList_ROM)+2,a1
  move.l    #ChipSprite,d1
  move.w    d1,4(a1)
  swap      d1
  move.w    d1,(a1)
  addq.l    #8,a1

  ; Init 3 bullet sprites (Sprites 1-3) and bullet state table
  lea       ChipBullets,a2
  lea       Bullets,a3
  moveq     #3-1,d0
.init_bullets:
  lea       BulletSprite_ROM(pc),a0
  move.l    a2,a4
  moveq     #(BulletSprite_End-BulletSprite_ROM)/2-1,d2
.copy_bspr:
  move.w    (a0)+,(a4)+
  dbf       d2,.copy_bspr
  move.w    #-1,(a3)+                                    ; X = -1 (inactive)
  clr.w     (a3)+                                        ; Y = 0
  move.l    a2,d1
  move.w    d1,4(a1)
  swap      d1
  move.w    d1,(a1)
  addq.l    #8,a1
  lea       32(a2),a2
  dbf       d0,.init_bullets

  ; Init 4 alien sprites (Sprites 4-7) and alien state table
  lea       ChipAliens,a2
  lea       Aliens,a3
  lea       AlienInit_ROM(pc),a5
  moveq     #4-1,d0
.init_aliens:
  lea       AlienSprite_ROM(pc),a0
  move.l    a2,a4
  moveq     #(AlienSprite_End-AlienSprite_ROM)/2-1,d2
.copy_aspr:
  move.w    (a0)+,(a4)+
  dbf       d2,.copy_aspr
  move.w    (a5)+,(a3)+                                  ; X
  move.w    (a5)+,(a3)+                                  ; Y
  move.w    (a5)+,(a3)+                                  ; VX
  clr.w     (a3)+                                        ; Respawn = 0
  move.l    a2,d1
  move.w    d1,4(a1)
  swap      d1
  move.w    d1,(a1)
  addq.l    #8,a1
  lea       64(a2),a2
  dbf       d0,.init_aliens

    ; 4. Load Chip RAM Copper list and enable DMA
  move.l    #ChipCopper,COP1LCH(a6)
  move.w    #0,COPJMP1(a6)
  move.w    #$83A0,DMACON(a6)                            ; Master + Bitplane + Copper + Sprite DMA

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

  ; --- Read Keyboard (CIA-A SDR $BFEC01) ---
  btst      #3,$BFED01                                   ; Serial port interrupt flag set?
  beq       .no_key
  move.b    $BFEC01,d0                                   ; Read raw keycode
  bset      #6,$BFEE01                                   ; Pulse KDAT low to acknowledge
  moveq     #20,d1
.ack_wait:
  dbf       d1,.ack_wait
  bclr      #6,$BFEE01
  not.b     d0
  ror.b     #1,d0                                        ; Bit 7 = 1 if released, 0 if pressed
  move.b    d0,d1
  and.b     #$7F,d1                                      ; Raw keycode (0..127)
  moveq     #-1,d2
  cmp.b     #$4C,d1                                      ; Up arrow
  beq.s     .key_u
  cmp.b     #$11,d1                                      ; W
  bne.s     .chk_d
.key_u:
  moveq     #0,d2
  bra.s     .apply_key
.chk_d:
  cmp.b     #$4D,d1                                      ; Down arrow
  beq.s     .key_d
  cmp.b     #$21,d1                                      ; S
  bne.s     .chk_l
.key_d:
  moveq     #1,d2
  bra.s     .apply_key
.chk_l:
  cmp.b     #$4F,d1                                      ; Left arrow
  beq.s     .key_l
  cmp.b     #$20,d1                                      ; A
  bne.s     .chk_r
.key_l:
  moveq     #2,d2
  bra.s     .apply_key
.chk_r:
  cmp.b     #$4E,d1                                      ; Right arrow
  beq.s     .key_r
  cmp.b     #$22,d1                                      ; D
  bne.s     .chk_space
.key_r:
  moveq     #3,d2
  bra.s     .apply_key
.chk_space:
  cmp.b     #$40,d1                                      ; Spacebar
  bne.s     .no_key
  moveq     #4,d2
.apply_key:
  btst      #7,d0
  bne.s     .key_up
  bset      d2,KeyState
  bra.s     .no_key
.key_up:
  bclr      d2,KeyState
.no_key:

  ; --- Read Joystick Port 2 (JOY1DAT $DFF00C) & apply acceleration/deceleration ---
  move.w    $00C(a6),d0
  move.w    d0,d1
  lsr.w     #1,d1
  eor.w     d0,d1                                        ; Bit 0 = Down, Bit 8 = Up
  move.b    KeyState,d2

  ; Horizontal velocity (ShipVX)
  move.l    ShipVX,d5
  moveq     #0,d3                                        ; d3 = 1 if horizontal input active
  btst      #9,d0                                        ; Joy Left
  bne.s     .acc_l
  btst      #2,d2                                        ; Key Left
  beq.s     .chk_acc_r
.acc_l:
  sub.l     #SHIP_ACCEL,d5
  cmp.l     #-SHIP_MAXVEL,d5
  bge.s     .x_input_done
  move.l    #-SHIP_MAXVEL,d5
.x_input_done:
  moveq     #1,d3
  bra.s     .update_x
.chk_acc_r:
  btst      #1,d0                                        ; Joy Right
  bne.s     .acc_r
  btst      #3,d2                                        ; Key Right
  beq.s     .decel_x
.acc_r:
  add.l     #SHIP_ACCEL,d5
  cmp.l     #SHIP_MAXVEL,d5
  ble.s     .x_input_done
  move.l    #SHIP_MAXVEL,d5
  bra.s     .x_input_done
.decel_x:
  tst.l     d5
  beq.s     .update_x
  bmi.s     .decel_x_neg
  sub.l     #SHIP_DECEL,d5
  bpl.s     .update_x
  moveq     #0,d5
  bra.s     .update_x
.decel_x_neg:
  add.l     #SHIP_DECEL,d5
  bmi.s     .update_x
  moveq     #0,d5
.update_x:
  move.l    d5,ShipVX
  add.l     ShipX,d5
  move.l    d5,ShipX

  ; Vertical velocity (ShipVY)
  move.l    ShipVY,d3
  btst      #8,d1                                        ; Joy Up
  bne.s     .acc_u
  btst      #0,d2                                        ; Key Up
  beq.s     .chk_acc_d
.acc_u:
  sub.l     #SHIP_ACCEL,d3
  cmp.l     #-SHIP_MAXVEL,d3
  bge.s     .update_y
  move.l    #-SHIP_MAXVEL,d3
  bra.s     .update_y
.chk_acc_d:
  btst      #0,d1                                        ; Joy Down
  bne.s     .acc_d
  btst      #1,d2                                        ; Key Down
  beq.s     .decel_y
.acc_d:
  add.l     #SHIP_ACCEL,d3
  cmp.l     #SHIP_MAXVEL,d3
  ble.s     .update_y
  move.l    #SHIP_MAXVEL,d3
  bra.s     .update_y
.decel_y:
  tst.l     d3
  beq.s     .update_y
  bmi.s     .decel_y_neg
  sub.l     #SHIP_DECEL,d3
  bpl.s     .update_y
  moveq     #0,d3
  bra.s     .update_y
.decel_y_neg:
  add.l     #SHIP_DECEL,d3
  bmi.s     .update_y
  moveq     #0,d3
.update_y:
  move.l    d3,ShipVY
  add.l     ShipY,d3
  move.l    d3,ShipY

  move.w    ShipX,d5                                     ; Integer X
  move.w    ShipY,d3                                     ; Integer Y

.clamp_ship:
  tst.w     d5
  bpl.s     .x_min_ok
  moveq     #0,d5
  clr.l     ShipX
  clr.l     ShipVX
.x_min_ok:
  cmp.w     #303,d5
  ble.s     .x_max_ok
  move.w    #303,d5
  move.l    #303<<16,ShipX
  clr.l     ShipVX
.x_max_ok:
  tst.w     d3
  bpl.s     .y_min_ok
  moveq     #0,d3
  clr.l     ShipY
  clr.l     ShipVY
.y_min_ok:
  cmp.w     #183,d3
  ble.s     .y_max_ok
  move.w    #183,d3
  move.l    #183<<16,ShipY
  clr.l     ShipVY
.y_max_ok:

  ; --- Update Ship Sprite Control Words (VSTART/HSTART, VSTOP/CTRL) ---
  add.w     #$81,d5                                      ; HSTART = $81 + ShipX (lores pixels)
  lsr.w     #1,d5                                        ; d5 = HSTART[8:1], X/C = HSTART[0]
  scs       d2                                           ; Save HSTART[0] in d2 (non-zero if odd)
  add.w     #$2C,d3                                      ; VSTART = $2C + ShipY
  move.w    d3,d0
  lsl.w     #8,d0
  move.b    d5,d0                                        ; Word 0: (VSTART<<8) | HSTART[8:1]
  move.w    d0,ChipSprite

  move.w    d3,d1
  add.w     #16,d1                                       ; VSTOP = VSTART + 16
  move.w    d1,d0
  lsl.w     #8,d0                                        ; Word 1 high byte = VSTOP[7:0]
  btst      #8,d3                                        ; VSTART bit 8 -> bit 2
  beq.s     .no_vs8
  bset      #2,d0
.no_vs8:
  btst      #8,d1                                        ; VSTOP bit 8 -> bit 1
  beq.s     .no_ve8
  bset      #1,d0
.no_ve8:
  tst.b     d2                                           ; HSTART bit 0 -> bit 0
  beq.s     .no_hs0
  bset      #0,d0
.no_hs0:
  move.w    d0,ChipSprite+2

  ; --- Fire / Spacebar -> Spawn Bullet ---
  tst.b     FireCool
  beq.s     .can_fire
  subq.b    #1,FireCool
  bra.s     .update_bullets
.can_fire:
  btst      #7,$BFE001                                   ; Joy Port 2 Fire (active low)
  beq.s     .do_fire
  btst      #4,KeyState                                  ; Spacebar held
  beq.s     .update_bullets
.do_fire:
  lea       Bullets,a0
  moveq     #3-1,d0
.find_slot:
  tst.w     (a0)
  bmi.s     .spawn_bullet
  addq.l    #4,a0
  dbf       d0,.find_slot
  bra.s     .update_bullets
.spawn_bullet:
  move.w    ShipX,d1
  addq.w    #7,d1                                        ; Center bullet on 16px ship
  move.w    d1,(a0)+
  move.w    ShipY,d1
  subq.w    #4,d1
  move.w    d1,(a0)
  move.b    #8,FireCool

  ; --- Update & Render 3 Bullets (Sprites 1-3) ---
.update_bullets:
  move.w    d4,-(sp)                                     ; Preserve starfield frame counter
  lea       Bullets,a0
  lea       ChipBullets,a1
  moveq     #3-1,d4
.bullet_loop:
  move.w    (a0),d5                                      ; d5 = Bullet X (-1 if inactive)
  bmi.s     .next_bullet
  move.w    2(a0),d3                                     ; d3 = Bullet Y
  subq.w    #6,d3                                        ; Move upward 6 px/frame
  bpl.s     .bullet_alive
  move.w    #-1,(a0)                                     ; Deactivate
  clr.l     (a1)                                         ; Hide sprite
  bra.s     .next_bullet
.bullet_alive:
  move.w    d3,2(a0)
  add.w     #$81,d5
  lsr.w     #1,d5
  scs       d2
  add.w     #$2C,d3
  move.w    d3,d0
  lsl.w     #8,d0
  move.b    d5,d0
  move.w    d0,(a1)
  move.w    d3,d1
  addq.w    #5,d1
  move.w    d1,d0
  lsl.w     #8,d0
  btst      #8,d3
  beq.s     .b_no_vs8
  bset      #2,d0
.b_no_vs8:
  btst      #8,d1
  beq.s     .b_no_ve8
  bset      #1,d0
.b_no_ve8:
  tst.b     d2
  beq.s     .b_no_hs0
  bset      #0,d0
.b_no_hs0:
  move.w    d0,2(a1)
.next_bullet:
  addq.l    #4,a0
  lea       32(a1),a1
  dbf       d4,.bullet_loop
  move.w    (sp)+,d4                                     ; Restore starfield frame counter

  ; --- Bullet-to-Alien Collision ---
  lea       Bullets,a0
  lea       ChipBullets,a1
  moveq     #3-1,d0
.col_bullet:
  move.w    (a0),d1                                      ; Bullet X
  bmi.s     .col_next_b
  move.w    2(a0),d2                                     ; Bullet Y
  lea       Aliens,a2
  lea       ChipAliens,a3
  moveq     #4-1,d3
.col_alien:
  move.w    (a2),d5                                      ; Alien X
  bmi.s     .col_next_a
  sub.w     d1,d5
  bpl.s     .dx_pos
  neg.w     d5
.dx_pos:
  cmp.w     #12,d5
  bhs.s     .col_next_a
  move.w    2(a2),d5                                     ; Alien Y
  sub.w     d2,d5
  bpl.s     .dy_pos
  neg.w     d5
.dy_pos:
  cmp.w     #12,d5
  bhs.s     .col_next_a
  ; Hit! Deactivate bullet and alien
  move.w    #-1,(a0)
  clr.l     (a1)
  move.w    #-1,(a2)
  clr.l     (a3)
  move.w    #60,6(a2)                                    ; Respawn in 60 frames
  bra.s     .col_next_b
.col_next_a:
  addq.l    #8,a2
  lea       64(a3),a3
  dbf       d3,.col_alien
.col_next_b:
  addq.l    #4,a0
  lea       32(a1),a1
  dbf       d0,.col_bullet

  ; --- Update & Render 4 Aliens (Sprites 4-7) ---
  move.w    d4,-(sp)                                     ; Preserve starfield frame counter
  lea       Aliens,a0
  lea       ChipAliens,a1
  moveq     #4-1,d4
.alien_loop:
  move.w    (a0),d5                                      ; d5 = Alien X (-1 if inactive)
  bpl.s     .alien_active
  subq.w    #1,6(a0)                                     ; Countdown respawn
  bpl       .next_alien
  move.w    d7,d5
  and.w     #$00FF,d5
  add.w     #24,d5                                       ; Spawn X in 24..279
  move.w    d5,(a0)
  clr.w     2(a0)                                        ; Spawn at Y = 0
  bra.s     .alien_render
.alien_active:
  add.w     4(a0),d5                                     ; X += VX
  tst.w     d5
  bpl.s     .ax_min_ok
  moveq     #0,d5
  neg.w     4(a0)
.ax_min_ok:
  cmp.w     #303,d5
  ble.s     .ax_max_ok
  move.w    #303,d5
  neg.w     4(a0)
.ax_max_ok:
  move.w    d5,(a0)
  move.w    2(a0),d3                                     ; d3 = Alien Y
  move.w    (sp),d0                                      ; Frame counter
  and.w     #3,d0
  bne.s     .alien_render
  addq.w    #1,d3                                        ; Descend 1 px every 4 frames
  cmp.w     #188,d3
  ble.s     .ay_ok
  moveq     #0,d3
.ay_ok:
  move.w    d3,2(a0)
.alien_render:
  move.w    2(a0),d3
  add.w     #$81,d5
  lsr.w     #1,d5
  scs       d2
  add.w     #$2C,d3
  move.w    d3,d0
  lsl.w     #8,d0
  move.b    d5,d0
  move.w    d0,(a1)
  move.w    d3,d1
  add.w     #12,d1
  move.w    d1,d0
  lsl.w     #8,d0
  btst      #8,d3
  beq.s     .a_no_vs8
  bset      #2,d0
.a_no_vs8:
  btst      #8,d1
  beq.s     .a_no_ve8
  bset      #1,d0
.a_no_ve8:
  tst.b     d2
  beq.s     .a_no_hs0
  bset      #0,d0
.a_no_hs0:
  move.w    d0,2(a1)
.next_alien:
  addq.l    #8,a0
  lea       64(a1),a1
  dbf       d4,.alien_loop
  move.w    (sp)+,d4                                     ; Restore starfield frame counter

  jmp       loop

  include   "copper.i"

; --- 16x16 Spaceship Sprite (2 bitplanes) ---
ShipSprite_ROM:
  dc.w      $0000,$0000                                  ; Control words (patched at runtime)
  dc.w      $0180,$0000                                  ; Line 0:  .......XX.......
  dc.w      $0180,$0180                                  ; Line 1:  .......XX.......
  dc.w      $03C0,$0180                                  ; Line 2:  ......XXXX......
  dc.w      $03C0,$03C0                                  ; Line 3:  ......XXXX......
  dc.w      $07E0,$03C0                                  ; Line 4:  .....XXXXXX.....
  dc.w      $07E0,$0240                                  ; Line 5:  .....XX..XX.....
  dc.w      $0FF0,$0660                                  ; Line 6:  ....XXXXXXXX....
  dc.w      $1FF8,$07E0                                  ; Line 7:  ...XXXXXXXXXX...
  dc.w      $3FFC,$0DB0                                  ; Line 8:  ..XXXXXXXXXXXX..
  dc.w      $7FFE,$1998                                  ; Line 9:  .XXXXXXXXXXXXXX.
  dc.w      $FFFF,$3C3C                                  ; Line 10: XXXXXXXXXXXXXXXX
  dc.w      $FFFF,$7E7E                                  ; Line 11: XXXXXXXXXXXXXXXX
  dc.w      $E7E7,$4242                                  ; Line 12: XXX..XXXXXX..XXX
  dc.w      $C3C3,$0000                                  ; Line 13: XX....XXXX....XX
  dc.w      $0000,$0660                                  ; Line 14: .....XX..XX..... (thruster)
  dc.w      $0000,$0240                                  ; Line 15: ......X..X...... (thruster)
  dc.w      $0000,$0000                                  ; End of sprite
ShipSprite_End:

; --- 16x5 Bullet Sprite (2 bitplanes) ---
BulletSprite_ROM:
  dc.w      $0000,$0000                                  ; Control words (patched at runtime)
  dc.w      $0180,$0180
  dc.w      $0180,$0180
  dc.w      $0180,$0180
  dc.w      $0180,$0180
  dc.w      $0180,$0180
  dc.w      $0000,$0000                                  ; End of sprite
BulletSprite_End:

; --- Initial Alien Positions (X, Y, VX) ---
AlienInit_ROM:
  dc.w      40,20,1
  dc.w      110,40,-1
  dc.w      190,20,1
  dc.w      260,40,-1

; --- 16x12 Alien Invader Sprite (2 bitplanes) ---
AlienSprite_ROM:
  dc.w      $0000,$0000                                  ; Control words (patched at runtime)
  dc.w      $0810,$0000                                  ; Line 0:  ....X......X....
  dc.w      $0420,$0000                                  ; Line 1:  .....X....X.....
  dc.w      $0FF0,$03C0                                  ; Line 2:  ....XXXXXXXX....
  dc.w      $1FF8,$0FF0                                  ; Line 3:  ...XXXXXXXXXX...
  dc.w      $3FFC,$1DB8                                  ; Line 4:  ..XXXXXXXXXXXX..
  dc.w      $7FFE,$3FFC                                  ; Line 5:  .XXXXXXXXXXXXXX.
  dc.w      $7FFE,$3C3C                                  ; Line 6:  .XXXXXXXXXXXXXX.
  dc.w      $5FFA,$1818                                  ; Line 7:  .X.XXXXXXXXXX.X.
  dc.w      $4812,$0000                                  ; Line 8:  .X..X......X..X.
  dc.w      $0420,$0000                                  ; Line 9:  .....X....X.....
  dc.w      $0240,$0000                                  ; Line 10: ......X..X......
  dc.w      $0000,$0000                                  ; Line 11: ................
  dc.w      $0000,$0000                                  ; End of sprite
AlienSprite_End: