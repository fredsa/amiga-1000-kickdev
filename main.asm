; Kickstart 1.0 - 1.3: 256KB $00fc0000 – $00ffffff
; Kickstart 2.0 - 3.1: 512KB $00f80000 – $00ffffff
BOOT_ROM_SIZE EQU 8*1024                    ; 256KB Kickstart ROM
  org       $fc0000

CUSTOM        EQU $DFF000

 jmp begin
;   nop
;   dc $4E71
;   dc $4E71
;   dc $4E71
;   dc $4E71
;   dc $4E71
;   dc $4E71
;   ds.w 7
    ;ds.b      BOOT_ROM_SIZE - (* - START) - 4*1024, $ff
    ;ds.b       4*1024, $ff

begin:
  move.l    #CUSTOM,a6
loop:
  addq.w    #1,d0
  and.w     #$0fff,d0                         ; keep 12 bit
  move.w    d0,$180(a6)                       ; COLOR00
  jmp       loop

  ds.b      BOOT_ROM_SIZE - (* - START), 0