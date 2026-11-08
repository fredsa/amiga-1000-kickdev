BOOT_ROM_SIZE              EQU 256*1024 ; 256kB Kickstart ROM

KICKSTART_ADF_SIZE         EQU 880*1024 ; 880kB Kickstart Disk
KICKSTART_KICK_SECTOR_SIZE EQU 512

; Kickstart 1.0 - 1.3: 256kB $00fc0000 – $00ffffff
; Kickstart 2.0 - 3.1: 512kB $00f80000 – $00ffffff
  org       $fc0000

CUSTOM                     EQU $DFF000

START
  dc.w      $1111
    ; move.b  (a1),-(a0)
  jmp       begin
;    nop
;    nop
;    nop
;    nop

;   dc $4E71
;   dc $4E71
;   dc $4E71
;   dc $4E71
;   dc $4E71
;   dc $4E71
;   ds.w 7

begin:
  move.l    #CUSTOM,a6
loop:
  addq.w    #1,d0
  and.w     #$0fff,d0      ; keep 12 bit
  move.w    d0,$180(a6)    ; COLOR00
  jmp       loop

FILL                       equ KICKSTART_ADF_SIZE-KICKSTART_KICK_SECTOR_SIZE-(*-START)

  ;ds.b      BOOT_ROM_SIZE-(*-START)
  ds.b      FILL