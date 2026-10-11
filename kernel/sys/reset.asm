; *****************************************************************************
; Copyright 2026 Stefan Jakobsson
;
; Redistribution and use in source and binary forms, with or without 
; modification, are permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice, 
;    this list of conditions and the following disclaimer.
;
; 2. Redistributions in binary form must reproduce the above copyright notice, 
;    this list of conditions and the following disclaimer in the documentation 
;    and/or other materials provided with the distribution.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
; POSSIBILITY OF SUCH DAMAGE.
; *****************************************************************************

.include "io.inc"

.export on_reset

.import device_init, device_call
.import irq_init

.CODE

; *****************************************************************************
; Purpose...............: System reset function called by the vector at
;                         address $fffc
; Input.................: None
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc on_reset
    ; Disable interrupts
    sei

    ; Initialize interrupts
    jsr irq_init
    jsr device_init
    ldy #0 ; Device 0 = VERA
    ldx #0 ; Function: init
    jsr device_call
    
    stz VERA_ADDR_L
    lda #$b0
    sta VERA_ADDR_M
    lda #%00010001
    sta VERA_ADDR_H
    ldx #80
    ldy #$97
:   lda #32
    sta VERA_DATA0
    sty VERA_DATA0
    dex
    bne :-
    ldx #80
    inc VERA_ADDR_M
    stz VERA_ADDR_L
    lda VERA_ADDR_M
    cmp #$b0+60
    bcc :-

    stz VERA_ADDR_L
    lda #$b0
    sta VERA_ADDR_M
    
    lda #1
    sta VERA_DATA0

    cli

    ldx #255
:   phx

    ldy #0 ; Vera
    ldx #8 ; Write
    lda #02
    jsr device_call

    plx
    dex
    bne :-

:   bra :-
.endproc
