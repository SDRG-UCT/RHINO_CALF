#RHINO Calf - GPMC IO
This calf covers communication both to and from the RHINO's ARM CPU and Xilinx FPGA using the General Purpose Memory Controller (GPMC) bus. Communication is abstracted in the operating system as memory-mapped IO files.

## BORPH Symbol Files
The symbol file is used to describe to BORPH the format of the code.
The format of the symbol file is:
```
[Name]	[Mode]	[Address]	[Size in Bytes]
```
* Name may be any ASCII single alphanumeric word that will identify the symbol in the OS.
* Mode may be:
```
	1 (Read-only)
	2 (Write-only)
	3 (Read-Write)
```
* Address is a 4 byte (i.e. 8 hexadecimal values) that identifies the symbol on the FPGA. Only bytes
* Size is the size of the symbol file in bytes.

## Communication Tutorial
1) Create the BORPH design with the appriopriate symbol file. See the [Programming calf](../programming/README.md) for more details on how to create the BORPH design. 

E.g. ```project_build gpmc_blinky gpmc_blinky``` 

The symbol file for [gpmc_blinky](./gpmc_blinky.sym):
```
VERSION 1  0x08000000 0x02
reg_led 2  0x08800000 0x02
reg_word 3 0x0900000 0x04
reg_file 3 0x09800000 0x7f
```
Where:

* The register `VERSION` is read-only and starts at address 0 and is two bytes in size. 
* `reg_led` is write-only, and starts at address 1, is also two bytes in size.
* `reg_word` is read-write, and starts at address 2, is four bytes in size.
* `reg_file` is read_write, and starts at address 3, and is 128 bytes in size.


2) Copy the BORPH design to the RHINO's CPU, and run it on the RHINO. 

e.g. ```./gpmc_blinky.bof```

3) Use `ps -A | grep [design name].bof` to find the process id (pid) of the design. The register files will be in `/proc/[pid of the design]/hw/ioreg/[Symbol Name]`.

e.g. ```
ps -A | grep gpmc_blinky.bof
  677 root     ./gpmc_blinky.bof

ls /proc/677/hw/ioreg/
VERSION	reg_led	reg_word	reg_file
```

4) To write to the files, use `echo -e -n "\x[byte 1]\x[byte 2]..\x[byte n] >> /proc/[design pid]/hw/ioreg/[Symbol name]".

e.g. ```
echo -e -n "\x01\x00" >> /proc/683/hw/ioreg/reg_led
``` 

5) To read from the symbols on the command line, use `cat /proc/[design pid]/hw/ioreg/[Symbol name] > [symbol_name.txt]`. Various terminals will vary in how these symbols are rendered.

e.g. ```
cat /proc/683/hw/ioreg/VERSION > VERSION.txt
```
