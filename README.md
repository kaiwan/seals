SEALS
=====
SEALS is an abbreviation for _Simple Embedded ARM Linux System_.
It uses the powerful and FOSS *Qemu* (quick emulator!) to emulate a few target boards, helping us learn how to build a small (skeletal, really) embedded Linux system pretty muc from scratch!

**NEW! (Oct 2023) : SEALS now supports:**<br>
- A simple GUI at startup to select the target machine to deploy<br>
- New machines (platforms)!<br>
    - the good 'ol PC (x86_64 or amd64)     [Dec 2023]<br>
    - the Raspberry Pi 3B (shows as the Compute Model 3 - CM3)

(Jan 2023): SEALS now supports both AArch32 and AArch64 platforms

The SEALS project consists of scripts that will enable you to build a simple
yet complete skeletal ARM\*/Linux system, emulated using the powerful [QEMU][2]
emulator. The SEALS scripts automate the following tasks:

\*ARM can now be AArch32 or AArch64 platforms. <br>
From v0.3, SEALS also supports the x86_64 / amd64 PC platform (so it isn't strictly only 'ARM' now!)

- Using a simple ASCII text config file to precisely customize your environment
- Using a cross-compiler
- ARM\* / Linux kernel config and build
- Creating a skeletal root filesystem from scratch
- Integrating the components together, using QEMU (qemu-system-arm,
  particularly) to run the same in an emulated environment.
# Getting Started
**Please FIRST READ
    - the Tutorial below. <br>
Then, in the Wiki section, the:<br>
    - [SEAL's Wiki page - intro to SEALS][0], and <br>
    - [SEAL's HOWTO page][1] <br>
 to better understand how to build and use this project.**

Very useful for developers / testers to try things out in a custom ARM/Linux or emulated x86 PC simple guest system.

## Install
- Clone this repository
```shell
git clone https://github.com/kaiwan/seals.git
```
- Run the `run_and_log` script.

# A very brief tutorial on getting going with SEALS

I assume you're running in GUI mode (via Xorg or Xwayland).

 *Step 1.* Perform the git clone (as mentioned above)<br><br>

 *Step 2.* Run the `run_and_log` script. The first time, it's very likely you get the following (or similar) error message (notice how it's both via the GUI and on the console (terminal window)):

![first time error](tutorial_pics/first-time-error.png)

Hey, this is expected! Read it carefully; the project expects you to minimally setup a 'staging area' or work area (where the stuff gtes built at runtime) like this:<br>

<staging-dir\> <br>
   |--- linux-kernel-source-tree <br>
   |--- busybox-git-source-tree


*FAQ: Where are the staging and other folders designated?* <br>
In the all-important **build config** file! <br>
This file is, by default, named `build.config` and is a symbolic (or soft) link to the `build.config.arm32_vexpress` build config file - to build and run the (emulated) ARM-32 Verstaile Express board!

    $ ls -l build.config
    lrwxrwxrwx. 1 kaiwan kaiwan 18 Dec 14 15:43 build.config -> build.config.arm32_vexpress

*It's very important to familiarize yourself with the board config files! Please browse through them, they're quite self-explanatory (with a lot of comments).*

You can change the target board of course... by either manually updating the soft link, or, better,via our GUI! These are the 'prebuilt' target board config files we provide:<br>

    $ ls build.config*
    build.config@  build.config.amd64  build.config.arm32_vexpress  build.config.arm64_qemuvirt  build.config.arm64_rpi3b_cm3

The one that the `build.config` soft link points to is the current one, the one that will get built and run (via Qemu).

 *Step 3.* As the error text says, fix the issue, installing these folders and their source trees, by running the `install.sh` script; here's a screenshot:

![install script](tutorial_pics/install.png)

(The script detects and deletes old source if required).
When it's done, you should have the Linux busybox project and the Linux kernel source tree installed.

The `build_SEALS.sh` script is the primary script (invoked by the `run_and_log` script) and the first thing it does is show you the currently selected target platform, and allows you to change it via this gui:

![select target board](tutorial_pics/select_platform.png)

(TODO: A slight issue: when you select another board, the highlight bar still stays on the first one, but that's okay).

To go ahead with the current selection, simply press `Esc` here... Else, select another board and click the `Select` button; a confirmation dialog pops up.
(TODO: the new target board selection procedure's only via the GUI currently; need to update the console mode for it as well).

  *Step 4.* Now you are shown the currently selected target board configuration in detail (both via gui and console):

![config review](tutorial_pics/platform-config-review-screen.png)

The config details are picked up from the `board.config.<foo>` file pertaining to the board. 
This dialog allows you to review the current settings for it and decide if the current board config is fine; if your answer is:<br>
- Yes, it's fine: simply click the `Yes` button
- No, I need to edit it: click the `No` button; the script aborts, you must now edit the relevant `build.config.<foo>` file to your satisfaction, and then rerun the script.

*Step 5.* When happy with the state of the build config, run the script:

After the 'usual' GUI dialogs, (the ones you've seen in the earlier steps), you will get the main menu GUI dialog:

![main menu](tutorial_pics/menu.png)

Read the (blue color) notes on top carefully. Go ahead and select whichever options you'd like SEALS to perform! Click on `OK` when done.<br>

Here's an example showing some selections made:

![main menu sample selection](tutorial_pics/menu-selected4.png)

FAQ> What do the 'Wipe kernel / busybox config' options do?<br>
Ans> Essentially, they have the underlying kbuild menu system to run it's `make ARCH=<whatever> defconfig` thus setting all config values to their default. So, it's typically useful to do this the first time you're performing the build. Once you've saved your won config, you can disable these toggles, thereby keeping your config (also, FYI, the config files, among others, can be saved / backed up (the second-to-last option).<br>
If running in console (non-gui, on a terminal window) mode, it still works and will interactively ask you to select what you want it to do.

Perhaps it still generates errors. This could be due to missing packages (we only automate installation of required host packages on Ubuntu). More likely, the absence of the **cross toolchain** - specified in the board config file - is the issue (see the FAQ below).

**FAQ> I'm getting errors regarding the toolchain** <br>
Ans> The (cross) toolchain is a required component when using any of the ARM-based boards.
You'll have to install it on your build host (which can be a Linux VM, np). [The detailed documentation to do so is in the Wiki section](https://github.com/kaiwan/seals/wiki/SEALs-HOWTO).

# Issues, Contribution
This project, like most FOSS ones, is ever-evolving... I urge you to not hesitate, to write in your comments, suggestions or anything.
Please do raise issues or bugs in the [Issues section of the GitHub repo](https://github.com/kaiwan/seals/issues).
Any contributions would be awesome ! I solicit your participation and help to make this project better!

[0]: https://github.com/kaiwan/seals/wiki 
[1]: https://github.com/kaiwan/seals/wiki/SEALs-HOWTO "SEALS HOWTO Page"
[2]: https://www.qemu.org/ "QEMU Homepage"
