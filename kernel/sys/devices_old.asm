DRIVER_COUNT    = 16

ptr = $02

; Device driver function offsets
DRIVER_FLAGS    = 0     ; Returns driver flags (0: Char/Block device, 1: Writable, 2: Readable, 3: Seekable, 4-7: Reserved)
DRIVER_ON_IRQ   = 3     ; Called by the kernel IRQ handler
DRIVER_INIT     = 6     ; Initializes the driver, called once on register/mount
DRIVER_NAME     = 9     ; Returns the device name as a null-terminated string, e.g. sd0 for the primary SD card
DRIVER_OPEN     = 12    ; Opens file
DRIVER_READ     = 15    ; Char devices: Reads one byte; Block devices: Reads one block
DRIVER_WRITE    = 18    ; Char devices: Writes one byte; Block devices: Writes one block
DRIVER_CLOSE    = 21    ; Closes file
DRIVER_CONTROL  = 24    ; Sends device-specific commands
DRIVER_GEOMETRY = 27    ; Only supported by block devices. Returns a struct holding the following information
                        ; Sector size       2 bytes

; Driver table fields
DRIVER_TABLE_LOCATION   = 0     ; 0: Not present, 1=ROM bank 0 or low RAM, 2=ROM bank > 0, 3=RAM bank
DRIVER_TABLE_ADDRESS    = 1
DRIVER_TABLE_BANK       = 3

; Device driver table
driver_table: 
    .res DRIVER_COUNT*4

; *****************************************************************************
; Function name......: driver_init
; Description........: Initializes the driver table
; Input..............: None
; Output.............: None
; Errors.............: None
; Preserved registers: None
; *****************************************************************************
.proc driver_init
    ; Set all drivers inactive
    ldx #0
    lda #0
:   sta driver_table,x
    inx
    inx
    inx
    inx
    cpx #DRIVER_COUNT*4
    bcc :-

    rts
.endproc

; *****************************************************************************
; Purpose...............: Calls the specified device driver function
; Input.................: X = Function ID
;                         Y = Device driver ID
; Output................: Varies depending on the specific function
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
    cmp #1
    bcs banking_required

no_banking:
    pla
    jmp (ptr)

not_present:
    pla
    rts
    
banking_required:
    pla
    ;... TODO ...
    jmp dispatch_ram_part

.endproc

; *****************************************************************************
; Function name......: driver_on_irq
; Description........: Calls the on_irq function of each active driver
; Input..............: None
; Output.............: None
; Errors.............: None
; Preserved registers: None
; *****************************************************************************
.proc driver_on_irq
    ldx #0

loop:
    phx
    lda driver_table,x
    beq next ; inactive

    lda driver_table+DRIVER_TABLE_ADDRESS,x
    sta ptr
    lda driver_table+DRIVER_TABLE_ADDRESS+1,x
    sta ptr
    lda driver_table+DRIVER_TABLE_BANK,x
    sta $01
    ldx #DRIVER_ON_IRQ

    jsr on_irq 

next:
    pla
    cmp DRIVER_COUNT*4
    bcs exit
    adc #4
    tax
    bra loop

on_irq:
    jmp (ptr,x)

exit:
    rts

.endproc

; RAM CODE
; Input: X = driver jump table function offset
