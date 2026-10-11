rom_bank = 1


; *****************************************************************************
; Function name......: jsrfar
; Description........: Long call utility. Intended to be used between ROM
;                      banks only. Must be stored in low RAM.
; Input..............: Set target bank at target_bank+1 (8 bits)
;                      Set target address at target_call+1 (16 bits)
; Output.............: None
; Errors.............: None
; Preserved registers: None
; *****************************************************************************
.proc jsrfar
    ; Reserve one byte on stack, to be used for storing the current ROM bank
	php

    ; Backup registers and status
	php
	pha
	phx

    ; Get stack pointer
	tsx

    ; Store current ROM bank in the reserved stack byte
	lda rom_bank
	sta $0104,x

    ; Restore register
	plx

target_bank:
    ; Set target bank
    lda #$ff
    sta rom_bank

    ; Restore registers and status
	pla
	plp

target_call:
    ; Call target function
	jsr $ffff

    ; Backup registers and status
	php
	pha
	phx

    ; Get stack pointer
	tsx

    ; Restore ROM bank
	lda $0104,x
	sta rom_bank

    ; Copy status to reserved byte
	lda $0103,x
	sta $0104,x

    ; Restore registers and status
	plx
	pla
	plp
	plp

    ; Exit
	rts
.endproc
