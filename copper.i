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
