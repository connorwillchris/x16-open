.export device_init, device_call

.import terminal_dispatch
.import ps2kbd_dispatch

DEVICE_COUNT = 16           ; Devices 0-15
DEVICE_BUILTIN_COUNT = 5    ; Devices 0-4, can't be changed/unregistered

; ******************************************************************************
; All device drivers must implement a dispatch function that takes a driver
; function number in the X register and additional function arguments
; in the A register and the arg1-8 zero page registers. The dispatch function
; must be stored at the beginning of the memory reserved for the driver.
;
; All device drivers must support these functions accessible through the
; above-mentioned dispatch function:
;
; ------------------------------------------------------------------------------
; #     Name        Input               Output              On error
; ------------------------------------------------------------------------------
; 0     init        None                A:device ID         C=1, error code in A
;                                                           arg7-8:errmsg ptr

; 1     open        A:file handle       X:file handle       C=1, error code in A
;                   arg1-2:path         A:context           arg7-8:errmsg ptr
;
; 2     read_byte   A:context           A:value             C=1, error code in A
;                                                           arg7-8:errmsg ptr
; 
; 3     read_block  A:context           arg1-2:data len     C=1, error code in A
;                                       arg3-4:data ptr     arg7-8:errmsg ptr
;
; 4     write_byte  A:context           None                C=1, error code in A
;                   arg1:byte                               arg7-8:errmsg ptr
;
; 5     write_block A:context           arg1-2:bytes left   C=1, error code in A
;                   arg1-2:data len                         arg7-8:errmsg ptr
;                   arg3-4:data ptr
;
; 6     close       A:context           None                C=1, error code in A
;                                                           arg7-8:errmsg ptr
;
; 7     ioctl       A:context           arg1-8:custom       C=1, error code in A
;                   arg1-8:custom                           arg7-8:errmsg ptr
;
; 8     on_irq      None                None                C=1, error code in A
;                                                           arg7-8:errmsg ptr
; ******************************************************************************

DEVICE_INIT         = 0
DEVICE_OPEN         = 1
DEVICE_READ_BYTE    = 2
DEVICE_READ_BLOCK   = 3
DEVICE_WRITE_BYTE   = 4
DEVICE_WRITE_BLOCK  = 5
DEVICE_CLOSE        = 6
DEVICE_IOCTL        = 7
DEVICE_ON_IRQ       = 8

ptr = $22

.segment "K_LRAM"

dt_addr_lo: .res DEVICE_COUNT
dt_addr_hi: .res DEVICE_COUNT
dt_bank:    .res DEVICE_COUNT
dt_flags:   .res DEVICE_COUNT   ; 0-1: Location, 2: Char/Block device, 3: Writable, 4: Readable, 5: Seekable, 6-7: Reserved
                                ; Location: 0 = not present, 1 = ROM bank 0 or low RAM, 2 = ROM bank > 0, 3 = RAM bank

.CODE

; *****************************************************************************
; Purpose...............: First sets all devices not present, and then
;                         registers built-in device drivers that are always
;                         present, i.e.:
;                         0: Terminal driver
;                         1: I2C driver
;                         2: PS/2 keyboard driver
;                         3: PS/2 mouse driver
;                         4: SNES controller driver
;                         5: Built-in SD card driver
; Input.................: None
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc device_init
    ; Set all devices not present
    lda #0
    ldx #DEVICE_COUNT
:   sta dt_flags-1,x
    dex
    bne :-

    ; #0: Register terminal driver
    lda #<terminal_dispatch
    sta dt_addr_lo
    lda #>terminal_dispatch
    sta dt_addr_hi
    stz dt_bank
    lda #%00011001  ; In ROM bank 0, char device, writable, readable
    sta dt_flags

    ; #1: Register PS/2 keyboard driver
    lda #<ps2kbd_dispatch
    sta dt_addr_lo+1
    lda #>ps2kbd_dispatch
    sta dt_addr_hi+1
    stz dt_bank+1
    lda #%00010001  ; In ROM bank 0, char device, readable
    sta dt_flags+1

    ; #2: Register PS/2 mouse driver
    ; TODO...

    ; #3: Register SNES game controller driver
    ; TODO...

    ; #4: Register SD card driver
    ; TODO...
    
    rts
.endproc

; *****************************************************************************
; Purpose...............: Calls device driver function
; Input.................: X     Function number
;                         Y     Driver number
;                         A     Primary function argument
;                         p0-7  Additional function arguments
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc device_call
    pha
    lda dt_addr_lo,y
    sta ptr
    lda dt_addr_hi,y
    sta ptr+1
    lda dt_flags,y
    and #3 ; The flag register bits 0-1: 0=device not present, 1=Stored in ROM bank 0 or low RAM, 2=Stored in ROM bank>0, 3=Stored in RAM bank
    beq not_present
    cmp #2
    bcs banking_required

no_banking:
    pla
    jmp (ptr)

not_present:
    pla
    rts
    
banking_required:
    ; TODO: Not yet implemented ...
    pla
    rts
.endproc
