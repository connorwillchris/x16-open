# X16 Open


## Using the Kernel

### Overview

The X16 open kernel is an open source alternative for the Commander X16.

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
|get_clock        |$c036  |Returns the jiffy clock                   |
|set_clock        |$c039  |Sets the jiffy clock                      |
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

All kernel functions sets the carry flag if an error occured.

The error code is returned in the A register. A plain text error
message is also available, and can be retrieved through the get_errmsg
function.

List of error kernal error codes:

|Code  |Name                |Description                             |
|------|--------------------|----------------------------------------|
|0     |EOK                 |No error                                |
|1     |ENOMEM              |No free banked RAM                      |
|2     |EMEMINUSE           |Requsted RAM bank already in use        |
|3     |ENODEVSPC           |No space for more devices               |
|4     |ENODEV              |Device does not exist                   |
|5     |EDEVBUSY            |Device is used and can't be altered     |
|6     |EDEVINVAL           |Invalid operation for the device        |
|8     |ENOFILESPC          |No space for more files                 |
|7     |ENOTFOUND           |File not found                          |
|8     |ENOTFILE            |Path is not a file                      |
|9     |ENOTDIR             |Path is not a directory                 |
|10    |EIO                 |Generic driver failure                  |


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
**Output:** A: Allocated RAM bank index
**Errors:** A: ENOMEM, EMENINUSE

The X16 has no hardware support for memory management.  The kernel's memory management functions 
(alloc and free) keep track of which parts of banked RAM are free to use. All well behaved
programs are expected to use these functions. These functions are needed especially as
the kernel allows for device drivers loaded into RAM.

If this function is called with A = 0, it will search for and allocate the next available
RAM bank. Error ENOMEM is raised if there is no free memory.

If it is called with A > 0, the function will attempt to allocate the specified RAM bank.
Error EMEMINUSE is raised if that bank is already in use.

The allocated RAM bank is returned in the A register.


### Function: free

**Call address:** $c006<br>
**Input:** A: RAM bank index to free<br>
**Output:** None

This function frees a RAM bank that previously was allocated with the alloc function.

RAM bank 0 is used by the system and may not be freed.


### Function: device_register

**Call address:** $c009<br>
**Input:** arg1-2: Pointer to start of driver, arg3: ROM/RAM bank<br>
**Output:** A: Device ID

Registers a device driver that is already present in memory.

The following device drivers are embedded into the kernel source code, and are
registered automatically when booting the system:

0. X16 terminal driver
1. Generic I2C driver
2. PS/2 keyboard driver
3. PS/2 mouse driver
4. SNES game controller driver
5. SD card driver

### Function: device_unregister

**Call address:** $c00c<br>
**Input:** Y: Device ID<br>
**Output:** None<br>

Unregisters the specified device driver.

The built-in device drivers (0-5) can't be unregistrered. Also, you can't unregister
a device driver that is used by an open file.

### Function: file_open

**Call address:** $c00f<br>
**Input:** X: File handle, Y: Device driver ID, A: flags, arg1-2: File path
**Output:** X: File handle, Y: Context ID

Opens a file using the specified device driver.

If the X register is set to $ff, this functions returns the next available file handle. Otherwise,
the functions attempts to use the specified file handle that must not already be in use.

The file is opened using the device driver specified in the Y register.

The following flags are supported:

- Bit 0: If set, the file is opened for reading
- Bit 1: If set, the file is opened for writing
- Bit 2: If set, the file is opened for appending

Opening the file will fail if the device driver doesn't support one or more of
the operations set in the flags argument. Bit 1 (for writing) is ignored if
bit 2 (for appending) is set.

If successfully opened, the file is entered into the file table.

This function returns the file handle in the X register and the driver's file context in the
Y register. The context is managed by the driver, and is used by the driver to keep track
of multiple files opened at the same time.


### Function: file_read_byte

**Call address:** $c012<br>
**Input:** X: File handle<br>
**Output:** A: Byte value

Reads one byte from the specified file.

The file must be openened for reading, and the connected driver must support read operations.

### Function: file_read_block

**Call address:** $c015<br>
**Input:** X: file handle, arg1-2: requested number of bytes, arg3-4: address where to store data, arg5: bank where to store data<br>
**Output:** arg1-2: returned number of bytes

Reads a block from the specified file.

This function reads at most the number of bytes supported by the device's block read function, which on this
system is usually not more than 512 bytes.

The file must be opened for reading, and the connected driver must support read operations.


### Function: file_read_all

**Call address:** $c018<br>
**Input:** X: file handle, arg3-4: address where to store data, arg5: bank where to store data<br>
**Output:** arg1-2: returned number of bytes

Reads an entire file into RAM.

The file must be opened for reading, and the connected driver must support read operations.


### Function: file_write_byte

**Call address:** $c01b<br>
**Input:** X: File handle, arg1: Byte value<br>
**Output:** None

Writes one byte to the specified file.

The file must be opened for writing or appending, and the connected driver must support write operations.


### Function: file_write_block

**Call address:** $c01e<br>
**Input:** X: File handle, arg1-2: Length of data, arg3-4: address where to get data, arg5: bank where to get data<br>
**Output:** arg1-2: Number of bytes written

Writes one block to the specified file.

This function writes at most the number of bytes supported by the device's block write function, which on this
system is usually not more than 512 bytes.

The file must be opened for writing or appending, and the connected driver must support write operations.


### Function: file_write_all

**Call address:** $c021<br>
**Input:** X: File handle, arg1-2: Length of data, arg3-4: address where to get data, arg5: bank where to get data<br>
**Output:** None

Writes the entire address range to the specified file.

If the block is larger than the device's block write function, this function will call the device multiple times
until all data has been written to the file.

The file must be opened for writing or appending, and the connected driver must support write operations.


### Function: file_seek

**Call address:** $c024<br>
**Input:** X: File handle, arg1-4: seek position<br>
**Output:** arg1-4: Current position

Moves to the requested position in the specified file.

The file must be opened for reading or appending.

The file position after this call is returned in arg1-4.


### Function: file_position

**Call address:** $c027<br>
**Input:** X: File handle<br>
**Output:** arg1-4: Current position

Returns the current position in the specified file.

The file must be open.


### Function: file_close

**Call address:** $c02a<br>
**Input:** X: File handle<br>
**Output:** None

Closes the specified file.


### Function:file_ioctl

**Call address:** $c02d<br>
**Input:** X: File handle, arg1: type, arg2:length, arg3-8: data<br>
**Output:** arg1-8: Driver and function specific

TODO...


### Function: stdin_read

**Call address:** $c030<br>
**Input:** None<br>
**Output:** A: Data

Reads on byte from stdout (file #0).

File #0 must be opened for reading, and the connected driver must support read operations.


### Function: stdout_write

**Call address:** $c033<br>
**Input:** arg1: data<br>
**Output:** None

Writes one byte to stdout (file #1).

File #1 must be opened for writing or appending, and the connected driver must support write
operations.


### Function: get_clock

**Call address:** $c036<br>
**Input:** None<br>
**Output:** arg1-3: Jiffy clock (low, middle, high)

Returns the internal jiffy clock that is incremented on every
IRQ (once every 1/60 second).

The returned value is in the order low byte, middle byte, high byte (24 bits).


### Function: set_clock

**Call address:** $c039<br>
**Input:** arg1-3: Clock setting<br>
**Output:** None

Sets the internal jiffy clock that is incremented on every IRQ.

The input value is expexted in the order low byte, middle byte, high byte (24 bits).


### Function: get_errmsg

**Call address:** $c03c<br>
**Input:** None
**Output:** A: error code, arg1-2: Pointer to error message, arg3: Bank<br>

Returns an error code and a pointer to the last system error message.

A is 0 if no error message is available.

The error message is a null-terminated string.

The error message is cleared after calling this function.


### Function: set_errmsg

**Call address:** $c03f<br>
**Input:** A: Error code, arg1-2: Pointer to error message, arg3: Bank<br>
**Output:** None

Sets a system error code and error message.

A = 0 is reserved for no error message.

The error message referred to be arg1-3 must be a null-terminated string.

TODO: A list of error codes...


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
|2-6|Reserved                        |
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

