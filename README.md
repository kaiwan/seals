SEALS
=====
SEALS is an abbreviation for _Simple Embedded ARM Linux System_. 

The SEALS project consists of scripts that will enable one to build a simple
yet complete skeletal ARM/Linux system, emulated using the powerful [QEMU][2]
emulator. The SEALS scripts automate the following tasks:

- Using a simple ASCII text config file to precisely customize your environment
- Using a cross-compiler
- ARM / Linux kernel config and build
- Creating a skeletal root filesystem from scratch
- Integrating the components together, using QEMU (qemu-system-arm,
  particularly) to run the same in an emulated environment.
# Getting Started
**Please FIRST READ the [SEAL's HOWTO page][1] in the Wiki section to better
understand how to build and use this project.**

Very useful for developers / testers to try things out in a custom ARM/Linux guest system.

## Install
- Clone this repository
```shell
git clone https://github.com/kaiwan/seals.git
```
- Run `run_and_log` script.

# Contribution
Do write in your comments, suggestions or anything.
Any contributions would be awesome !


[1]: https://github.com/kaiwan/seals/wiki/SEALs-HOWTO "SEALS HOWTO Page"
[2]: https://www.qemu.org/ "QEMU Homepage"
