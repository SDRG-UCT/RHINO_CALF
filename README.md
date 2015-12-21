# RHINO CALF
Set of basic tutorials/building blocks for using the RHINO platform and its features.

##Contributors
This repository contains contributions from the following:

1) [Gordon Inggs](mailto:gordon.e.inggs@ieee.org)

2) [Matthew Bridges](mailto:matthewbridges88@gmail.com)

3) [Lerato Mohapi](mailto:leratojeffrey.mohapi@gmail.com)

4) [Lekhobola Tsoeunyane](mailto:lekhobola@gmail.com)

## Requirements
The following is required to use these tutorials:

* RHINO board running BORPH Linux. See [SDRG BORPH fork](https://github.com/SDRG-UCT/borph_rhino)
* Host System with Ethernet link to RHINO board's ARM CPU ethernet interface (100 Mbps). Linux recommended.
* Host System with Xilinx ISE 14.7 installed. Download it [here](http://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/design-tools.html). You will also need a license for programming the RHINO's Xilinx Spartan 6 XC6SLX150T FPGA.

## Crash of Calves
Each calf covers aspect of functionality for the board. The directory structure of this repository mirrors the calves below. Each calf contains a README.md file which mirrors the corresponding page on the repository wiki.

### Programming Calf
This calf covers:
* Compiling code for the ARM CPU
* Programming the FPGA using the ARM CPU
See the [Programming Calf README](./programming/README.md) for more details.

### GPMC-IO Calf
This calf covers:
* Communicating from the ARM CPU to the FPGA using the General Purpose Memory Controller (GPMC) bus
* Communicating from the FPGA to the ARM CPU using the GPMC bus.

### Ethernet-IO Calf
This calf covers:
* Communicating from the FPGA to the host system using the 1Gbps Ethernet Interface
* Communiating from the host system to the FPGA using the 1Gbps Ethernet Interface

### FMC150-IO Calf
This calf covers:
* Using the FMC150 card's Analog-to-Digital Convertor (ADC) to sample analog waveforms
* Using the FMC150 card's Digital-to-Analog Converter (DAC) to produce analog waveforms
