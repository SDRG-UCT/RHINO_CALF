#RHINO Calf - Programming
This tutorial/building block covers the fundementals of programming the RHINO computing devices - the ARM CPU and the Xilinx FPGA.

## Programming the ARM CPU


## Programming the Xilinx FPGA
Follow the following steps:

1) Create the FPGA binary file from the FPGA design file(s) (i.e. [design name].[vhd,ucf] -> [design name].bin). Run the project_build script: `project_build [project name] [top module]`, 

e.g. In this directory run ```project_build blinky blinky```

2) Create the BORPH programming file from the FPGA binary file and the BORPH Symbol file (i.e. from [design name].[bin,sym] to [design name].bof). This should have already been created in this directory command by the [project_build](../bin/project_build) script.

3) Copy the BORPH file to the RHINO. To copy the design created: `scp [project name].bof root@[RHINO IP address]:/root/` 

e.g ```scp blinky.bof root@[RHINO IP address]:/root/```

4) Log into the RHINO Board using SSH: `ssh root@[RHINO IP address]`

5) Set the permissions of the BORPH file so that it can be executed. Use the following command `chmod +x [design name].bof`, 

e.g. ```chmod +x blinky.bof```

6) Run the design: `./[design_name].bof`! 

e.g. ```./blinky.bof```
