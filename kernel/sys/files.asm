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

FILE_STDIN              = 0
FILE_STDOUT             = 1 
FILE_KEYBOARD           = 2
FILE_MOUSE              = 3
FILE_SNES               = 4
FILE_HANDLES_SPECIAL    = FILE_SNES+1
FILE_HANDLES_COUNT      = 16

FILE_FOR_READING        = 1
FILE_FOR_WRITING        = 2
FILE_IS_OPEN            = 128

; File table
ft_driver:      .res MAX_HANDLES   ; driver slot 0-15, or $FF for free
ft_context:     .res MAX_HANDLES   ; driver-defined context 0-255
ft_flags:       .res MAX_HANDLES   ; driver-defined flags

; *****************************************************************************
; Purpose...............: Opens a file
; Input.................: X     file handle or $ff to request any available
;                         Y     device/driver number
;                         r0    path, a null-terminated string (16 bit pointer)
;                         r1L   flags
; Output................: Y     context number
; Preparatory rutines...: None
; Errors................: C     set on error
;                         A     error code, 0 if no error
; Preserved registers...: None
; Credits...............: New implementation
.proc file_open
    ; Check if valid file handle
    cpx #FILE_HANDLES_COUNT
    bcc :+

    ; Check if X is $ff => allocate next available non-special handle
    cpx #$ff
    bne err0

    ldx #FILE_HANDLES_SPECIAL
    lda ft_flags,x
    bmi :+
    inx
    cpx #FILE_HANDLES_COUNT
    bcs err1

    ; Backup data
:   phy
    phx

    ; Call driver's open function
    ldx #DEVICE_OPEN
    jsr device_call
    bcs err2

    ; Update file table
    plx
    pla
    sta ft_driver,x
    lda r1
    ora #FILE_IS_OPEN
    sta ft_flags,x
    tya
    sta ft_context,x

    ; Exit successfully
    clc
    lda #0
    rts

err0:
    lda #0  ; Invalid file handle
    bra err

err1:
    lda #1  ; Too many files open
    bra err

err2:
    lda #2  ; Driver error

err:
    plx
    ply
    sec
    rts
.endproc

; *****************************************************************************
; Purpose...............: Closes a file
; Input.................: X file handle
; Output................: None
; Preparatory rutines...: Call file_open to open a file
; Errors................: C     set on error
;                         A     error code, 0 if no error
; Preserved registers...: None
; Credits...............: New implementation
.proc file_close
    ; Check if file handle is valid
    cpx #FILE_HANDLES_COUNT
    bcs err0
    
    ; Call driver's close function
    lda ft_driver,x     ; Get driver number
    tay
    lda ft_context,x    ; Get file context
    ldx #DEVICE_CLOSE
    jsr device_close    ; Call driver function
    bcs err1

    ; Exit successfully
    lda #0
    rts

err0:
    lda #0  ; Invalid file handle
    bra err

err1:
    lda #1  ; driver error

err:
    sec
    rts
.endproc

; *****************************************************************************
; Purpose...............: Duplicates a file table entry
; Input.................: X     New file handle
;                         Y     Old file handle to copy
; Output................: None
; Preparatory rutines...: Call file_open to open a file
; Errors................: C     Set on error
;                         A     Error code
; Preserved registers...: None
; Credits...............: New implementation
.proc file_dup
    ; Check if file handles are valid
    cpx #FILE_HANDLES_COUNT
    bcs err0
    cpy #FILE_HANDLES_COUNT
    bcs err0

    ; Verify that new file is closed
    lda ft_flags,x
    bmi err1

    ; Verify that old file is open
    lda ft_flags,y
    bpl err2

    ; Copy file table entry
    lda ft_driver,y
    sta ft_driver,x
    lda ft_context,y
    sta ft_context,x
    lda ft_flags,y
    sta ft_flags,x

    ; Exit successfully
    clc
    lda #0
    rts

err0:
    lda #0      ; Invalid file handle
    bra err
err1:
    lda #1      ; New file is open
    bra err
err2:
    lda #2      ; Old file is closed
err:
    sec
    rts
.endproc

; *****************************************************************************
; Purpose...............: Reads one byte from an open file
; Input.................: X     File handle
; Output................: A     Byte value
; Preparatory rutines...: Open a file with file_open
; Errors................: C     Set on error
;                         A     Error code
; Preserved registers...: None
; Credits...............: New implementation
.proc file_read_byte
    ; Verify that file handle is valid
    cpx #FILE_HANDLES_COUNT
    bcs err0

    ; Verify that file handle is open for reading
    lda file_flags
    and #FILE_IS_OPEN + FILE_FOR_READING
    cmp #FILE_IS_OPEN + FILE_FOR_READING
    bne err1

    ; Call driver's read_byte function
    lda ft_driver,x
    tay
    lda ft_context,x
    ldx #FILE_READ_BYTE
    jsr device_call
    bcs err2

    ; Exit successfully
    clc
    lda #0
    rts

err0:
    lda #0      ; Invalid file handle
    bra err
err1:
    lda #1      ; File closed or not opened for reading
    bra err
err2:
    lda #2      ; Driver error
err:
    sec
    rts
.endproc

; *****************************************************************************
; Purpose...............: 
; Input.................: None
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc file_read_block
.endproc

; *****************************************************************************
; Purpose...............: Writes a byte to an open file
; Input.................: X     File handle
;                         A     Byte value to write
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc file_write_byte
    ; Backup param
    pha

    ; Verify that file handle is valid
    cpx #FILE_HANDLE_COUNT
    bcs err0

    ; Verify that file is open for writing
    lda ft_flags,x
    and #FILE_IS_OPEN + FILE_FOR_WRITING
    cmp #FILE_IS_OPEN + FILE_FOR_WRITING
    bne err1

    ; Call driver's write_byte function
    lda ft_driver,x
    tay
    lda ft_context,x
    sta r0
    pla
    ldx #DEVICE_WRITE_BYTE
    jsr device_call
.endproc

; device_call (funcid, driver, context, data)

; *****************************************************************************
; Purpose...............: 
; Input.................: None
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc file_write_block
.endproc

; *****************************************************************************
; Purpose...............: 
; Input.................: None
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc file_seek
.endproc

; *****************************************************************************
; Purpose...............: 
; Input.................: None
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc file_ioct
.endproc

; File functions
;file_dup(fh, fh to duplicate)
;file_read(fh)
;file_write(fh, data)
;file_seek(fh, params)
;file_ioct(fh, params)
