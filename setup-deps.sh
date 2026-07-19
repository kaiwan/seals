#!/bin/bash
# setup-deps.sh
# Install the Debian/Ubuntu host packages required to build & run the SEALS project.
#   https://github.com/kaiwan/seals
#
# Derived from what the SEALS scripts actually check/invoke:
#   - build_SEALS.sh : install_deb_pkgs(), check_deps_fatal(), check_installed_pkg()
#   - common.sh      : gui_init() (xdpyinfo, xrandr)
#   - install.sh     : git clone / wget of source trees
#
# NOTE: This installs HOST build deps only. It does NOT install the ARM/AArch64
#       cross toolchain -- see the note at the end. The distro's cross-gcc
#       packages are deliberately avoided by SEALS (incomplete sysroot).
#
# Usage:
#   ./setup-deps.sh           # core + GUI deps (default)
#   ./setup-deps.sh --no-gui  # skip yad/X11 helper deps (console mode, '-c', only)
#   ./setup-deps.sh --initrd  # also install initramfs-tools (x86_64/amd64 target)
#
# License: MIT (matches the SEALS project)

set -euo pipefail

GUI=1
INITRD=0
for arg in "$@"; do
	case "$arg" in
		--no-gui) GUI=0 ;;
		--initrd) INITRD=1 ;;
		-h|--help)
			grep -E '^# ' "$0" | sed 's/^# \{0,1\}//'
			exit 0 ;;
		*) echo "Unknown option: $arg (try --help)"; exit 1 ;;
	esac
done

# --- Sanity: Debian/Ubuntu only (this is the apt path) ---
if ! command -v apt >/dev/null 2>&1; then
	echo "*** This script targets Debian/Ubuntu (apt not found). Aborting. ***"
	echo "    On Fedora/RHEL install the equivalents: ncurses-devel, openssl-devel,"
	echo "    gmp-devel, libmpc-devel, elfutils-libelf-devel, bison, flex, bc, lzop,"
	echo "    yad, qemu-system-arm/aarch64, etc."
	exit 1
fi

# ---------------------------------------------------------------------------
# Package sets
# ---------------------------------------------------------------------------

# Core build/runtime deps.
#  build-essential : gcc, g++, make, libc-dev, dpkg-dev (supersedes bare 'make')
#  bison flex bc   : kernel build (parser/lexer/calc)
#  lzop            : required for some kernel image compression (e.g. i.MX6)
#  libncurses-dev  : kernel/busybox menuconfig UI
#  libssl-dev      : kernel crypto / module signing bits
#  libgmp3-dev
#  libmpc-dev      : (auto-installed by build_SEALS.sh too; harmless to pre-install)
#  libelf-dev      : kernel objtool / CONFIG_UNWINDER etc. (NOT checked by SEALS,
#                    but a modern 6.x kernel build fails without it)
#  cpio kmod       : initramfs packing / module tooling (implicit kernel-build deps)
#  e2fsprogs       : mkfs.ext4 (rootfs image); usually already present
#  lsb-release     : build_SEALS.sh greps lsb_release to detect Ubuntu/Debian
#  git wget        : install.sh fetches busybox (git) + kernel tarball (wget)
CORE_PKGS=(
	build-essential
	bison flex bc lzop
	libncurses-dev libssl-dev libgmp3-dev libmpc-dev libelf-dev
	cpio kmod
	e2fsprogs
	lsb-release
	git wget
)

# GUI-mode deps: yad (dialogs), xrandr (x11-xserver-utils), xdpyinfo (x11-utils).
# Only needed if you run build_SEALS.sh WITHOUT the '-c' (console) switch.
GUI_PKGS=(
	yad
	x11-utils
	x11-xserver-utils
)

# x86_64/amd64 target with USE_INITRAMFS=1 needs mkinitramfs.
INITRD_PKGS=(
	initramfs-tools
)

# QEMU: install all of these explicitly (user request). Package naming varies
# across Ubuntu/Debian releases, so we install them ONE BY ONE -- that way a
# name that doesn't exist on this release just warns instead of aborting the
# whole apt transaction (which is what 'apt install a b c' would do if any one
# name is invalid).
QEMU_CANDIDATES=(
	qemu-system-arm      # arm32
	qemu-system-arm64    # arm64 (some releases)
	qemu-system-aarch64  # arm64 (alt name on some releases)
	qemu-system-x86      # amd64 target
)

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

PKGS=( "${CORE_PKGS[@]}" )
[ "$GUI" -eq 1 ]    && PKGS+=( "${GUI_PKGS[@]}" )
[ "$INITRD" -eq 1 ] && PKGS+=( "${INITRD_PKGS[@]}" )

echo "[*] apt update ..."
sudo apt update

echo "[*] Installing core deps${GUI:+ (+GUI)} ..."
sudo apt install -y "${PKGS[@]}"

# QEMU: install each explicitly; skip (with a warning) any not in this archive.
echo "[*] Installing QEMU system emulators ..."
QEMU_OK=0
for p in "${QEMU_CANDIDATES[@]}"; do
	if sudo apt install -y "$p"; then
		QEMU_OK=1
	else
		echo "   -- '$p' not available on this release; skipping."
	fi
done
[ "$QEMU_OK" -eq 0 ] && echo "!! No qemu-system-* package installed -- install one manually."

# ---------------------------------------------------------------------------
# Verify the fatal-checked tools are now on PATH (mirrors check_deps_fatal)
# ---------------------------------------------------------------------------
echo
echo "[*] Verifying required tools ..."
MISSING=0
for t in make bison flex bc lzop mkfs.ext4 yad wget git; do
	if command -v "$t" >/dev/null 2>&1; then
		printf '   [ok]  %s\n' "$t"
	else
		printf '   [!!]  %s  (NOT found)\n' "$t"
		MISSING=1
	fi
done
# At least one qemu-system binary
if compgen -c | grep -q '^qemu-system-'; then
	printf '   [ok]  qemu-system-*\n'
else
	printf '   [!!]  qemu-system-*  (NOT found)\n'
	MISSING=1
fi

echo
if [ "$MISSING" -eq 0 ]; then
	echo "[+] All SEALS-checked host tools are present."
else
	echo "[!] Some tools are missing above -- resolve before running build_SEALS.sh."
fi

cat <<'EOF'

--------------------------------------------------------------------------
IMPORTANT: Cross toolchain is NOT installed by this script.
--------------------------------------------------------------------------
SEALS deliberately avoids the distro cross-gcc packages
(e.g. gcc-arm-linux-gnueabihf) because they often lack a complete sysroot,
which the rootfs step copies libraries from.

Install the matching Arm GNU toolchain instead, then point build.config at it:

    CXX=arm-none-linux-gnueabihf-
    CXX_LOC=~/tc/arm-gnu-toolchain-<ver>-x86_64-arm-none-linux-gnueabihf/bin

(The amd64/x86_64 target builds natively -- build-essential is enough there.)

Details: https://github.com/kaiwan/seals/wiki/SEALs-HOWTO
--------------------------------------------------------------------------
EOF
