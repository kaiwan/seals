SEALS
~~~~~
SEALs = Simple Embedded ARM Linux System

Clone with:
git clone https://github.com/kaiwan/seals


The SEALs project consists of scripts that will enable one to build a simple
yet complete skeletal ARM/Linux system, emulated using the powerful QEMU
emulator. The SEALS scripts automate:
- using a simple ASCII text config file to precisely customize your environment
- using a cross-compiler
- ARM / Linux kernel config and build
- creating a skeletal root filesystem from scratch
- integrating the components together, using QEMU (qemu-system-arm,
  particularly) to run the same in an emulated environment.
 
Very useful for developers / testers to try things out in a custom ARM/Linux guest system.


GETTING STARTED with SEALS
~~~~~~~~~~~~~~~~~~~~~~~~~~
** Please FIRST READ the 'SEALs HOWTO' page [1] in the Wiki section to better
understand how to build and use this project. **

For the impatient: run the run_and_log wrapper script.

Do write in your comments, suggestions, whatever.
Contributing would be awesome !

Thanks!
Kaiwan.

[1] https://github.com/kaiwan/seals/wiki/SEALs-HOWTO
