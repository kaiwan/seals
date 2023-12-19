SEALS
=====
SEALS is an abbreviation for _Simple Embedded ARM Linux System_.
It uses the powerful and FOSS *Qemu* (quick emulator!) to emulate a few target boards, helping us learn how to build a small (skeletal, really) embedded Linux system pretty muc from scratch!
<hr>

**NEW! (Oct 2023) : SEALS now supports:**<br>
- A simple GUI at startup to select the target machine to deploy<br>
- New machines (platforms)!<br>
    - the good 'ol PC (x86_64 or amd64)     [Dec 2023]<br>
    - the Raspberry Pi 3B (shows as the Compute Model 3 - CM3)

(Jan 2023): SEALS now supports both AArch32 and AArch64 platforms

The SEALS project consists of scripts that will enable you to build a simple
yet complete skeletal ARM\*/Linux system, emulated using the powerful [QEMU][2]
emulator. The SEALS scripts automate the following tasks:

- Using a simple ASCII text config file to precisely customize your environment
- Using a cross-compiler
- ARM\* / Linux kernel config and build
- Creating a skeletal root filesystem from scratch
- Integrating the components together, using QEMU (qemu-system-arm,
  particularly) to run the same in an emulated environment.

\*ARM can now be AArch32 or AArch64 platforms. <br>
From v0.3, SEALS also supports the x86_64 / amd64 PC platform (so it isn't strictly only 'ARM' now!)
<hr>

# Getting Started
Please, FIRST READ<br>
    - [the SEALS Getting Going! Tutorial](https://github.com/kaiwan/seals#a-very-brief-tutorial-on-getting-going-with-seals) <br>

Then, in the Wiki section, the:<br>
    - [SEAL's Wiki page - intro to SEALS][0], and <br>
    - [SEAL's HOWTO page][1] <br>
to better understand how to build and use this project.

*SEALS can prove very useful for developers / testers to prototype, try things out in a custom ARM/\*Linux or emulated x86 PC simple guest system.*
<hr>

## Install
- Clone this repository:<br>
`git clone https://github.com/kaiwan/seals.git`
- Run the `run_and_log` script.
<hr>

# A very brief tutorial on getting going with SEALS

I assume you're running in GUI mode (via Xorg or Xwayland).

 *Step 1.* Perform the git clone (as mentioned above)<br>

 *Step 2.* If you immediately run the `run_and_log` script, it typically results in an error, saying that the "staging, busybox and kernel source folders" aren't present.
This is typically the case when you start out.
<br>

***FAQ: Where are the staging and other folders designated?*** <br>
In the all-important **build config** file! <br>
This file is, by default, named `build.config` and is a symbolic (or soft) link to the `build.config.arm32_vexpress` build config file - to build and run the (emulated) ARM-32 Verstaile Express board!

    $ ls -l build.config
    lrwxrwxrwx. 1 kaiwan kaiwan 18 Dec 14 15:43 build.config -> build.config.arm32_vexpress

*It's very important to familiarize yourself with the board config files! Please browse through them, they're quite self-explanatory (with a lot of comments).*

Here's a snippet from the `build.config.arm32_vexpress` file showing how these folders are designated:

    STG=~/seals_staging/seals_staging_arm32
    ROOTFS=${STG}/rootfs
    IMAGES_FOLDER=${STG}/images
    IMAGES_BKP_FOLDER=${STG}/images_bkp
    CONFIGS_FOLDER=${STG}/configs

You're free to edit it... typically, just set the `STG` variable  to point to your staging location on your build host's disk, the rest follow under it... (In a similar fashion, the board config files use simple shell variables to designate various board attributes, the root fs and kernel stuff, and more; you must browse through them.

So, back to the setup. To fix possible errors the first time you run SEALS, install the busybox and kernel folders and their source trees **by running the `install.sh` script**; here's a screenshot:

![install script](tutorial_pics/install.png)

(The script detects and deletes old source if required).
When it's done, you should have the Linux busybox project and the Linux kernel source tree installed.
<br>

You can change the target board of course... by either manually updating the soft link, or, better, via our GUI! These are the 'prebuilt' target board config files we provide:<br>

    $ ls build.config*
    build.config@  build.config.amd64  build.config.arm32_vexpress  build.config.arm64_qemuvirt  build.config.arm64_rpi3b_cm3

The one that the `build.config` soft link points to is the current one, the one that will get built and run (via Qemu). You can even define your own board config files using these as a template! (of course, introducing new variables will require your editing the `build_SEALS.sh` script as well). When you do do this and it works, consider contributing it!

<br>

 *Step 3.* Run the `run_and_log` script. 
Now, *if you do NOT* have the staging, busybox and kernel source folders installed (*Step 2*), you'll get the following (or similar) error message (notice how it's both via the GUI and on the console (terminal window)):

![first time error](tutorial_pics/first-time-error.png)

(Hey, this is expected! Read it carefully; the project expects you to minimally setup a 'staging area' or work area (where the stuff gtes built at runtime) like this:<br>

<staging-dir\> <br>
   |--- linux-kernel-source-tree <br>
   |--- busybox-git-source-tree

).

Assuming these folders and the sources are in place (typically achived by running the `install.sh` script), all will be well and execution continues...
The `build_SEALS.sh` script is the primary script (invoked by the `run_and_log` script) and the first thing it does is show you the currently selected target platform, and allows you to change it via this gui:

![select target board](tutorial_pics/select_platform.png)

(TODO: A slight issue: when you select another board, the highlight bar still stays on the first one, but that's okay).

To go ahead with the current selection, simply press `Esc` here... Else, select another board by turning on it's radio button and thenclick on `Select`; a confirmation dialog pops up.
(TODO: the new target board selection procedure's only via the GUI currently; need to update the console mode for it as well).

  *Step 4.* You are now shown the currently selected target board configuration in detail (both via a gui dialog box and on the console):

![config review](tutorial_pics/platform-config-review-screen.png)

The config details are picked up from the `board.config.<foo>` file pertaining to the current board. 
This dialog allows you to review the current settings for it and decide if the current board config is fine; if your answer is:

  * Yes, it's fine: simply click the `Yes` button
  * No, I need to edit it: click the `No` button, and the script aborts. Edit the relevant `build.config.<foo>` file to your satisfaction, and then rerun the script.

*Step 5.* When happy with the state of the build config file, run the script:

After the 'usual' GUI dialogs, (the ones you've seen in the earlier steps), you will get the main menu GUI dialog:

![main menu](tutorial_pics/menu.png)

Read the (blue color) notes on top carefully. Go ahead and select whichever options you'd like SEALS to perform! Click on `OK` when done.<br>

Here's an example showing some selections made:

![main menu sample selection](tutorial_pics/menu-selected4.png)

***FAQ> What do the `Wipe kernel / busybox config (Careful!*)` options do?***<br>
Ans> Essentially, they have the underlying kbuild menu system to run it's `make ARCH=<whatever> defconfig` thus setting all config values to their default. So, it's typically useful to do this the first time you're performing the build. Once you've saved your won config, you can disable these toggles, thereby keeping your config (also, FYI, the config files, among others, can be saved / backed up (the second-to-last option).<br>
If running in console (non-gui, on a terminal window) mode, it still works and will interactively ask you to select what you want it to do.
<hr>
Perhaps it still generates errors. This could be due to missing packages (we only automate installation of required host packages on Ubuntu). More likely, the absence of the **cross toolchain** - specified in the board config file - is the issue (see the FAQ below).

<hr>

***FAQ> I'm getting errors regarding the toolchain*** <br>
Ans> The (cross) toolchain is a required component when using any of the ARM-based boards.
You'll have to install it on your build host (which can be a Linux VM, np). [The detailed documentation to do so is in the Wiki section](https://github.com/kaiwan/seals/wiki/SEALs-HOWTO).

<hr>

#Example screenshots
All are wrt the default build config platform, the ARM-32 Versatile Express:
(FYI, all carried out in an x86_64 Ubuntu 23.04 VirtualBox guest).

**Kernel Build Portion**:-

  * A screenshot showing a portion of the kernel build step, just before entering the kernel config:

![kernel build sample 1](tutorial_pics/k1.png)

  * A screenshot showing a portion of the kernel build step, the kernel config:
 
![kernel menuconfig sample](tutorial_pics/k2.png)

  * Some sample output while the kernel build just begins:

![kernel pre build sample](tutorial_pics/k3.png)

  * Some sample output while the kernel is building:
 
![kernel build sample](tutorial_pics/k4.png)

  * Some sample output after the kernel build is done:
 
![kernel after build sample](tutorial_pics/k5.png)

**Busybox (generates part of the target root fs: /bin, /sbin, /usr) config**:-

  * Some sample output of the Busybox config menu:
 
![bb config sample](tutorial_pics/bb1.png)

  * Some sample output of the Busybox completion:
 
![bb done sample](tutorial_pics/bb2.png)

  * Some sample output of the Busybox step, *root filesystem generation* by SEALS:
 
![bb rootfs sample](tutorial_pics/bb3.png)

**Sample output from the 'Generate Root Filesystem EXT4 image' menu** :

 
![gen ext4 image sample](tutorial_pics/gen_rootfs.png)

** Running it!** 

  * Some sample output just prior to running the AArch32 Vexpress target board under Qemu (notice the complete Qemu command line!):
 
![pre run sample](tutorial_pics/run1.png)

  * Some sample output when running the AArch32 Vexpress target board under Qemu (notice the kernel startup, all the kernel printk's being emitted as it boots...) :
 
![run sample](tutorial_pics/run2.png)

  * Some sample output running the AArch32 Vexpress target board under Qemu; once we reach our Busybox shell via (busybox) init :
 
![post run sample](tutorial_pics/run3.png)

  * Some sample output running the AArch32 Vexpress target board under Qemu; on the Busybox shell :
 
![post run sample 2](tutorial_pics/run4.png)

Excellent; we're running the ARM-32 Vexpress platform.
<hr>

***FAQ: Can I clean up everything (for the current board)?***

Yes! You can do so via the `cleanall` script; but **be CAREFUL**; it will ask for confimation and then delete stuff (via the typical `make clean` type of command for the source, and via `rm -rf ...` for the root fs, images, etc).

# Issues, Contribution
This project, like most FOSS ones, is ever-evolving... I urge you to not hesitate, to write in your comments, suggestions or anything.
Please do raise issues or bugs in the [Issues section of the GitHub repo](https://github.com/kaiwan/seals/issues).
Any contributions would be awesome (have a look at the current `Issues`)! I solicit your participation and help to make this project better!

[0]: https://github.com/kaiwan/seals/wiki 
[1]: https://github.com/kaiwan/seals/wiki/SEALs-HOWTO "SEALS HOWTO Page"
[2]: https://www.qemu.org/ "QEMU Homepage"
