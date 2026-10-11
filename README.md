# X16 Open


## Using the Kernel

### Overview

The X16 open kernel is an open source operating system for the Commander X16.

It is built around these ideas:

- **Single user, single process.**
- **Everything is a file.** Devices are accessed through file handles,
  using `open`, `read`, `write`, `close`, and `ioctl`.
- **Drivers are modular.** The main drivers live in ROM and are
  registered at boot. Additional drivers can be loaded at runtime into
  low RAM or banked RAM.
- **The kernel is thin.** It dispatches calls to drivers, manages the
  file table, and provides a small number of primitives. Everything
  else is the driver's responsibility.


### Public API

The public API consists of the following functions.

|Function         |Address|Description                               |
|-----------------|-------|------------------------------------------|
|reset            |$c000  |System reset                              |
|alloc            |$c003  |Allocates one RAM bank (8 kB)             |
|free             |$c006  |Frees one RAM bank                        |
|device_register  |$c009  |Registers a new device driver             |
|device_unregister|$c00c  |Unregisters a device                      |
|file_open        |$c00f  |Opens a file                              |
|file_read_byte   |$c012  |Reads one byte from an opened file        |
|file_read_block  |$c015  |Reads a block of bytes from an opened file|
|file_read_all    |$c018  |Reads an entire file                      |
|file_write_byte  |$c01b  |Writes one byte to an opened file         |
|file_write_block |$c01e  |Writes a block of bytes to an opened file |
|file_write_all   |$c021  |Writes an entire file                     |
|file_seek        |$c024  |Seeks a position in an opened file        |
|file_position    |$c027  |Returns current position in an opened file|
|file_close       |$c02a  |Closes a file                             |
|file_ioctl       |$c02d  |Driver specific (control) commands        |
|stdin_read       |$c030  |Reads one byte from stdin                 |
|stdout_write     |$c033  |Writes one byte to stdout                 |
|get_ticks        |$c036  |Returns the jiffy clock                   |
|set_ticks        |$c039  |Sets the jiffy clock                      |
|get_errmsg       |$c03c  |Returns system error message              |
|set_errmsg       |$c03f  |Sets system error message                 |


The kernel's internal code and data structures are subject to change. 
Only the functions listed in this table are part of the stable interface.


### Passing and Returning Values

Arguments are passed to the kernel functions, and return values
are made available through the A, X, Y registers and eight zero page
registers (arg1-arg8).

arg1-arg8 are reserved for kernel calls and must not be used for
other purposes.


### Error Handling

All kernel functions set the carry flag if an error occur.

The error code is returned in the A register. A plain text error
message is also available, and can be retrieved through the get_errmsg
function.

List of error codes:

|Code  |Name                |Description                             |
|------|--------------------|----------------------------------------|
|0     |EOK                 |No error                                |
|1     |ENOMEM              |No free banked RAM                      |
|2     |EMEMINUSE           |Requested RAM bank already in use       |
|3     |ENODEVSPC           |No space for more devices               |
|4     |ENODEV              |Device does not exist                   |
|5     |EDEVBUSY            |Device is used and can't be altered     |
|6     |ENOFILESPC          |No space for more files                 |
|7     |ENOTFOUND           |File not found                          |
|8     |ENOTFILE            |Path is not a file                      |
|9     |ENOTDIR             |Path is not a directory                 |
|10    |ENOTOPEN            |File not open                           |
|11    |EINVAL              |Invalid operation                       |
|12    |EIO                 |Generic driver failure                  |
|13    |EEOF                |End of file                             |
|255   |ECUSTOM             |Custom error message                    |


### Function: reset

**Call address:** $c000<br>
**Input:** None<br>
**Output:** None<br>
**Error:** None

This function does a cold reset of the system. It is called when booting the computer, and
may also be called while using the computer.


### Function: alloc

**Call address:** $c003<br>
**Input:** A: Requested RAM bank index<br>
**Output:** A: Allocated RAM bank index<br>
**Errors:** ENOMEM, EMEMINUSE

The X16 has no hardware support for memory management.  The kernel's memory management functions 
(alloc and free) keep track of which parts of banked RAM are free to use. All well behaved
programs are expected to use these functions. These functions are needed especially as
the kernel allows for device drivers loaded into RAM.

If this function is called with A = 0, it will search for and allocate the next available
RAM bank. Error ENOMEM is set if there is no free memory.

If it is called with A > 0, the function will attempt to allocate the specified RAM bank.
Error EMEMINUSE is returned if that bank is already in use.

The allocated RAM bank is returned in the A register.


### Function: free

**Call address:** $c006<br>
**Input:** A: RAM bank index to free<br>
**Output:** None<br>
**Errors:** None

This function frees a RAM bank that previously was allocated with the alloc function.

RAM bank 0 is used by the system and may not be freed.


### Function: device_register

**Call address:** $c009<br>
**Input:** Y: Device ID, arg1-2: Pointer to start of driver, arg3: ROM/RAM bank<br>
**Output:** A: Device ID<br>
**Errors:** ENODEVSPC, EDEVBUSY, EIO

Registers a device driver that is already present in memory.

The following device drivers are embedded into the kernel source code, and are
registered automatically when booting the system:

0. X16 terminal driver
1. Generic I2C driver
2. PS/2 keyboard driver
3. PS/2 mouse driver
4. SNES game controller driver
5. SD card driver

If called with Y = 255, this function will use the first available device ID above 
the built-in drivers. Otherwise the function attempts to use the specified device ID.

The ENODEVSPC error is set if the driver table is full.

The EDEVBUSY error is returned if the device ID is already in use. In case
this happens you must first call device_unregister to free the driver currently 
connected to the device ID.

The driver may set an EIO error when calling during initialization.


### Function: device_unregister

**Call address:** $c00c<br>
**Input:** Y: Device ID<br>
**Output:** None<br>
**Errors:** EDEVBUSY

Unregisters the specified device driver.

The built-in device drivers (0-5) can't be unregistered. Also, you can't unregister
a device driver that is used by an open file.

The EDEVBUSY error is returned if the device is referenced by an open file.


### Function: file_open

**Call address:** $c00f<br>
**Input:** X: File handle, Y: Device driver ID, A: flags, arg1-2: File path<br>
**Output:** X: File handle, Y: Context ID <br>
**Errors:** ENOFILESPC, ENOTFOUND, ENOTFILE, EINVAL, EIO

Opens a file using the specified device driver.

If the X register is set to $ff, this function returns the next available file handle. Otherwise,
the functions attempt to use the specified file handle that must not already be in use.

The file is opened using the device driver specified in the Y register.

The following flags are supported:

- Bit 0: If set, the file is opened for reading
- Bit 1: If set, the file is opened for writing
- Bit 2: If set, the file is opened for appending

You must set exactly one flag. The kernel doesn't support opening a file
in multiple modes (or no mode).

Opening the file will fail if the device driver doesn't support 
the operations set in the flags argument.

The path must be a null-terminated string.

If successfully opened, the file is entered into the file table.

This function returns the file handle in the X register and the driver's file context in the
Y register. The context is managed by the driver, and is used by the driver to keep track
of multiple files opened at the same time.

The ENOFILESPC error is set if the file table is full. There can be at most 16 open files
at any given time.

The function fails with ENOTFOUND if the file is not found and with ENOTFILE if the specified
path is not a file. 

The function returns the EINVAL error if the device driver doesn't have the capability
requested in the flags argument. The same error is returned if not exactly one flag is set.

The EIO error is set by the driver.


### Function: file_read_byte

**Call address:** $c012<br>
**Input:** X: File handle<br>
**Output:** A: Byte value<br>
**Errors:** ENOTOPEN, EINVAL, EIO, EEOF

Reads one byte from the specified file.

The file must be opened for reading.

The ENOTOPEN error is returned if the specified file handle is not open.

The EINVAL error is set if the file is not opened for reading.

The EIO error is set by the driver.

EEOF is set if the read operation was attempted at end of file and 
no byte was produced. A successful read operation of the final byte does 
not return EEOF; the caller discovers EOF on the next read attempt.


### Function: file_read_block

**Call address:** $c015<br>
**Input:** X: file handle, arg1-2: requested number of bytes, arg3-4: address where to store data, arg5: bank where to store data<br>
**Output:** arg1-2: returned number of bytes<br>
**Errors:** ENOTOPEN, EINVAL, EIO, EEOF

Reads a block from the specified file.

This function reads at most the number of bytes supported by the device's block read function, which on this
system is usually not more than 512 bytes.

The file must be opened for reading.

The ENOTOPEN error is returned if the specified file handle is not open.

The EINVAL error is returned if the file is not opened for reading.

The EIO error is set by the driver.

EEOF is set if the read operation was attempted at end of file and 
no byte was produced. A successful read operation of the final byte does 
not return EEOF; the caller discovers EOF on the next read attempt.


### Function: file_read_all

**Call address:** $c018<br>
**Input:** X: file handle, arg3-4: address where to store data, arg5: bank where to store data<br>
**Output:** arg1-2: returned number of bytes<br>
**Errors:** ENOTOPEN, EINVAL, EIO, EEOF

Reads an entire file into RAM.

The file must be opened for reading.

The ENOTOPEN error is returned if the specified file handle is not open.

The EINVAL error is returned if the file is not opened for reading.

The EIO error is set by the driver.

EEOF is set if the read operation was attempted at end of file and 
no byte was produced. A successful read operation of the final byte does 
not return EEOF; the caller discovers EOF on the next read attempt.


### Function: file_write_byte

**Call address:** $c01b<br>
**Input:** X: File handle, arg1: Byte value<br>
**Output:** None<br>
**Errors:** ENOTOPEN, EINVAL, EIO

Writes one byte to the specified file.

The file must be opened for writing or appending.

The ENOTOPEN error is returned if the specified file handle is not open.

The EINVAL error is returned if the file is not opened for writing or appending.

The EIO error is set by the driver.


### Function: file_write_block

**Call address:** $c01e<br>
**Input:** X: File handle, arg1-2: Length of data, arg3-4: address where to get data, arg5: bank where to get data<br>
**Output:** arg1-2: Number of bytes written<br>
**Errors:** ENOTOPEN, EINVAL, EIO

Writes one block to the specified file.

This function writes at most the number of bytes supported by the device's block write function, which on this
system is usually not more than 512 bytes.

The file must be opened for writing or appending.

The ENOTOPEN error is returned if the specified file handle is not open.

The EINVAL error is returned if the file is not opened for writing or appending.

The EIO error is set by the driver.


### Function: file_write_all

**Call address:** $c021<br>
**Input:** X: File handle, arg1-2: Length of data, arg3-4: address where to get data, arg5: bank where to get data<br>
**Output:** None<br>
**Errors:** ENOTOPEN, EINVAL, EIO

Writes the entire address range to the specified file.

If the block is larger than the device's block write function, this function will call the device multiple times
until all data has been written to the file.

The file must be opened for writing or appending.

The ENOTOPEN error is returned if the specified file handle is not open.

The EINVAL error is returned if the file is not opened for writing or appending.

The EIO error is set by the driver.


### Function: file_seek

**Call address:** $c024<br>
**Input:** X: File handle, arg1-4: seek position<br>
**Output:** arg1-4: Current position<br>
**Errors:** ENOTOPEN, EINVAL, EIO

Moves to the requested position in the specified file.
Seeking is only supported on files opened for reading. Files opened for writing or appending 
are sequential streams: the write head advances only as data is written and cannot be 
repositioned. Attempting to seek on a file opened for writing or appending returns 
the EINVAL error.

The file position after this call is returned in arg1-4.

The ENOTOPEN error is returned if the specified file handle is not open.

The EIO error is set by the driver.


### Function: file_position

**Call address:** $c027<br>
**Input:** X: File handle<br>
**Output:** arg1-4: Current position<br>
**Errors:** ENOTOPEN, EIO

Returns the current position in the specified file. The file may be
opened for reading, writing, or appending.

The ENOTOPEN error is returned if the specified file is not open.

The EIO error is set by the driver.


### Function: file_close

**Call address:** $c02a<br>
**Input:** X: File handle<br>
**Output:** None<br>
**Errors:** None

Closes the specified file.

This function does not return an error even if the file is not open.


### Function: file_ioctl

**Call address:** $c02d<br>
**Input:** X: File handle, arg1: type, arg2:length, arg3-8: data<br>
**Output:** arg1-8: Driver and function specific

TODO...


### Function: stdin_read

**Call address:** $c030<br>
**Input:** None<br>
**Output:** A: Data<br>
**Errors:** ENOTOPEN, EINVAL, EIO, EEOF

Reads one byte from stdin (file #0).

File #0 must be opened for reading.

The ENOTOPEN error is returned if file handle #0 is not open.

The EINVAL error is returned if the file is not opened for reading.

The EIO error is set by the driver.

EEOF is set if the read operation was attempted at end of file and 
no byte was produced. A successful read operation of the final byte does 
not return EEOF; the caller discovers EOF on the next read attempt.


### Function: stdout_write

**Call address:** $c033<br>
**Input:** arg1: data<br>
**Output:** None<br>
**Errors:** ENOTOPEN, EINVAL, EIO

Writes one byte to stdout (file #1).

File #1 must be opened for writing or appending.

The ENOTOPEN error is returned if file handle #1 is not open.

The EINVAL error is returned if the file is not opened for writing or appending.

The EIO error is set by the driver.


### Function: get_ticks

**Call address:** $c036<br>
**Input:** None<br>
**Output:** arg1-3: Jiffy clock (low, middle, high)<br>
**Errors:** None

Returns the internal jiffy clock that is incremented on every
IRQ (once every 1/60 second).

The returned value is in the order low byte, middle byte, high byte (24 bits).


### Function: set_ticks

**Call address:** $c039<br>
**Input:** arg1-3: Clock setting<br>
**Output:** None<br>
**Errors:** None

Sets the internal jiffy clock that is incremented on every IRQ.

The input value is expected in the order low byte, middle byte, high byte (24 bits).


### Function: get_errmsg

**Call address:** $c03c<br>
**Input:** None<br>
**Output:** A: error code, arg1-2: Pointer to error message, arg3: Bank<br>
**Errors:** None

Returns an error code and a pointer to the last system error message.

A is 0 if no error message is available.

The error message is a null-terminated string.

The error message is cleared after calling this function.


### Function: set_errmsg

**Call address:** $c03f<br>
**Input:** A: Error code, arg1-2: Pointer to error message, arg3: Bank<br>
**Output:** None<br>
**Errors:** None

Sets a system error code and error message.

A = 0 is reserved for no error message.

The error message referred to by arg1-3 must be a null-terminated string.


## Making Device Drivers

### Overview

TODO...


### Kernal File Table

At the heart of the kernel's file system is a file table. The file table contains the following fields:

|Field name|Value|Description                                                            |
|----------|-----|-----------------------------------------------------------------------|
|driver ID |0-15 |The driver's index in the driver table.                                |
|context ID|0-255|An index identifying a file or other resource, maintained by the driver|
|flags     |0-255|See list of flags below                                                |

List of flags:

|Bit|Description                     |
|---|--------------------------------|
|0  |Set if file opened for reading  |
|1  |Set if file opened for writing  |
|2  |Set if file opened for appending|
|3-6|Reserved                        |
|7  |Set if file is open             |

## Device Table

Each open file is connected to a driver in the device table.

The device table has these fields:

|Field name|Value|Description                                |
|----------|-----|-------------------------------------------|
|addr_lo   |0-255|Address to start of driver, LSB            |
|addr_hi   |0-255|Address to start of driver, MSB            |
|bank      |0-255|Address to start of driver, RAM or ROM bank|
|flags     |0-255|See list of flags below                    |

List of flags:

|Bit|Description                              |
|---|-----------------------------------------|
|0-1|Driver location                          |
|2  |Set if block device, unset if char device|
|3  |Set if writeable                         |
|4  |Set if appendable                        |
|5  |Set if readable                          |
|6  |Set if seekable                          |
|7  |Reserved                                 |

The driver location bits are interpreted as follows:

|Bit value|Description                    |
|---------|-------------------------------|
|00       |Device not present             |
|01       |Stored in ROM bank 0 or low RAM|
|10       |Stored in ROM bank 1-255       |
|11       |Stored in RAM bank 0-255       |

