#!/bin/bash
# It is designed to build Debian linux for Variscite imx8m-dart modules
# prepare host OS system:
#  sudo apt-get install binfmt-support qemu qemu-user-static debootstrap kpartx
#  sudo apt-get install lvm2 dosfstools gpart binutils git lib32ncurses5-dev python-m2crypto
#  sudo apt-get install gawk wget git-core diffstat unzip texinfo gcc-multilib build-essential chrpath socat libsdl1.2-dev
#  sudo apt-get install autoconf libtool libglib2.0-dev libarchive-dev
#  sudo apt-get install python-git xterm sed cvs subversion coreutils texi2html
#  sudo apt-get install docbook-utils python-pysqlite2 help2man make gcc g++ desktop-file-utils libgl1-mesa-dev
#  sudo apt-get install libglu1-mesa-dev mercurial automake groff curl lzop asciidoc u-boot-tools mtd-utils
#

# -e  Exit immediately if a command exits with a non-zero status.
set -e

SCRIPT_NAME=${0##*/}
readonly SCRIPT_VERSION="0.7"


#### Exports Variables ####
#### global variables ####
readonly ABSOLUTE_FILENAME=`readlink -e "$0"`
readonly ABSOLUTE_DIRECTORY=`dirname ${ABSOLUTE_FILENAME}`
readonly SCRIPT_POINT=${ABSOLUTE_DIRECTORY}
readonly SCRIPT_START_DATE=`date +%Y%m%d`
readonly LOOP_MAJOR=7

# default mirror
readonly DEF_DEBIAN_MIRROR="http://httpredir.debian.org/debian"
readonly DEB_RELEASE="buster"
readonly DEF_ROOTFS_TARBAR_NAME="rootfs.tar.gz"

## base paths
readonly DEF_BUILDENV="${ABSOLUTE_DIRECTORY}"
readonly DEF_SRC_DIR="${DEF_BUILDENV}/src"
readonly G_ROOTFS_DIR="${DEF_BUILDENV}/rootfs"
readonly G_TMP_DIR="${DEF_BUILDENV}/tmp"
readonly G_TOOLS_PATH="${DEF_BUILDENV}/toolchain"
readonly G_VARISCITE_PATH="${DEF_BUILDENV}/variscite"

## CROSS_COMPILER config and paths
readonly G_CROSS_COMPILER_64BIT_NAME="gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu"
readonly G_CROSS_COMPILER_ARCHIVE_64BIT="${G_CROSS_COMPILER_64BIT_NAME}.tar.xz"
readonly G_EXT_CROSS_64BIT_COMPILER_LINK="http://releases.linaro.org/components/toolchain/binaries/6.3-2017.05/aarch64-linux-gnu/${G_CROSS_COMPILER_ARCHIVE_64BIT}"
readonly G_CROSS_COMPILER_64BIT_PREFIX="aarch64-linux-gnu-"

readonly G_CROSS_COMPILER_32BIT_NAME="gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf"
readonly G_CROSS_COMPILER_ARCHIVE_32BIT="${G_CROSS_COMPILER_32BIT_NAME}.tar.xz"
readonly G_EXT_CROSS_32BIT_COMPILER_LINK="http://releases.linaro.org/components/toolchain/binaries/6.3-2017.05/arm-linux-gnueabihf/${G_CROSS_COMPILER_ARCHIVE_32BIT}"
readonly G_CROSS_COMPILER_32BIT_PREFIX="arm-linux-gnueabihf-"

readonly G_CROSS_COMPILER_JOPTION="-j 4"

############## user rootfs packages ##########
readonly G_USER_PACKAGES=""

export LC_ALL=C

#### Input params #####
PARAM_DEB_LOCAL_MIRROR="${DEF_DEBIAN_MIRROR}"
PARAM_OUTPUT_DIR="${DEF_BUILDENV}/output"
PARAM_DEBUG="0"
PARAM_CMD="all"
PARAM_BLOCK_DEVICE="na"
### usage ###
function usage() {
	echo "This program version ${SCRIPT_VERSION}"
	echo " Used for make debian(${DEB_RELEASE}) image for ${MACHINE}  board"
	echo " and create booted sdcard"
	echo ""
	echo "Usage:"
	echo " MACHINE=<imx8m-var-dart|imx8mm-var-dart|imx8qxp-var-som|imx6ul-var-dart|var-som-mx6|var-som-mx7> ./${SCRIPT_NAME} options"
	echo ""
	echo "Options:"
	echo "  -h|--help   -- print this help"
	echo "  -c|--cmd <command>"
	echo "     Supported commands:"
	echo "       deploy      -- prepare environment for all commands"
	echo "       all         -- build or rebuild kernel/bootloader/rootfs"
	echo "       bootloader  -- build or rebuild bootloader (u-boot+SPL)"
	echo "       kernel      -- build or rebuild linux kernel for this board"
	echo "       modules     -- build or rebuild linux kernel modules and install in rootfs directory for this board"
	echo "       rootfs      -- build or rebuild debian rootfs filesystem (includes: make debian apks, make and install kernel moduled,"
	echo "                       make and install extern modules (wifi/bt), create rootfs.tar.gz)"
	echo "       rtar        -- generate or regenerate rootfs.tar.gz image from rootfs folder "
	echo "       clean       -- clean all build artifacts (not delete sources code and resulted images (output folder))"
	echo "       sdcard      -- create bootting sdcard for this device"
	echo "  -o|--output -- custom select output directory (default: \"${PARAM_OUTPUT_DIR}\")"
	echo "  -d|--dev    -- select sdcard device (exmple: -d /dev/sde)"
	echo "  --debug     -- enable debug mode for this script"
	echo "Examples of use:"
	echo "  make only linux kernel for board: sudo ./${SCRIPT_NAME} --cmd kernel"
	echo "  make only rootfs for board:       sudo ./${SCRIPT_NAME} --cmd rootfs"
	echo "  create boot sdcard:               sudo ./${SCRIPT_NAME} --cmd sdcard --dev /dev/sdX"
	echo "  deploy and build:                 ./${SCRIPT_NAME} --cmd deploy && sudo ./${SCRIPT_NAME} --cmd all"
	echo ""
}

source variscite/${MACHINE}/${MACHINE}.sh
if [ "${ARCH_CPU}" = "64BIT" ]; then
	G_CROSS_COMPILER_NAME=${G_CROSS_COMPILER_64BIT_NAME}
	G_EXT_CROSS_COMPILER_LINK=${G_EXT_CROSS_64BIT_COMPILER_LINK}
	G_CROSS_COMPILER_ARCHIVE=${G_CROSS_COMPILER_ARCHIVE_64BIT}
	G_CROSS_COMPILER_PREFIX=${G_CROSS_COMPILER_64BIT_PREFIX}
	ARCH_ARGS="arm64"
	BUILD_IMAGE_TYPE="Image.gz"
	KERNEL_BOOT_IMAGE_SRC="arch/arm64/boot/"
	KERNEL_DTB_IMAGE_PATH="arch/arm64/boot/dts/freescale/"
elif [ "${ARCH_CPU}" = "32BIT" ]; then
	G_CROSS_COMPILER_NAME=${G_CROSS_COMPILER_32BIT_NAME}
	G_EXT_CROSS_COMPILER_LINK=${G_EXT_CROSS_32BIT_COMPILER_LINK}
	G_CROSS_COMPILER_ARCHIVE=${G_CROSS_COMPILER_ARCHIVE_32BIT}
	G_CROSS_COMPILER_PREFIX=${G_CROSS_COMPILER_32BIT_PREFIX}
	ARCH_ARGS="arm"
else
	echo " Error unknown CPU type"
	exit 1
fi

G_CROSS_COMPILER_PATH="${G_TOOLS_PATH}/${G_CROSS_COMPILER_NAME}/bin"

echo "====Build Summary===="
echo "Building Debian ${DEB_RELEASE}  for ${MACHINE}"
echo "Kernel Config :	${G_LINUX_KERNEL_DEF_CONFIG}"
echo "Kernel DTB    : 	${G_LINUX_DTB}"
echo "Uboot Config  :  	${G_UBOOT_DEF_CONFIG_MMC}"

###### parse input arguments ##
readonly SHORTOPTS="c:o:d:h"
readonly LONGOPTS="cmd:,output:,dev:,help,debug"

ARGS=$(getopt -s bash --options ${SHORTOPTS}  \
  --longoptions ${LONGOPTS} --name ${SCRIPT_NAME} -- "$@" )

eval set -- "$ARGS"

while true; do
	case $1 in
		-c|--cmd ) # script command
			shift
			PARAM_CMD="$1";
			;;
		-o|--output ) # select output dir
			shift
			PARAM_OUTPUT_DIR="$1";
			;;
		-d|--dev ) # block device (for create sdcard)
			shift
			[ -e ${1} ] && {
				PARAM_BLOCK_DEVICE=${1};
			};
			;;
		--debug ) # enable debug
			PARAM_DEBUG=1;
			;;
		-h|--help ) # get help
			usage
			exit 0;
			;;
		-- )
			shift
			break
			;;
		* )
			shift
			break
			;;
	esac
	shift
done

## enable tarce options in debug mode
[ "${PARAM_DEBUG}" = "1" ] && {
	echo "Debug mode enabled!"
	set -x
};

if [ -d ${G_VARISCITE_PATH}/${MACHINE} ]; then
	echo "Building Debian for MACHINE ${MACHINE}"
else
	echo "Missing custom files for MACHINE ${MACHINE}"
	exit 1
fi

## declarate dinamic variables ##
readonly G_ROOTFS_TARBAR_PATH="${PARAM_OUTPUT_DIR}/${DEF_ROOTFS_TARBAR_NAME}"

###### local functions ######

### printing functions ###

# print error message
# $1 - printing string
function pr_error() {
	echo "E: $1"
}

# print warning message
# $1 - printing string
function pr_warning() {
	echo "W: $1"
}

# print info message
# $1 - printing string
function pr_info() {
	echo "I: $1"
}

# print debug message
# $1 - printing string
function pr_debug() {
	echo "D: $1"
}

### work functions ###

# get sources from git repository
# $1 - git repository
# $2 - branch name
# $3 - output dir
# $4 - commit id
function get_git_src() {
	# clone src code
	git clone ${1} -b ${2} ${3}
	cd ${3}
	git reset --hard ${4}
	RET=$?
	cd -
	return $RET
}

# get remote file
# $1 - remote file
# $2 - local file
function get_remote_file() {
	# download remote file
	wget -c ${1} -O ${2}
	return $?
}

function make_prepare() {
	if [ "${MACHINE}" = "var-som-mx6" ]; then
		mkdir -p ${DEF_SRC_DIR}/imx && :;
		mkdir -p ${DEF_SRC_DIR}/wilink8 && :;
	fi
## create src dir
	mkdir -p ${DEF_SRC_DIR} && :;

## create toolchain dir
	mkdir -p ${G_TOOLS_PATH} && :;

## create rootfs dir
	mkdir -p ${G_ROOTFS_DIR} && :;

## create out dir
	mkdir -p ${PARAM_OUTPUT_DIR} && :;

## create tmp dir
	mkdir -p ${G_TMP_DIR} && :;
}

# unpack fsl package
# $1 - package
function unpack_imx_package() {
	cd ${DEF_SRC_DIR}/imx
	/bin/sh ${1} --auto-accept
	cd -
	return $?
}
# function generate rootfs in input dir
# $1 - rootfs base dir
function make_debian_rootfs() {
	local ROOTFS_BASE=$1

	pr_info "Make debian(${DEB_RELEASE}) rootfs start..."

## umount previus mounts (if fail)
	umount ${ROOTFS_BASE}/{sys,proc,dev/pts,dev} 2>/dev/null && :;

## clear rootfs dir
	rm -rf ${ROOTFS_BASE}/* && :;

	pr_info "rootfs: debootstrap"
	debootstrap --verbose --foreign --arch arm64 ${DEB_RELEASE} \
		${ROOTFS_BASE}/ ${PARAM_DEB_LOCAL_MIRROR}

## prepare qemu
	pr_info "rootfs: debootstrap in rootfs (second-stage)"
	cp /usr/bin/qemu-aarch64-static ${ROOTFS_BASE}/usr/bin/
	mount -o bind /proc ${ROOTFS_BASE}/proc
	mount -o bind /dev ${ROOTFS_BASE}/dev
	mount -o bind /dev/pts ${ROOTFS_BASE}/dev/pts
	mount -o bind /sys ${ROOTFS_BASE}/sys
	chroot $ROOTFS_BASE /debootstrap/debootstrap --second-stage

	# delete unused folder
	chroot $ROOTFS_BASE rm -rf  ${ROOTFS_BASE}/debootstrap

	pr_info "rootfs: generate default configs"
	mkdir -p ${ROOTFS_BASE}/etc/sudoers.d/
	echo "user ALL=(root) /usr/bin/apt-get, /usr/bin/dpkg, /usr/bin/vi, /sbin/reboot" > ${ROOTFS_BASE}/etc/sudoers.d/user
	chmod 0440 ${ROOTFS_BASE}/etc/sudoers.d/user
	mkdir -p ${ROOTFS_BASE}/srv/local-apt-repository

#imx-firmware
	cp -r ${G_VARISCITE_PATH}/deb/imx-firmware-${IMX_FIRMWARE_VERSION}/* \
		${ROOTFS_BASE}/srv/local-apt-repository
#cairo
	cp -r ${G_VARISCITE_PATH}/deb/cairo/* \
		${ROOTFS_BASE}/srv/local-apt-repository
#libdrm
	cp -r ${G_VARISCITE_PATH}/deb/libdrm/* \
		${ROOTFS_BASE}/srv/local-apt-repository
#waylandprotocols
	cp -r ${G_VARISCITE_PATH}/deb/waylandprotocols/* \
		${ROOTFS_BASE}/srv/local-apt-repository
#G2D_Packages
	if [ ! -z "${G2D_PACKAGE_DIR}" ]; then
		cp -r ${G_VARISCITE_PATH}/deb/${G2D_PACKAGE_DIR}/* \
		${ROOTFS_BASE}/srv/local-apt-repository
	fi
#Vivante GPU libraries
	if [ ! -z "${G_GPU_IMX_VIV_PACKAGE_DIR}" ]; then
		cp -r ${G_VARISCITE_PATH}/deb/${G_GPU_IMX_VIV_PACKAGE_DIR}/* \
		${ROOTFS_BASE}/srv/local-apt-repository
	fi
#imxcodec
	cp -r ${G_VARISCITE_PATH}/deb/imxcodec/* \
		${ROOTFS_BASE}/srv/local-apt-repository
#imxparser
	cp -r ${G_VARISCITE_PATH}/deb/imxparser/* \
		${ROOTFS_BASE}/srv/local-apt-repository
#imxvpuhantro
	cp -r ${G_VARISCITE_PATH}/deb/imxvpuhantro/* \
		${ROOTFS_BASE}/srv/local-apt-repository
#gstpluginsbad
	cp -r ${G_VARISCITE_PATH}/deb/gstpluginsbad/${GST_MM_VERSION}/* \
		${ROOTFS_BASE}/srv/local-apt-repository
#gstpluginsbase
	cp -r ${G_VARISCITE_PATH}/deb/gstpluginsbase/${GST_MM_VERSION}/* \
		${ROOTFS_BASE}/srv/local-apt-repository
#gstpluginsgood
	cp -r ${G_VARISCITE_PATH}/deb/gstpluginsgood/${GST_MM_VERSION}/* \
		${ROOTFS_BASE}/srv/local-apt-repository
#gstreamer
	cp -r ${G_VARISCITE_PATH}/deb/gstreamer/${GST_MM_VERSION}/* \
		${ROOTFS_BASE}/srv/local-apt-repository
#imx-vpuwrap
	cp -r ${G_VARISCITE_PATH}/deb/imxvpuwrap/* \
		${ROOTFS_BASE}/srv/local-apt-repository
#imxgstplugin
	cp -r ${G_VARISCITE_PATH}/deb/imxgstplugin/${GST_MM_VERSION}/* \
		${ROOTFS_BASE}/srv/local-apt-repository
#weston
	cp -r ${G_VARISCITE_PATH}/deb/weston/${WESTON_PACKAGE_DIR}/* \
		${ROOTFS_BASE}/srv/local-apt-repository

## added mirror to source list
echo "deb ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE} main contrib non-free
deb-src ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE} main contrib non-free
deb ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE}-backports main contrib non-free
deb-src ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE}-backports main contrib non-free
" > etc/apt/sources.list

## raise backports priority
echo "Package: *
Pin: release n=${DEB_RELEASE}-backports
Pin-Priority: 500
" > etc/apt/preferences.d/backports

## maximize local repo priority
echo "Package: *
Pin: origin ""
Pin-Priority: 1000
" > etc/apt/preferences.d/local

echo "
# /dev/mmcblk0p1  /boot           vfat    defaults        0       0
" > etc/fstab

echo "${MACHINE}" > etc/hostname

echo "auto lo
iface lo inet loopback
" > etc/network/interfaces

echo "
locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8
locales locales/default_environment_locale select en_US.UTF-8
console-common	console-data/keymap/policy	select	Select keymap from full list
keyboard-configuration keyboard-configuration/variant select 'English (US)'
openssh-server openssh-server/permit-root-login select true
" > debconf.set

	pr_info "rootfs: prepare install packages in rootfs"
## apt-get install without starting
cat > ${ROOTFS_BASE}/usr/sbin/policy-rc.d << EOF
#!/bin/sh
exit 101
EOF

chmod +x ${ROOTFS_BASE}/usr/sbin/policy-rc.d

## third packages stage
cat > third-stage << EOF
#!/bin/bash
# apply debconfig options
debconf-set-selections /debconf.set
rm -f /debconf.set


function protected_install() {
    local _name=\${1}
    local repeated_cnt=5;
    local RET_CODE=1;

    echo Installing \${_name}
    for (( c=0; c<\${repeated_cnt}; c++ ))
    do
        apt install -y \${_name} && {
            RET_CODE=0;
            break;
        };

        echo ""
        echo "###########################"
        echo "## Fix missing packages ###"
        echo "###########################"
        echo ""

        sleep 2;

        apt --fix-broken install -y && {
            RET_CODE=0;
            break;
        };
    done

    return \${RET_CODE}
}

# update packages and install base
apt-get update || apt-get upgrade

# local-apt-repository support
protected_install local-apt-repository

# update packages and install base
apt-get update || apt-get upgrade

protected_install locales
protected_install ntp
protected_install openssh-server
protected_install nfs-common

# packages required when flashing emmc
protected_install dosfstools

# fix config for sshd (permit root login)
sed -i -e 's/#PermitRootLogin.*/PermitRootLogin\tyes/g' /etc/ssh/sshd_config

# net-tools (ifconfig, etc.)
protected_install net-tools
protected_install network-manager

# sdma package
protected_install imx-firmware-sdma

# VPU package
protected_install imx-firmware-vpu

# epdc package
protected_install imx-firmware-epdc

# graphical packages
protected_install libdrm-vivante1
protected_install imx-gpu-viv-core
if [ ! -z "${G2DPACKAGE}" ]
then
	protected_install	${G2DPACKAGE}
fi
protected_install weston

# added alsa & gstreamer
protected_install alsa-utils
protected_install gstreamer1.0-alsa
protected_install gstreamer1.0-plugins-bad
protected_install gstreamer1.0-plugins-base
protected_install gstreamer1.0-plugins-base-apps
protected_install gstreamer1.0-plugins-ugly
protected_install gstreamer1.0-plugins-good
protected_install gstreamer1.0-tools
protected_install ${IMXGSTPLG}

# added i2c tools
protected_install i2c-tools

# added usb tools
protected_install usbutils

# added net tools
protected_install iperf

# mtd
protected_install mtd-utils

# bluetooth
protected_install bluetooth
protected_install bluez-obexd
protected_install bluez-tools
protected_install blueman
protected_install gconf2

# wifi support packages
protected_install hostapd
protected_install udhcpd

# can support
protected_install can-utils

apt-get -y autoremove

# create users and set password
useradd -m -G audio -s /bin/bash user
usermod -a -G video user
echo "user:user" | chpasswd
echo "root:root" | chpasswd

# sado kill
rm -f third-stage
EOF

	pr_info "rootfs: install selected debian packages (third-stage)"
	chmod +x third-stage
	chroot ${ROOTFS_BASE} /third-stage

## fourth-stage ##
### install variscite-bt service
	install -m 0755 ${G_VARISCITE_PATH}/brcm_patchram_plus \
		${ROOTFS_BASE}/usr/bin
	install -d -m 0755 ${ROOTFS_BASE}/etc/bluetooth
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/variscite-bt.conf \
		${ROOTFS_BASE}/etc/bluetooth
	install -m 0755 ${G_VARISCITE_PATH}/variscite-bt \
		${ROOTFS_BASE}/etc/bluetooth
	install -m 0644 ${G_VARISCITE_PATH}/variscite-bt.service \
		${ROOTFS_BASE}/lib/systemd/system
	ln -s /lib/systemd/system/variscite-bt.service \
		${ROOTFS_BASE}/etc/systemd/system/multi-user.target.wants/variscite-bt.service

### install variscite-wifi service
	install -d -m 0755 ${ROOTFS_BASE}/etc/wifi
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/blacklist.conf \
		${ROOTFS_BASE}/etc/wifi
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/variscite-wifi.conf \
		${ROOTFS_BASE}/etc/wifi
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/variscite-wifi-common.sh \
		${ROOTFS_BASE}/etc/wifi
	install -m 0755 ${G_VARISCITE_PATH}/variscite-wifi \
		${ROOTFS_BASE}/etc/wifi
	install -m 0644 ${G_VARISCITE_PATH}/variscite-wifi.service \
		${ROOTFS_BASE}/lib/systemd/system
	ln -s /lib/systemd/system/variscite-wifi.service \
		${ROOTFS_BASE}/etc/systemd/system/multi-user.target.wants/variscite-wifi.service

#install securetty
	install -m 0644 ${G_VARISCITE_PATH}/securetty \
		${ROOTFS_BASE}/etc/securetty

### install weston service
	install -d -m 0755 ${ROOTFS_BASE}/etc/xdg/weston
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/weston.ini \
		${ROOTFS_BASE}/etc/xdg/weston
	install -m 0755 ${G_VARISCITE_PATH}/${MACHINE}/weston.config \
		${ROOTFS_BASE}/etc/default/weston
	install -m 0755 ${G_VARISCITE_PATH}/weston-start \
		${ROOTFS_BASE}/usr/bin/weston-start
	install -m 0755 ${G_VARISCITE_PATH}/weston.profile \
		${ROOTFS_BASE}/etc/profile.d/weston.sh
	install -m 0644 ${G_VARISCITE_PATH}/weston.service \
		${ROOTFS_BASE}/lib/systemd/system
	ln -s /lib/systemd/system/weston.service \
		${ROOTFS_BASE}/etc/systemd/system/multi-user.target.wants/weston.service

## end packages stage ##
[ "${G_USER_PACKAGES}" != "" ] && {

	pr_info "rootfs: install user defined packages (user-stage)"
	pr_info "rootfs: G_USER_PACKAGES \"${G_USER_PACKAGES}\" "

echo "#!/bin/bash
# update packages
apt-get update
apt-get upgrade

# install all user packages
apt-get -y install ${G_USER_PACKAGES}

rm -f user-stage
" > user-stage

	chmod +x user-stage
	chroot ${ROOTFS_BASE} /user-stage

};

## binaries rootfs patching ##
	install -m 0644 ${G_VARISCITE_PATH}/issue ${ROOTFS_BASE}/etc/
	install -m 0644 ${G_VARISCITE_PATH}/issue.net ${ROOTFS_BASE}/etc/
	install -m 0755 ${G_VARISCITE_PATH}/rc.local ${ROOTFS_BASE}/etc/
	install -m 0644 ${G_VARISCITE_PATH}/splash.bmp ${ROOTFS_BASE}/boot/
	cp ${PARAM_OUTPUT_DIR}/Image.gz ${ROOTFS_BASE}/boot
	cp ${PARAM_OUTPUT_DIR}/*.dtb ${ROOTFS_BASE}/boot
	if [ "$DEFAULT_BOOT_DTB" != "$BOOT_DTB" ]; then
		ln -sf ${DEFAULT_BOOT_DTB} ${ROOTFS_BASE}/boot/${BOOT_DTB}
		if [ ! -z "${BOOT_DTB2}" ]; then
			ln -sf ${DEFAULT_BOOT_DTB2} \
				${ROOTFS_BASE}/boot/${BOOT_DTB2}
		fi
	fi

	mkdir -p ${ROOTFS_BASE}/usr/share/images/desktop-base/
	install -m 0644 ${G_VARISCITE_PATH}/wallpaper.png \
		${ROOTFS_BASE}/usr/share/images/desktop-base/default

## added alsa default configs ##
	install -m 0644 ${G_VARISCITE_PATH}/asound.state \
		${ROOTFS_BASE}/var/lib/alsa/
	install -m 0644 ${G_VARISCITE_PATH}/asound.conf ${ROOTFS_BASE}/etc/

## Revert regular booting
	rm -f ${ROOTFS_BASE}/usr/sbin/policy-rc.d

## install kernel modules in rootfs
	install_kernel_modules \
		${G_CROSS_COMPILER_PATH}/${G_CROSS_COMPILER_PREFIX} \
		${G_LINUX_KERNEL_DEF_CONFIG} ${G_LINUX_KERNEL_SRC_DIR} \
		${ROOTFS_BASE} || {
		pr_error "Failed #$? in function install_kernel_modules"
		return 2;
	}

## copy all kernel headers for development
	mkdir -p ${ROOTFS_BASE}/usr/local/src/linux-imx/drivers/staging/android/uapi
	cp ${G_LINUX_KERNEL_SRC_DIR}/drivers/staging/android/uapi/* \
	${ROOTFS_BASE}/usr/local/src/linux-imx/drivers/staging/android/uapi
	cp -r ${G_LINUX_KERNEL_SRC_DIR}/include \
		${ROOTFS_BASE}/usr/local/src/linux-imx/

## copy custom files
	cp ${G_VARISCITE_PATH}/fw_env.config ${ROOTFS_BASE}/etc
	cp ${PARAM_OUTPUT_DIR}/fw_printenv ${ROOTFS_BASE}/usr/bin
	ln -sf fw_printenv ${ROOTFS_BASE}/usr/bin/fw_setenv
	cp ${G_VARISCITE_PATH}/10-imx.rules ${ROOTFS_BASE}/etc/udev/rules.d
if [ "${MACHINE}" = "imx8m-var-dart" ]; then
	cp ${G_VARISCITE_PATH}/${MACHINE}/*.rules ${ROOTFS_BASE}/etc/udev/rules.d
fi

## clenup command
echo "#!/bin/bash
apt-get clean
rm -f cleanup
" > cleanup

	# clean all packages
	pr_info "rootfs: clean"
	chmod +x cleanup
	chroot ${ROOTFS_BASE} /cleanup
	umount ${ROOTFS_BASE}/{sys,proc,dev/pts,dev}

## kill latest dbus-daemon instance due to qemu-aarch64-static
	QEMU_PROC_ID=$(ps axf | grep dbus-daemon | grep qemu-aarch64-static | awk '{print $1}')
	if [ -n "$QEMU_PROC_ID" ]
	then
		kill -9 $QEMU_PROC_ID
	fi

	rm ${ROOTFS_BASE}/usr/bin/qemu-aarch64-static

	return 0;
}

# function generate rootfs in input dir
# $1 - rootfs base dir
function make_debian_rootfs_x11_common() {
	local ROOTFS_BASE=$1

	pr_info "Make debian(${DEB_RELEASE}) rootfs start..."

## umount previus mounts (if fail)
	umount ${ROOTFS_BASE}/{sys,proc,dev/pts,dev} 2>/dev/null && :;

## clear rootfs dir
	rm -rf ${ROOTFS_BASE}/* && :;

	pr_info "rootfs: debootstrap"
	debootstrap --verbose --foreign --arch armhf ${DEB_RELEASE} ${ROOTFS_BASE}/ ${PARAM_DEB_LOCAL_MIRROR}

## prepare qemu
	pr_info "rootfs: debootstrap in rootfs (second-stage)"
	cp /usr/bin/qemu-arm-static ${ROOTFS_BASE}/usr/bin/
	mount -o bind /proc ${ROOTFS_BASE}/proc
	mount -o bind /dev ${ROOTFS_BASE}/dev
	mount -o bind /dev/pts ${ROOTFS_BASE}/dev/pts
	mount -o bind /sys ${ROOTFS_BASE}/sys
	LANG=C chroot $ROOTFS_BASE /debootstrap/debootstrap --second-stage

	# delete unused folder
	LANG=C chroot $ROOTFS_BASE rm -rf  ${ROOTFS_BASE}/debootstrap

	pr_info "rootfs: generate default configs"
	mkdir -p ${ROOTFS_BASE}/etc/sudoers.d/
	echo "user ALL=(root) /usr/bin/apt-get, /usr/bin/dpkg, /usr/bin/vi, /sbin/reboot" > ${ROOTFS_BASE}/etc/sudoers.d/user
	chmod 0440 ${ROOTFS_BASE}/etc/sudoers.d/user

## added mirror to source list
echo "deb ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE} main contrib non-free
deb-src ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE} main contrib non-free
deb ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE}-backports main contrib non-free
deb-src ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE}-backports main contrib non-free
" > etc/apt/sources.list

## raise backports priority
echo "Package: *
Pin: release n=${DEB_RELEASE}-backports
Pin-Priority: 500
" > etc/apt/preferences.d/backports

echo "
# /dev/mmcblk0p1  /boot           vfat    defaults        0       0
" > etc/fstab

echo "${MACHINE}" > etc/hostname

echo "auto lo
iface lo inet loopback
" > etc/network/interfaces

echo "
locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8
locales locales/default_environment_locale select en_US.UTF-8
console-common	console-data/keymap/policy	select	Select keymap from full list
keyboard-configuration keyboard-configuration/variant select 'English (US)'
openssh-server openssh-server/permit-root-login select true
" > debconf.set

	pr_info "rootfs: prepare install packages in rootfs"
## apt-get install without starting
cat > ${ROOTFS_BASE}/usr/sbin/policy-rc.d << EOF
#!/bin/sh
exit 101
EOF

chmod +x ${ROOTFS_BASE}/usr/sbin/policy-rc.d

## third packages stage
cat > third-stage << EOF
#!/bin/bash
# apply debconfig options
debconf-set-selections /debconf.set
rm -f /debconf.set

function protected_install() {
    local _name=\${1}
    local repeated_cnt=5;
    local RET_CODE=1;

    for (( c=0; c<\${repeated_cnt}; c++ ))
    do
        apt-get install -y \${_name} && {
            RET_CODE=0;
            break;
        };

        echo ""
        echo "###########################"
        echo "## Fix missing packeges ###"
        echo "###########################"
        echo ""

        sleep 2;
    done

    return \${RET_CODE}
}


# update packages and install base
apt-get update || apt-get update

protected_install locales
protected_install ntp
protected_install openssh-server
protected_install nfs-common

# packages required when flashing emmc
protected_install dosfstools

# fix config for sshd (permit root login)
sed -i -e 's/#PermitRootLogin.*/PermitRootLogin\tyes/g' /etc/ssh/sshd_config


# sound mixer & volume
# xfce-mixer is not part of Stretch since the stable versionit depends on
# gstreamer-0.10, no longer used
# Stretch now uses PulseAudio and xfce4-pulseaudio-plugin is included in
# Xfce desktop and can be added to Xfce panels.
#protected_install xfce4-mixer
#protected_install xfce4-volumed

# network manager
#protected_install network-manager-gnome

# net-tools (ifconfig, etc.)
protected_install net-tools

protected_install udisk2
protected_install gvfs

protected_install gvfs-daemons


# enable graphical desktop
protected_install xorg
protected_install xfce4
protected_install xfce4-goodies

#network manager
protected_install network-manager-gnome

# net-tools (ifconfig, etc.)
protected_install net-tools

## fix lightdm config (added autologin x_user) ##
sed -i -e 's/\#autologin-user=/autologin-user=x_user/g' /etc/lightdm/lightdm.conf
sed -i -e 's/\#autologin-user-timeout=0/autologin-user-timeout=0/g' /etc/lightdm/lightdm.conf

# added alsa & alsa utilites
protected_install alsa-utils
protected_install gstreamer1.0-alsa

# added i2c tools
protected_install i2c-tools

# added usb tools
protected_install usbutils

# added net tools
protected_install iperf

protected_install rng-tools

#media
protected_install audacious
# protected_install parole

# mtd
protected_install mtd-utils

# bluetooth
protected_install bluetooth
protected_install bluez-obexd
protected_install bluez-tools
protected_install blueman
protected_install gconf2

# wifi support packages
protected_install hostapd
protected_install udhcpd

# can support
protected_install can-utils


# delete unused packages ##
apt-get -y remove xserver-xorg-video-ati
apt-get -y remove xserver-xorg-video-radeon

apt-get -y autoremove

# Remove foreign man pages and locales
rm -rf /usr/share/man/??
rm -rf /usr/share/man/??_*
rm -rf /var/cache/man/??
rm -rf /var/cache/man/??_*
(cd /usr/share/locale; ls | grep -v en_[GU] | xargs rm -rf)

# Remove document files
rm -rf /usr/share/doc

# create users and set password
useradd -m -G audio -s /bin/bash user
useradd -m -G audio -s /bin/bash x_user
usermod -a -G video user
usermod -a -G video x_user
echo "user:user" | chpasswd
echo "root:root" | chpasswd
passwd -d x_user

# sado kill
rm -f third-stage
EOF

	pr_info "rootfs: install selected debian packages (third-stage)"
	chmod +x third-stage
	LANG=C chroot ${ROOTFS_BASE} /third-stage

## end packages stage ##
[ "${G_USER_PACKAGES}" != "" ] && {

	pr_info "rootfs: install user defined packages (user-stage)"
	pr_info "rootfs: G_USER_PACKAGES \"${G_USER_PACKAGES}\" "

echo "#!/bin/bash
# update packages
apt-get update

# install all user packages
apt-get -y install ${G_USER_PACKAGES}

rm -f user-stage
" > user-stage

	chmod +x user-stage
	LANG=C chroot ${ROOTFS_BASE} /user-stage

};

## fourth-stage ##
	install_wifi_service
	install_bt_brcm
## binaries rootfs patching ##
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/issue ${ROOTFS_BASE}/etc/
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/issue.net ${ROOTFS_BASE}/etc/
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/hostapd.conf ${ROOTFS_BASE}/etc/
	install -m 0755 ${G_VARISCITE_PATH}/${MACHINE}/rc.local ${ROOTFS_BASE}/etc/
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/splash.bmp ${ROOTFS_BASE}/boot/

	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/wallpaper.png \
		${ROOTFS_BASE}/usr/share/images/desktop-base/default

## disable light-locker
	install -m 0755 ${G_VARISCITE_PATH}/${MACHINE}/disable-lightlocker ${ROOTFS_BASE}/usr/local/bin/
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/disable-lightlocker.desktop ${ROOTFS_BASE}/etc/xdg/autostart/

## added alsa default configs ##
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/asound.state ${ROOTFS_BASE}/var/lib/alsa/
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/asound.conf ${ROOTFS_BASE}/etc/

## Revert regular booting
	rm -f ${ROOTFS_BASE}/usr/sbin/policy-rc.d

## install kernel modules in rootfs
	install_kernel_modules ${G_CROSS_COMPILER_PATH}/${G_CROSS_COMPILER_PREFIX} ${G_LINUX_KERNEL_DEF_CONFIG} ${G_LINUX_KERNEL_SRC_DIR} ${ROOTFS_BASE} || {
		pr_error "Failed #$? in function install_kernel_modules"
		return 2;
	}

## copy custom files
	cp ${G_VARISCITE_PATH}/${MACHINE}/kobs-ng ${ROOTFS_BASE}/usr/bin
	cp ${G_VARISCITE_PATH}/${MACHINE}/fw_env.config ${ROOTFS_BASE}/etc
	cp ${PARAM_OUTPUT_DIR}/fw_printenv ${ROOTFS_BASE}/usr/bin
	ln -sf fw_printenv ${ROOTFS_BASE}/usr/bin/fw_setenv

	if [ "${MACHINE}" = "var-som-mx6" ]; then
		cp ${G_VARISCITE_PATH}/var-som-mx6/10-imx.rules ${ROOTFS_BASE}/etc/udev/rules.d
		cp ${G_VARISCITE_PATH}/var-som-mx6/chroot_script* ${ROOTFS_BASE}

		## install wl18xx stuff
		install_wl18xx_packages ${G_CROSS_COMPILER_PATH}/${G_CROSS_COMPILER_PREFIX}

		## copy imx sources to rootfs for native compilation
		install_imx_packages

		LANG=C LC_ALL=C chroot ${ROOTFS_BASE} /chroot_script_base.sh
		sleep 1; sync

		## install xorg libs
		LANG=C LC_ALL=C chroot ${ROOTFS_BASE} /chroot_script_patched-xorg-server.sh
		sleep 1; sync

		## install iMX GPU libs
		LANG=C LC_ALL=C chroot ${ROOTFS_BASE} /chroot_script_imx-gpu.sh
		sleep 1; sync

		### install vivante init scripts
		cp ${G_VARISCITE_PATH}/var-som-mx6/xorg.conf ${ROOTFS_BASE}/usr/share/X11/xorg.conf.d/90-vivante.conf
		install -m 0755 ${G_VARISCITE_PATH}/var-som-mx6/vivante ${ROOTFS_BASE}/etc/init.d/
		LANG=C chroot ${ROOTFS_BASE} update-rc.d vivante defaults
		install -m 0755 ${G_VARISCITE_PATH}/var-som-mx6/rc.autohdmi ${ROOTFS_BASE}/etc/init.d
		LANG=C chroot ${ROOTFS_BASE} update-rc.d rc.autohdmi defaults

		## install iMX VPU libs
		LANG=C LC_ALL=C chroot ${ROOTFS_BASE} /chroot_script_gst.sh
	fi
## clenup command
echo "#!/bin/bash
apt-get clean
rm -f cleanup
" > cleanup

	# clean all packages
	pr_info "rootfs: clean"
	chmod +x cleanup
	LANG=C chroot ${ROOTFS_BASE} /cleanup
	umount ${ROOTFS_BASE}/{sys,proc,dev/pts,dev}

## kill latest dbus-daemon instance due to qemu-arm-static
	QEMU_PROC_ID=$(ps axf | grep dbus-daemon | grep qemu-arm-static | awk '{print $1}')
	if [ -n "$QEMU_PROC_ID" ]
	then
		kill -9 $QEMU_PROC_ID
	fi

	rm ${ROOTFS_BASE}/usr/bin/qemu-arm-static
	if [ "${MACHINE}" = "var-som-mx6" ]; then
		rm ${ROOTFS_BASE}/chroot_script*
	fi
	rm -rf ${ROOTFS_BASE}/usr/local/src/*

	return 0;
}
# make tarbar arx from footfs
# $1 -- packet folder
# $2 -- output arx full name
function make_tarbar() {
	cd $1

	chown root:root .
	pr_info "make tarbar arx from folder ${1}"
	pr_info "Remove old arx $2"
	rm $2 > /dev/null 2>&1 && :;

	pr_info "Create $2"

	tar czf $2 .
	success=$?
	[ $success -eq 0 ] || {
	# fail
	    rm $2 > /dev/null 2>&1 && :;
	};

	cd -
}

# make linux kernel modules
# $1 -- cross compiler prefix
# $2 -- linux defconfig file
# $3 -- linux dtb files
# $4 -- linux dirname
# $5 -- out path
function make_kernel() {
	pr_info "make kernel .config"
	make ARCH=${ARCH_ARGS} CROSS_COMPILE=${1} ${G_CROSS_COMPILER_JOPTION} -C ${4}/ ${2}

	pr_info "make kernel"
	if [ ! -z "${UIMAGE_LOADADDR}" ]; then
		IMAGE_EXTRA_ARGS="LOADADDR=${UIMAGE_LOADADDR}"
	fi
	make CROSS_COMPILE=${1} ARCH=${ARCH_ARGS} ${G_CROSS_COMPILER_JOPTION} ${IMAGE_EXTRA_ARGS}\
			-C ${4}/ ${BUILD_IMAGE_TYPE}

	pr_info "make ${3}"
	make CROSS_COMPILE=${1} ARCH=${ARCH_ARGS} ${G_CROSS_COMPILER_JOPTION} -C ${4} ${3}

	pr_info "Copy kernel and dtb files to output dir: ${5}"
	cp ${4}/${KERNEL_BOOT_IMAGE_SRC}/${BUILD_IMAGE_TYPE} ${5}/;
	cp ${4}/${KERNEL_DTB_IMAGE_PATH}*.dtb ${5}/;

	return 0;
}

# clean kernel
# $1 -- linux dir path
function clean_kernel() {
	pr_info "Clean linux kernel"

	make ARCH=${ARCH_ARGS} -C ${1}/ mrproper

	return 0;
}

# make linux kernel modules
# $1 -- cross compiler prefix
# $2 -- linux defconfig file
# $3 -- linux dirname
# $4 -- out modules path
function make_kernel_modules() {
	pr_info "make kernel defconfig"
	make ARCH=${ARCH_ARGS} CROSS_COMPILE=${1} ${G_CROSS_COMPILER_JOPTION} -C ${3} ${2}

	pr_info "Compiling kernel modules"
	make ARCH=${ARCH_ARGS} CROSS_COMPILE=${1} ${G_CROSS_COMPILER_JOPTION} -C ${3} modules
}

# install linux kernel modules
# $1 -- cross compiler prefix
# $2 -- linux defconfig file
# $3 -- linux dirname
# $4 -- out modules path
function install_kernel_modules() {
	pr_info "Installing kernel headers to ${4}"
	make ARCH=${ARCH_ARGS} CROSS_COMPILE=${1} ${G_CROSS_COMPILER_JOPTION} -C ${3} INSTALL_HDR_PATH=${4}/usr/local headers_install

	pr_info "Installing kernel modules to ${4}"
	make ARCH=${ARCH_ARGS} CROSS_COMPILE=${1} ${G_CROSS_COMPILER_JOPTION} -C ${3} INSTALL_MOD_PATH=${4} modules_install

	return 0;
}

function install_wl18xx_packages() {
	local WL18XX_FW_DIR=${G_ROOTFS_DIR}/lib/firmware/ti-connectivity
	local WLCONF_DIR=${G_ROOTFS_DIR}/usr/sbin/wlconf

	mkdir -p ${WL18XX_FW_DIR}
	mkdir -p ${WLCONF_DIR}

	pr_info "Compiling wl18xx wlconf"
	make CC=${1}gcc ${G_CROSS_COMPILER_JOPTION} -C ${G_WILINK8_UTILS_SRC_DIR}/wlconf

	pr_info "Installing wl18xx bt firmware"
	cp ${G_WILINK8_FW_BT_SRC_DIR}/initscripts/TIInit_*.bts ${WL18XX_FW_DIR}
	
	pr_info "Installing wl18xx wifi firmware"
	cp ${G_WILINK8_FW_WIFI_SRC_DIR}/*.bin ${WL18XX_FW_DIR}
	cp ${G_VARISCITE_PATH}/wl1271-nvs.bin ${WL18XX_FW_DIR}

	pr_info "Installing wl18xx wlconf"
	cp ${G_WILINK8_UTILS_SRC_DIR}/wlconf/configure-device.sh ${WLCONF_DIR}
	cp ${G_WILINK8_UTILS_SRC_DIR}/wlconf/default.conf ${WLCONF_DIR}
	cp ${G_WILINK8_UTILS_SRC_DIR}/wlconf/dictionary.txt ${WLCONF_DIR}
	cp ${G_WILINK8_UTILS_SRC_DIR}/wlconf/example.* ${WLCONF_DIR}
	cp -r ${G_WILINK8_UTILS_SRC_DIR}/wlconf/official_inis ${WLCONF_DIR}
	cp ${G_WILINK8_UTILS_SRC_DIR}/wlconf/README ${WLCONF_DIR}
	cp ${G_WILINK8_UTILS_SRC_DIR}/wlconf/*.bin ${WLCONF_DIR}
	cp ${G_WILINK8_UTILS_SRC_DIR}/wlconf/wlconf ${WLCONF_DIR}
	cp ${G_WILINK8_UTILS_SRC_DIR}/wlconf/wl18xx-conf-default.bin ${WL18XX_FW_DIR}/wl18xx-conf.bin

	return 0;
}

function install_imx_packages() {
	local VPU_FW_DIR=${G_ROOTFS_DIR}/lib/firmware/vpu
	local IMX_DIR=${G_ROOTFS_DIR}/usr/local/src/imx
	local DEB_DIR=${G_ROOTFS_DIR}/usr/local/src/deb

	mkdir -p ${VPU_FW_DIR}
	mkdir -p ${IMX_DIR}
	mkdir -p ${DEB_DIR}

	pr_info "Installing vpu firmware"
	cp ${G_IMX_FW_LOCAL_DIR}/firmware/vpu/vpu_fw_imx6*.bin ${VPU_FW_DIR}

	cp -dr ${G_IMX_VPU_LOCAL_DIR} ${IMX_DIR}
	cp -dr ${G_IMX_CODEC_LOCAL_DIR} ${IMX_DIR}
	cp -dr ${G_IMX_GPU_G2D_LOCAL_DIR} ${IMX_DIR}
	cp -dr ${G_IMX_GPU_VIV_LOCAL_DIR} ${IMX_DIR}
	cp -dr ${G_IMX_XORG_DRV_SRC_DIR} ${IMX_DIR}
	cp -dr ${G_IMX_VPU_API_SRC_DIR} ${IMX_DIR}
	cp -dr ${G_IMX_GSTREAMER_SRC_DIR} ${IMX_DIR}
	cp -dr ${G_VARISCITE_PATH}/deb/* ${DEB_DIR}

	return 0;
}
# make uboot
# $1 uboot path
# $2 outputdir
function make_uboot() {
### make emmc uboot ###
	pr_info "Make SPL & u-boot: ${G_UBOOT_DEF_CONFIG_MMC}"
	# clean work directory
	make ARCH=${ARCH_ARGS} -C ${1} \
		CROSS_COMPILE=${G_CROSS_COMPILER_PATH}/${G_CROSS_COMPILER_PREFIX} \
		${G_CROSS_COMPILER_JOPTION} mrproper

	# make uboot config for mmc
	make ARCH=${ARCH_ARGS} -C ${1} \
		CROSS_COMPILE=${G_CROSS_COMPILER_PATH}/${G_CROSS_COMPILER_PREFIX} \
		${G_CROSS_COMPILER_JOPTION} ${G_UBOOT_DEF_CONFIG_MMC}

	# make uboot
	make -C ${1} \
		CROSS_COMPILE=${G_CROSS_COMPILER_PATH}/${G_CROSS_COMPILER_PREFIX} \
		${G_CROSS_COMPILER_JOPTION}

	# make fw_printenv
	make env -C ${1} \
		CROSS_COMPILE=${G_CROSS_COMPILER_PATH}/${G_CROSS_COMPILER_PREFIX} \
		${G_CROSS_COMPILER_JOPTION}
	make envtools -C ${1} \
		CROSS_COMPILE=${G_CROSS_COMPILER_PATH}/${G_CROSS_COMPILER_PREFIX} \
		${G_CROSS_COMPILER_JOPTION}

	if [ "${MACHINE}" = "imx8qxp-var-som" ]; then
		cp ${G_VARISCITE_PATH}/${MACHINE}/imx-boot-tools/scfw_tcm.bin \
			src/imx-mkimage/iMX8QX/
		cp ${G_VARISCITE_PATH}/${MACHINE}/imx-boot-tools/bl31-imx8qx.bin \
			src/imx-mkimage/iMX8QX/bl31.bin
		cp ${G_VARISCITE_PATH}/${MACHINE}/imx-boot-tools/mx8qx-ahab-container.img \
			src/imx-mkimage/iMX8QX/
		cp ${1}/u-boot.bin ${DEF_SRC_DIR}/imx-mkimage/iMX8QX/
		cd ${DEF_SRC_DIR}/imx-mkimage
		make SOC=iMX8QX flash
		cp ${DEF_SRC_DIR}/imx-mkimage/iMX8QX/flash.bin \
			${DEF_SRC_DIR}/imx-mkimage/${G_UBOOT_NAME_FOR_EMMC}
	# copy images
	cp ${G_UBOOT_NAME_FOR_EMMC} ${2}/${G_UBOOT_NAME_FOR_EMMC}

	cp ${1}/tools/env/fw_printenv ${2}
	elif [ "${MACHINE}" = "imx8m-var-dart" ]; then
		cp ${G_VARISCITE_PATH}/${MACHINE}/imx-boot-tools/bl31-imx8mq.bin \
			src/imx-mkimage/iMX8M/bl31.bin
		cp ${G_VARISCITE_PATH}/${MACHINE}/imx-boot-tools/signed_hdmi_imx8m.bin \
			src/imx-mkimage/iMX8M/signed_hdmi_imx8m.bin
		cp ${G_VARISCITE_PATH}/${MACHINE}/imx-boot-tools/lpddr4_pmu_train_1d_imem.bin \
			src/imx-mkimage/iMX8M/lpddr4_pmu_train_1d_imem.bin
		cp ${G_VARISCITE_PATH}/${MACHINE}/imx-boot-tools/lpddr4_pmu_train_1d_dmem.bin \
			src/imx-mkimage/iMX8M/lpddr4_pmu_train_1d_dmem.bin
		cp ${G_VARISCITE_PATH}/${MACHINE}/imx-boot-tools/lpddr4_pmu_train_2d_imem.bin \
			src/imx-mkimage/iMX8M/lpddr4_pmu_train_2d_imem.bin
		cp ${G_VARISCITE_PATH}/${MACHINE}/imx-boot-tools/lpddr4_pmu_train_2d_dmem.bin \
			src/imx-mkimage/iMX8M/lpddr4_pmu_train_2d_dmem.bin
		cp ${1}/u-boot.bin ${DEF_SRC_DIR}/imx-mkimage/iMX8M/
		cp ${1}/u-boot-nodtb.bin ${DEF_SRC_DIR}/imx-mkimage/iMX8M/
		cp ${1}/spl/u-boot-spl.bin ${DEF_SRC_DIR}/imx-mkimage/iMX8M/
		cp ${1}/arch/arm/dts/${UBOOT_DTB} ${DEF_SRC_DIR}/imx-mkimage/iMX8M/fsl-imx8mq-evk.dtb
		cp ${1}/tools/mkimage ${DEF_SRC_DIR}/imx-mkimage/iMX8M/mkimage_uboot
		cd ${DEF_SRC_DIR}/imx-mkimage
		make SOC=iMX8M flash_evk
		cp ${DEF_SRC_DIR}/imx-mkimage/iMX8M/flash.bin \
			${DEF_SRC_DIR}/imx-mkimage/${G_UBOOT_NAME_FOR_EMMC}
	# copy images
	cp ${G_UBOOT_NAME_FOR_EMMC} ${2}/${G_UBOOT_NAME_FOR_EMMC}

	cp ${1}/tools/env/fw_printenv ${2}
	elif [ "${MACHINE}" = "imx8mm-var-dart" ]; then
		cp ${G_VARISCITE_PATH}/${MACHINE}/imx-boot-tools/bl31-imx8mm.bin \
			src/imx-mkimage/iMX8M/bl31.bin
		cp ${G_VARISCITE_PATH}/${MACHINE}/imx-boot-tools/lpddr4_pmu_train_1d_imem.bin \
			src/imx-mkimage/iMX8M/lpddr4_pmu_train_1d_imem.bin
		cp ${G_VARISCITE_PATH}/${MACHINE}/imx-boot-tools/lpddr4_pmu_train_1d_dmem.bin \
			src/imx-mkimage/iMX8M/lpddr4_pmu_train_1d_dmem.bin
		cp ${G_VARISCITE_PATH}/${MACHINE}/imx-boot-tools/lpddr4_pmu_train_2d_imem.bin \
			src/imx-mkimage/iMX8M/lpddr4_pmu_train_2d_imem.bin
		cp ${G_VARISCITE_PATH}/${MACHINE}/imx-boot-tools/lpddr4_pmu_train_2d_dmem.bin \
			src/imx-mkimage/iMX8M/lpddr4_pmu_train_2d_dmem.bin
		cp ${1}/u-boot.bin ${DEF_SRC_DIR}/imx-mkimage/iMX8M/
		cp ${1}/u-boot-nodtb.bin ${DEF_SRC_DIR}/imx-mkimage/iMX8M/
		cp ${1}/spl/u-boot-spl.bin ${DEF_SRC_DIR}/imx-mkimage/iMX8M/
		cp ${1}/arch/arm/dts/${UBOOT_DTB} ${DEF_SRC_DIR}/imx-mkimage/iMX8M/fsl-imx8mm-evk.dtb
		cp ${1}/tools/mkimage ${DEF_SRC_DIR}/imx-mkimage/iMX8M/mkimage_uboot
		cd ${DEF_SRC_DIR}/imx-mkimage
		make SOC=iMX8MM flash_evk
		cp ${DEF_SRC_DIR}/imx-mkimage/iMX8M/flash.bin \
			${DEF_SRC_DIR}/imx-mkimage/${G_UBOOT_NAME_FOR_EMMC}
	# copy images
	cp ${G_UBOOT_NAME_FOR_EMMC} ${2}/${G_UBOOT_NAME_FOR_EMMC}

	cp ${1}/tools/env/fw_printenv ${2}
	elif [ "${MACHINE}" = "var-som-mx6" ] ||
		[ "${MACHINE}" = "imx6ul-var-dart" ] ||
		[ "${MACHINE}" = "var-som-mx7" ]; then
	
	# copy images
	cp ${1}/u-boot.img  ${2}/${G_UBOOT_NAME_FOR_EMMC}

	cp ${1}/tools/env/fw_printenv ${2}
	# copy images
	cp ${1}/SPL ${2}/${G_SPL_NAME_FOR_EMMC}
### make nand uboot ###
	pr_info "Make SPL & u-boot: ${G_UBOOT_DEF_CONFIG_NAND}"
	# clean work directory
	make ARCH=arm -C ${1} CROSS_COMPILE=${G_CROSS_COMPILER_PATH}/${G_CROSS_COMPILER_PREFIX} ${G_CROSS_COMPILER_JOPTION} mrproper

	# make uboot config for nand
	make ARCH=arm -C ${1} CROSS_COMPILE=${G_CROSS_COMPILER_PATH}/${G_CROSS_COMPILER_PREFIX} ${G_CROSS_COMPILER_JOPTION} ${G_UBOOT_DEF_CONFIG_NAND}

	# make uboot
	make ARCH=arm -C ${1} CROSS_COMPILE=${G_CROSS_COMPILER_PATH}/${G_CROSS_COMPILER_PREFIX} ${G_CROSS_COMPILER_JOPTION}

	# copy images
	cp ${1}/SPL ${2}/${G_SPL_NAME_FOR_NAND}
	cp ${1}/u-boot.img ${2}/${G_UBOOT_NAME_FOR_NAND}
		
	fi


	return 0;
}

# make *.ubi image from rootfs
# params:
#  $1 -- path to rootfs dir
#  $2 -- tmp dir
#  $3 -- output dir
#  $4 -- ubi file name
function make_ubi() {
	readonly local _rootfs=${1};
	readonly local _tmp=${2};
	readonly local _output=${3};
	readonly local _ubi_file_name=${4};

	readonly local UBI_CFG="${_tmp}/ubi.cfg"
	readonly local UBIFS_IMG="${_tmp}/rootfs.ubifs"
	readonly local UBI_IMG="${_output}/${_ubi_file_name}"

	# gnerate ubifs file
	pr_info "Generate ubi config file: ${UBI_CFG}"
cat > ${UBI_CFG} << EOF
[ubifs]
mode=ubi
image=${UBIFS_IMG}
vol_id=0
vol_type=dynamic
vol_name=rootfs
vol_flags=autoresize
EOF
	# delete previus images
	rm -f ${UBI_IMG} && :;
	rm -f ${UBIFS_IMG} && :;

	pr_info "Creating $UBIFS_IMG image"
	mkfs.ubifs -x zlib -m 2048  -e 124KiB -c 3965 -r ${_rootfs} $UBIFS_IMG

	pr_info "Creating $UBI_IMG image"
	ubinize -o ${UBI_IMG} -m 2048 -p 128KiB -s 2048 -O 2048 ${UBI_CFG}

	# delete unused file
	rm -f ${UBIFS_IMG} && :;
	rm -f ${UBI_CFG} && :;

	return 0;
}

# clean uboot
# $1 -- u-boot dir path
function clean_uboot() {
	pr_info "Clean uboot"

	make ARCH=${ARCH_ARGS} -C ${1}/ mrproper

	return 0;
}

# make sdcard for device
# $1 -- block device
function check_sdcard()
{
	# Check that parameter is a valid block device
	if [ ! -b "$1" ]; then
		pr_error "$1 is not a valid block device, exiting"
		return 1
	fi

	local dev=$(basename $1)

	# Check that /sys/block/$dev exists
	if [ ! -d /sys/block/$dev ]; then
		pr_error "Directory /sys/block/${dev} missing, exiting"
		return 1
	fi

	# Get device parameters
	local removable=$(cat /sys/block/${dev}/removable)
	local block_size=$(cat /sys/class/block/${dev}/queue/physical_block_size)
	local size_bytes=$((${block_size}*$(cat /sys/class/block/${dev}/size)))
	local size_gib=$(bc <<< "scale=1; ${size_bytes}/(1024*1024*1024)")

	# non removable SD card readers require additional check
	if [ "${removable}" != "1" ]; then
		local drive=$(udisksctl info -b /dev/${dev}|grep "Drive:"|cut -d"'" -f 2)
		local mediaremovable=$(gdbus call --system --dest org.freedesktop.UDisks2 --object-path ${drive} --method org.freedesktop.DBus.Properties.Get org.freedesktop.UDisks2.Drive MediaRemovable)
		if [[ "${mediaremovable}" = *"true"* ]]; then
			removable=1
		fi
	fi

	# Check that device is either removable or loop
	if [ "$removable" != "1" -a $(stat -c '%t' /dev/$dev) != ${LOOP_MAJOR} ]; then
		pr_error "$1 is not a removable device, exiting"
		return 1
	fi

	# Check that device is attached
	if [ ${size_bytes} -eq 0 ]; then
		pr_error "$1 is not attached, exiting"
		return 1
	fi

	pr_info "Device: ${LPARAM_BLOCK_DEVICE}, ${size_gib}GiB"
	pr_info "================================================"
	read -p "Press Enter to continue"

	return 0
}

# make sdcard for device
# $1 -- block device
# $2 -- output images dir
function make_sdcard() {
	readonly local LPARAM_BLOCK_DEVICE=${1}
	readonly local LPARAM_OUTPUT_DIR=${2}
	readonly local P1_MOUNT_DIR="${G_TMP_DIR}/p1"
	readonly local DEBIAN_IMAGES_TO_ROOTFS_POINT="opt/images/Debian"

	readonly local BOOTLOAD_RESERVE_SIZE=8
	readonly local SPARE_SIZE=4

	[ "${LPARAM_BLOCK_DEVICE}" = "na" ] && {
		pr_warning "No valid block device: ${LPARAM_BLOCK_DEVICE}"
		return 1;
	};

	local part=""
	if [ `echo ${LPARAM_BLOCK_DEVICE} | grep -c mmcblk` -ne 0 ]; then
		part="p"
	fi

	# Check that we're using a valid device
	if ! check_sdcard ${LPARAM_BLOCK_DEVICE}; then
		return 1
	fi

	for ((i=0; i<10; i++))
	do
		if [ `mount | grep -c ${LPARAM_BLOCK_DEVICE}${part}$i` -ne 0 ]; then
			umount ${LPARAM_BLOCK_DEVICE}${part}$i
		fi
	done

	function format_sdcard
	{
		pr_info "Formating SDCARD partitions"
		mkfs.ext4 ${LPARAM_BLOCK_DEVICE}${part}1 -L rootfs
	}

	function flash_u-boot
	{
		pr_info "Flashing U-Boot"
		dd if=${LPARAM_OUTPUT_DIR}/${G_UBOOT_NAME_FOR_EMMC} \
		of=${LPARAM_BLOCK_DEVICE} bs=1K seek=${BOOTLOADER_OFFSET}; sync
	}

	function flash_sdcard
	{
		pr_info "Flashing \"rootfs\" partition"
		tar -xpf ${LPARAM_OUTPUT_DIR}/${DEF_ROOTFS_TARBAR_NAME} \
			-C ${P1_MOUNT_DIR}/
	}

	function copy_debian_images
	{
		mkdir -p ${P1_MOUNT_DIR}/${DEBIAN_IMAGES_TO_ROOTFS_POINT}

		pr_info "Copying Debian images to /${DEBIAN_IMAGES_TO_ROOTFS_POINT}"
		cp ${LPARAM_OUTPUT_DIR}/${DEF_ROOTFS_TARBAR_NAME} \
			${P1_MOUNT_DIR}/${DEBIAN_IMAGES_TO_ROOTFS_POINT}/${DEF_ROOTFS_TARBAR_NAME}

		pr_info "Copying MMC U-Boot to /${DEBIAN_IMAGES_TO_ROOTFS_POINT}"
		cp ${LPARAM_OUTPUT_DIR}/${G_UBOOT_NAME_FOR_EMMC} \
			${P1_MOUNT_DIR}/${DEBIAN_IMAGES_TO_ROOTFS_POINT}/
		return 0;
	}

	function copy_scripts
	{
		pr_info "Copying scripts to /${DEBIAN_IMAGES_TO_ROOTFS_POINT}"
		cp ${G_VARISCITE_PATH}/debian-emmc.sh \
			${P1_MOUNT_DIR}/usr/sbin/
	}

	function ceildiv
	{
		local num=$1
		local div=$2
		echo $(( (num + div - 1) / div ))
	}

	# Delete the partitions
	for ((i=0; i<10; i++))
	do
		if [ `ls ${LPARAM_BLOCK_DEVICE}${part}$i 2> /dev/null | grep -c ${LPARAM_BLOCK_DEVICE}${part}$i` -ne 0 ]; then
			dd if=/dev/zero of=${LPARAM_BLOCK_DEVICE}${part}$i bs=512 count=1024
		fi
	done
	sync

	((echo d; echo 1; echo d; echo 2; echo d; echo 3; echo d; echo w) | \
		fdisk ${LPARAM_BLOCK_DEVICE} &> /dev/null) || true
	sync

	dd if=/dev/zero of=${LPARAM_BLOCK_DEVICE} bs=1024 count=4096
	sleep 2; sync;

	pr_info "Creating new partitions"

	# Create a new partition table

	# Get total card size
	TOTAL_SIZE=`sfdisk -s ${LPARAM_BLOCK_DEVICE}`
	TOTAL_SIZE=`expr ${TOTAL_SIZE} / 1024`
	ROOTFS_SIZE=`expr ${TOTAL_SIZE} - ${BOOTLOAD_RESERVE_SIZE} - ${SPARE_SIZE}`

	pr_info "ROOT SIZE=${ROOTFS_SIZE} TOTAl SIZE=${TOTAL_SIZE}"

	BLOCK=`echo ${LPARAM_BLOCK_DEVICE} | cut -d "/" -f 3`
	SECT_SIZE_BYTES=`cat /sys/block/${BLOCK}/queue/physical_block_size`

	BOOTLOAD_RESERVE_SIZE_BYTES=$((BOOTLOAD_RESERVE_SIZE * 1024 * 1024))
	ROOTFS_SIZE_BYTES=$((ROOTFS_SIZE * 1024 * 1024))

	PART1_START=`ceildiv ${BOOTLOAD_RESERVE_SIZE_BYTES} ${SECT_SIZE_BYTES}`
	PART1_SIZE=`ceildiv ${ROOTFS_SIZE_BYTES} ${SECT_SIZE_BYTES}`

sfdisk --force -uS ${LPARAM_BLOCK_DEVICE} &> /dev/null << EOF
${PART1_START},${PART1_SIZE},83
EOF

	sleep 2; sync;
	fdisk -l ${LPARAM_BLOCK_DEVICE}

	sleep 2; sync;

	# Format the partitions
	format_sdcard
	sleep 2; sync;

	flash_u-boot
	sleep 2; sync;

	# Mount the partitions
	mkdir -p ${P1_MOUNT_DIR}
	sync

	mount ${LPARAM_BLOCK_DEVICE}${part}1  ${P1_MOUNT_DIR}
	sleep 2; sync;

	flash_sdcard
	copy_debian_images
	copy_scripts

	pr_info "Sync sdcard..."
	sync
	umount ${P1_MOUNT_DIR}

	rm -rf ${P1_MOUNT_DIR}

	pr_info "Done make sdcard!"

	return 0;
}

# make sdcard for device
# $1 -- block device
# $2 -- output images dir
function make_sdcard_mx6_mx6ul_mx7() {
	readonly local LPARAM_BLOCK_DEVICE=${1}
	readonly local LPARAM_OUTPUT_DIR=${2}
	readonly local P1_MOUNT_DIR="${G_TMP_DIR}/p1"
	readonly local P2_MOUNT_DIR="${G_TMP_DIR}/p2"
	readonly local DEBIAN_IMAGES_TO_ROOTFS_POINT="opt/images/Debian"

	readonly local BOOTLOAD_RESERVE=4
	readonly local BOOT_ROM_SIZE=8
	readonly local SPARE_SIZE=0

	[ "${LPARAM_BLOCK_DEVICE}" = "na" ] && {
		pr_warning "No valid block device: ${LPARAM_BLOCK_DEVICE}"
		return 1;
	};

	local part=""
	if [ `echo ${LPARAM_BLOCK_DEVICE} | grep -c mmcblk` -ne 0 ]; then
		part="p"
	fi

	# Check that we're using a valid device
	if ! check_sdcard ${LPARAM_BLOCK_DEVICE}; then
		return 1
	fi

	for ((i=0; i<10; i++))
	do
		if [ `mount | grep -c ${LPARAM_BLOCK_DEVICE}${part}$i` -ne 0 ]; then
			umount ${LPARAM_BLOCK_DEVICE}${part}$i
		fi
	done

	function format_sdcard
	{
		pr_info "Formating SDCARD partitions"
		mkfs.vfat ${LPARAM_BLOCK_DEVICE}${part}1 -n BOOT-VARSOM
		mkfs.ext4 ${LPARAM_BLOCK_DEVICE}${part}2 -L rootfs
	}

	function flash_u-boot
	{
		pr_info "Flashing U-Boot"
		dd if=${LPARAM_OUTPUT_DIR}/${G_SPL_NAME_FOR_EMMC} of=${LPARAM_BLOCK_DEVICE} bs=1K seek=1; sync
		dd if=${LPARAM_OUTPUT_DIR}/${G_UBOOT_NAME_FOR_EMMC} of=${LPARAM_BLOCK_DEVICE} bs=1K seek=69; sync
	}

	function flash_sdcard
	{
		pr_info "Flashing \"BOOT-VARSOM\" partition"
		cp ${LPARAM_OUTPUT_DIR}/*.dtb	${P1_MOUNT_DIR}/
		cp ${LPARAM_OUTPUT_DIR}/${BUILD_IMAGE_TYPE}	${P1_MOUNT_DIR}/${BUILD_IMAGE_TYPE}
		sync

		pr_info "Flashing \"rootfs\" partition"
		tar -xpf ${LPARAM_OUTPUT_DIR}/${DEF_ROOTFS_TARBAR_NAME} -C ${P2_MOUNT_DIR}/
	}

	function copy_debian_images
	{
		mkdir -p ${P2_MOUNT_DIR}/${DEBIAN_IMAGES_TO_ROOTFS_POINT}

		pr_info "Copying Debian images to /${DEBIAN_IMAGES_TO_ROOTFS_POINT}"
		cp ${LPARAM_OUTPUT_DIR}/${BUILD_IMAGE_TYPE} 						${P2_MOUNT_DIR}/${DEBIAN_IMAGES_TO_ROOTFS_POINT}/
		if [ "${MACHINE}" = "imx6ul-var-dart" ] ||
		[ "${MACHINE}" = "var-som-mx7" ]; then
			cp ${LPARAM_OUTPUT_DIR}/rootfs.ubi.img ${P2_MOUNT_DIR}/${DEBIAN_IMAGES_TO_ROOTFS_POINT}/
		fi
		cp ${LPARAM_OUTPUT_DIR}/${DEF_ROOTFS_TARBAR_NAME}	${P2_MOUNT_DIR}/${DEBIAN_IMAGES_TO_ROOTFS_POINT}/${DEF_ROOTFS_TARBAR_NAME}

		cp ${LPARAM_OUTPUT_DIR}/*.dtb						${P2_MOUNT_DIR}/${DEBIAN_IMAGES_TO_ROOTFS_POINT}/

		pr_info "Copying NAND U-Boot to /${DEBIAN_IMAGES_TO_ROOTFS_POINT}"
		cp ${LPARAM_OUTPUT_DIR}/${G_SPL_NAME_FOR_NAND}		${P2_MOUNT_DIR}/${DEBIAN_IMAGES_TO_ROOTFS_POINT}/
		cp ${LPARAM_OUTPUT_DIR}/${G_UBOOT_NAME_FOR_NAND}	${P2_MOUNT_DIR}/${DEBIAN_IMAGES_TO_ROOTFS_POINT}/

		pr_info "Copying MMC U-Boot to /${DEBIAN_IMAGES_TO_ROOTFS_POINT}"
		cp ${LPARAM_OUTPUT_DIR}/${G_SPL_NAME_FOR_EMMC}		${P2_MOUNT_DIR}/${DEBIAN_IMAGES_TO_ROOTFS_POINT}/
		cp ${LPARAM_OUTPUT_DIR}/${G_UBOOT_NAME_FOR_EMMC}	${P2_MOUNT_DIR}/${DEBIAN_IMAGES_TO_ROOTFS_POINT}/

		return 0;
	}

	function copy_scripts
	{
		pr_info "Copying scripts to /${DEBIAN_IMAGES_TO_ROOTFS_POINT}"
		cp ${G_VARISCITE_PATH}/${MACHINE}/debian-emmc.sh	${P2_MOUNT_DIR}/usr/sbin/
		if [ "${MACHINE}" = "imx6ul-var-dart" ] ||
		[ "${MACHINE}" = "var-som-mx7" ]; then
			cp ${G_VARISCITE_PATH}/${MACHINE}/debian-nand.sh	${P2_MOUNT_DIR}/usr/sbin/
		else
			cp ${G_VARISCITE_PATH}/${MACHINE}/debian-install.sh ${P2_MOUNT_DIR}/usr/sbin/
		fi
	}

	function ceildiv
	{
		local num=$1
		local div=$2
		echo $(( (num + div - 1) / div ))
	}

	# Delete the partitions
	for ((i=0; i<10; i++))
	do
		if [ `ls ${LPARAM_BLOCK_DEVICE}${part}$i 2> /dev/null | grep -c ${LPARAM_BLOCK_DEVICE}${part}$i` -ne 0 ]; then
			dd if=/dev/zero of=${LPARAM_BLOCK_DEVICE}${part}$i bs=512 count=1024
		fi
	done
	sync

	((echo d; echo 1; echo d; echo 2; echo d; echo 3; echo d; echo w) | fdisk ${LPARAM_BLOCK_DEVICE} &> /dev/null) || true
	sync

	dd if=/dev/zero of=${LPARAM_BLOCK_DEVICE} bs=1024 count=4096
	sleep 2; sync;

	pr_info "Creating new partitions"

	# Create a new partition table
fdisk ${LPARAM_BLOCK_DEVICE} <<EOF
n
p
1
8192
24575
t
c
n
p
2
24576

p
w
EOF
	sleep 2; sync;

	# Get total card size
	total_size=`sfdisk -s ${LPARAM_BLOCK_DEVICE}`
	total_size=`expr ${total_size} / 1024`
	boot_rom_sizeb=`expr ${BOOT_ROM_SIZE} + ${BOOTLOAD_RESERVE}`
	rootfs_size=`expr ${total_size} - ${boot_rom_sizeb} - ${SPARE_SIZE}`

	pr_info "ROOT SIZE=${rootfs_size} TOTAl SIZE=${total_size} BOOTROM SIZE=${boot_rom_sizeb}"
	sleep 2; sync;

	# Format the partitions
	format_sdcard
	sleep 2; sync;

	flash_u-boot
	sleep 2; sync;

	# Mount the partitions
	mkdir -p ${P1_MOUNT_DIR}
	mkdir -p ${P2_MOUNT_DIR}
	sync

	mount ${LPARAM_BLOCK_DEVICE}${part}1  ${P1_MOUNT_DIR}
	mount ${LPARAM_BLOCK_DEVICE}${part}2  ${P2_MOUNT_DIR}
	sleep 2; sync;

	flash_sdcard
	copy_debian_images
	copy_scripts

	pr_info "Sync sdcard..."
	sync
	umount ${P1_MOUNT_DIR}
	umount ${P2_MOUNT_DIR}

	rm -rf ${P1_MOUNT_DIR}
	rm -rf ${P2_MOUNT_DIR}

	pr_info "Done make sdcard!"

	return 0;
}


function make_imx_sdma_fw() {
	pr_info "Install imx sdma firmware"
	install -d ${2}/lib/firmware/imx/sdma
	install -m 0644 ${1}/imx/sdma/sdma-imx6q.bin ${2}/lib/firmware/imx/sdma
	install -m 0644 ${1}/LICENSE.sdma_firmware ${2}/lib/firmware/
	return 0;
}

# make firmware for wl bcm module
# $1 -- bcm git directory
# $2 -- rootfs output dir
function make_bcm_fw() {
	pr_info "Make and install bcm configs and firmware"

	install -d ${2}/lib/firmware/bcm
	install -d ${2}/lib/firmware/brcm
	install -m 0644 ${1}/brcm/* ${2}/lib/firmware/brcm/
	install -m 0644 ${1}/*.hcd ${2}/lib/firmware/bcm/
	install -m 0644 ${1}/LICENSE ${2}/lib/firmware/bcm/
	install -m 0644 ${1}/LICENSE ${2}/lib/firmware/brcm/

	return 0;
}

function install_wifi_service() {
### install variscite-wifi service
	install -d -m 0755 ${ROOTFS_BASE}/etc/wifi
	install -m 0755 ${G_VARISCITE_PATH}/${MACHINE}/variscite-wifi ${ROOTFS_BASE}/etc/wifi
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/variscite-wifi.service ${ROOTFS_BASE}/lib/systemd/system
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/brcmfmac.conf ${ROOTFS_BASE}/etc/modprobe.d
	ln -s /lib/systemd/system/variscite-wifi.service \
		${ROOTFS_BASE}/etc/systemd/system/multi-user.target.wants/variscite-wifi.service
}

function install_bt_brcm() {
	pr_info "Make and install bcm BT service and firmware"

### install variscite-bluetooth service
        install -m 0755 ${G_VARISCITE_PATH}/${MACHINE}/brcm_patchram_plus ${ROOTFS_BASE}/usr/bin
        install -d -m 0755 ${ROOTFS_BASE}/etc/bluetooth
        install -m 0755 ${G_VARISCITE_PATH}/${MACHINE}/variscite-bluetooth ${ROOTFS_BASE}/etc/bluetooth
        install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/variscite-bluetooth.service ${ROOTFS_BASE}/lib/systemd/system
        ln -s /lib/systemd/system/variscite-bluetooth.service \
                ${ROOTFS_BASE}/etc/systemd/system/multi-user.target.wants/variscite-bluetooth.service
}
#################### commands ################

function cmd_make_deploy() {
	make_prepare;

	# get linaro toolchain
	(( `ls ${G_CROSS_COMPILER_PATH} 2>/dev/null | wc -l` == 0 )) && {
		pr_info "Get and unpack cross compiler";
		get_remote_file ${G_EXT_CROSS_COMPILER_LINK} \
			${DEF_SRC_DIR}/${G_CROSS_COMPILER_ARCHIVE}
		tar -xJf ${DEF_SRC_DIR}/${G_CROSS_COMPILER_ARCHIVE} \
			-C ${G_TOOLS_PATH}/
	};

	# get uboot repository
	(( `ls ${G_UBOOT_SRC_DIR} 2>/dev/null | wc -l` == 0 )) && {
		pr_info "Get uboot repository";
		get_git_src ${G_UBOOT_GIT} ${G_UBOOT_BRANCH} \
			${G_UBOOT_SRC_DIR} ${G_UBOOT_REV}
	};

	# get kernel repository
	(( `ls ${G_LINUX_KERNEL_SRC_DIR} 2>/dev/null | wc -l` == 0 )) && {
		pr_info "Get kernel repository";
		get_git_src ${G_LINUX_KERNEL_GIT} ${G_LINUX_KERNEL_BRANCH} \
			${G_LINUX_KERNEL_SRC_DIR} ${G_LINUX_KERNEL_REV}
	};
	if [ ! -z "${G_BCM_FW_GIT}" ]; then
	# get bcm firmware repository
	(( `ls ${G_BCM_FW_SRC_DIR}  2>/dev/null | wc -l` == 0 )) && {
		pr_info "Get bcmhd firmware repository";
		get_git_src ${G_BCM_FW_GIT} ${G_BCM_FW_GIT_BRANCH} \
			${G_BCM_FW_SRC_DIR} ${G_BCM_FW_GIT_REV}
	};
	fi
	if [ ! -z "${G_IMXBOOT_GIT}" ]; then
	# get IMXBoot Source repository
	(( `ls ${G_IMXBOOT_SRC_DIR}  2>/dev/null | wc -l` == 0 )) && {
		pr_info "Get imx-boot";
		get_git_src ${G_IMXBOOT_GIT} \
		${G_IMXBOOT_BRACH} ${G_IMXBOOT_SRC_DIR} ${G_IMXBOOT_REV}
	};
	fi

	if [ "${MACHINE}" = "var-som-mx6" ]; then
	# get wilink8 utils repository
	(( `ls ${G_WILINK8_UTILS_SRC_DIR} 2>/dev/null | wc -l` == 0 )) && {
		pr_info "Get wilink8 utils repository";
		get_git_src ${G_WILINK8_UTILS_GIT} ${G_WILINK8_UTILS_GIT_BRANCH} ${G_WILINK8_UTILS_SRC_DIR} ${G_WILINK8_UTILS_GIT_SRCREV}
		cd ${G_WILINK8_UTILS_SRC_DIR}
		patch -p1 < ${DEF_BUILDENV}/patches/wilink8/utils/config_sh.patch
		cd -
	};

	# get wilink8 firmware repository
	(( `ls ${G_WILINK8_FW_WIFI_SRC_DIR} 2>/dev/null | wc -l` == 0 )) && {
		pr_info "Get wilink8 wifi firmware repository";
		get_git_src ${G_WILINK8_FW_WIFI_GIT} ${G_WILINK8_FW_WIFI_GIT_BRANCH} ${G_WILINK8_FW_WIFI_SRC_DIR} ${G_WILINK8_FW_WIFI_GIT_SRCREV}
	};

	# get bt firmware repository
	(( `ls ${G_WILINK8_FW_BT_SRC_DIR} 2>/dev/null | wc -l` == 0 )) && {
		pr_info "Get wilink8 bt firmware repository";
		get_git_src ${G_WILINK8_FW_BT_GIT} ${G_WILINK8_FW_BT_GIT_BRANCH} ${G_WILINK8_FW_BT_SRC_DIR} ${G_WILINK8_FW_BT_GIT_SRCREV}
	};

	# get imx firmware
	(( `ls ${G_IMX_FW_LOCAL_PATH} 2>/dev/null | wc -l` == 0 )) && {
		pr_info "Get and unpack iMX firmware";
		get_remote_file ${G_IMX_FW_REMOTE_LINK} ${G_IMX_FW_LOCAL_PATH}
		unpack_imx_package ${G_IMX_FW_LOCAL_PATH}
	};

	# get imx vpu library
	(( `ls ${G_IMX_VPU_LOCAL_PATH} 2>/dev/null | wc -l` == 0 )) && {
		pr_info "Get and unpack iMV VPU library";
		get_remote_file ${G_IMX_VPU_REMOTE_LINK} ${G_IMX_VPU_LOCAL_PATH}
		unpack_imx_package ${G_IMX_VPU_LOCAL_PATH}
	};

	# get imx codec libraries
	(( `ls ${G_IMX_CODEC_LOCAL_PATH} 2>/dev/null | wc -l` == 0 )) && {
		pr_info "Get and unpack iMV CODEC libraries";
		get_remote_file ${G_IMX_CODEC_REMOTE_LINK} ${G_IMX_CODEC_LOCAL_PATH}
		unpack_imx_package ${G_IMX_CODEC_LOCAL_PATH}
	};

	# get imx gpu g2d libraries
	(( `ls ${G_IMX_GPU_G2D_LOCAL_PATH} 2>/dev/null | wc -l` == 0 )) && {
		pr_info "Get and unpack iMV GPU G2D libraries";
		get_remote_file ${G_IMX_GPU_G2D_REMOTE_LINK} ${G_IMX_GPU_G2D_LOCAL_PATH}
		unpack_imx_package ${G_IMX_GPU_G2D_LOCAL_PATH}
	};

	# get imx gpu viv libraries
	(( `ls ${G_IMX_GPU_VIV_LOCAL_PATH} 2>/dev/null | wc -l` == 0 )) && {
		pr_info "Get and unpack iMV GPU VIV libraries";
		get_remote_file ${G_IMX_GPU_VIV_REMOTE_LINK} ${G_IMX_GPU_VIV_LOCAL_PATH}
		unpack_imx_package ${G_IMX_GPU_VIV_LOCAL_PATH}
	};

	# get imx xorg libraries
	(( `ls ${G_IMX_XORG_DRV_SRC_DIR} 2>/dev/null | wc -l` == 0 )) && {
		pr_info "Get XORG driver repository";
		get_git_src ${G_IMX_XORG_DRV_GIT} ${G_IMX_XORG_DRV_GIT_BRANCH} ${G_IMX_XORG_DRV_SRC_DIR} ${G_IMX_XORG_DRV_GIT_SRCREV}
		cd ${G_IMX_XORG_DRV_SRC_DIR}
		patch -p1 < ${DEF_BUILDENV}/patches/imx/xf86-video-imx-vivante/makefile.patch
		cd -
	};

	# get imx vpu api repository
	(( `ls ${G_IMX_VPU_API_SRC_DIR} 2>/dev/null | wc -l` == 0 )) && {
		pr_info "Get iMX VPU API repository";
		get_git_src ${G_IMX_VPU_API_GIT} ${G_IMX_VPU_API_GIT_BRANCH} ${G_IMX_VPU_API_SRC_DIR} ${G_IMX_VPU_API_GIT_SRCREV}
	};

	# get gstreamer-imx repository
	(( `ls ${G_IMX_GSTREAMER_SRC_DIR} 2>/dev/null | wc -l` == 0 )) && {
		pr_info "Get gstreamer-imx repository";
		get_git_src ${G_IMX_GSTREAMER_GIT} ${G_IMX_GSTREAMER_GIT_BRANCH} ${G_IMX_GSTREAMER_SRC_DIR} ${G_IMX_GSTREAMER_GIT_SRCREV}
	};
	fi
	if [ "${MACHINE}" = "imx6ul-var-dart" ] ||
		[ "${MACHINE}" = "var-som-mx7" ]; then
	# get linux-frimwrae source repository
	(( `ls ${G_IMX_SDMA_FW_SRC_DIR}  2>/dev/null | wc -l` == 0 )) && {
		pr_info "Get Linux-Firmware";
		get_git_src ${G_IMX_SDMA_FW_GIT} \
		${G_IMX_SDMA_FW_GIT_BRANCH} ${G_IMX_SDMA_FW_SRC_DIR} ${G_IMX_SDMA_FW_GIT_REV}
	};
	fi
	return 0;
}

function cmd_make_rootfs() {
	make_prepare;

	if [ "${MACHINE}" = "var-som-mx6" ] ||
	   [ "${MACHINE}" = "imx6ul-var-dart" ] ||
		[ "${MACHINE}" = "var-som-mx7" ]; then
	## make debian rootfs for mx6
	cd ${G_ROOTFS_DIR}
	make_debian_rootfs_x11_common ${G_ROOTFS_DIR} || {
		pr_error "Failed #$? in function make_debian_rootfs"
		cd -;
		return 1;
	}
	## make imx sdma firmware
	make_imx_sdma_fw ${G_IMX_SDMA_FW_SRC_DIR} ${G_ROOTFS_DIR} || {
		pr_error "Failed #$? in function make_tarbar"
		return 4;
	};
	cd -
	else 	
	## make debian rootfs
	cd ${G_ROOTFS_DIR}
	make_debian_rootfs ${G_ROOTFS_DIR} || {
		pr_error "Failed #$? in function make_debian_rootfs"
		cd -;
		return 1;
	}
	cd -

	fi
	if [ ! -z "${G_BCM_FW_GIT}" ]; then
	## make bcm firmwares
	make_bcm_fw ${G_BCM_FW_SRC_DIR} ${G_ROOTFS_DIR} || {
		pr_error "Failed #$? in function make_tarbar"
		return 4;
	};
	fi
	## pack rootfs
	make_tarbar ${G_ROOTFS_DIR} ${G_ROOTFS_TARBAR_PATH} || {
		pr_error "Failed #$? in function make_tarbar"
		return 4;
	}

	if [ "${MACHINE}" = "imx6ul-var-dart" ] ||
		[ "${MACHINE}" = "var-som-mx7" ]; then
		## pack to ubi
		make_ubi ${G_ROOTFS_DIR} ${G_TMP_DIR} ${PARAM_OUTPUT_DIR} ${G_UBI_FILE_NAME}  || {
			pr_error "Failed #$? in function make_ubi"
			return 5;
		};
	fi
	return 0;
}

function cmd_make_uboot() {
	make_uboot ${G_UBOOT_SRC_DIR} ${PARAM_OUTPUT_DIR} || {
		pr_error "Failed #$? in function make_uboot"
		return 1;
	};

	return 0;
}

function cmd_make_kernel() {
	make_kernel ${G_CROSS_COMPILER_PATH}/${G_CROSS_COMPILER_PREFIX} \
		${G_LINUX_KERNEL_DEF_CONFIG} "${G_LINUX_DTB}" \
		${G_LINUX_KERNEL_SRC_DIR} ${PARAM_OUTPUT_DIR} || {
		pr_error "Failed #$? in function make_kernel"
		return 1;
	};

	return 0;
}

function cmd_make_kmodules() {
	make_prepare;

	rm -rf ${G_ROOTFS_DIR}/lib/modules/* || {
		pr_error "Failed #$? prepare modules dir"
		return 1;
	};

	make_kernel_modules ${G_CROSS_COMPILER_PATH}/${G_CROSS_COMPILER_PREFIX} \
		${G_LINUX_KERNEL_DEF_CONFIG} ${G_LINUX_KERNEL_SRC_DIR} \
		${G_ROOTFS_DIR} || {
		pr_error "Failed #$? in function make_kernel_modules"
		return 2;
	};

	install_kernel_modules ${G_CROSS_COMPILER_PATH}/${G_CROSS_COMPILER_PREFIX} \
		${G_LINUX_KERNEL_DEF_CONFIG} \
		${G_LINUX_KERNEL_SRC_DIR} ${G_ROOTFS_DIR} || {
		pr_error "Failed #$? in function install_kernel_modules"
		return 2;
	};

	return 0;
}

function cmd_make_rfs_ubi() {
	make_ubi ${G_ROOTFS_DIR} ${G_TMP_DIR} ${PARAM_OUTPUT_DIR} ${G_UBI_FILE_NAME} || {
		pr_error "Failed #$? in function make_ubi"
		return 1;
	};

	return 0;
}

function cmd_make_rfs_tar() {
	## pack rootfs
	make_tarbar ${G_ROOTFS_DIR} ${G_ROOTFS_TARBAR_PATH} || {
		pr_error "Failed #$? in function make_tarbar"
		return 1;
	}

	return 0;
}

function cmd_make_sdcard() {
	if [ "${MACHINE}" = "var-som-mx6" ] ||
		[ "${MACHINE}" = "imx6ul-var-dart" ] ||
		[ "${MACHINE}" = "var-som-mx7" ]; then
		make_sdcard_mx6_mx6ul_mx7 ${PARAM_BLOCK_DEVICE} ${PARAM_OUTPUT_DIR} || {
			pr_error "Failed #$? in function make_sdcard"
			return 1;
		};

	else
		make_sdcard ${PARAM_BLOCK_DEVICE} ${PARAM_OUTPUT_DIR} || {
			pr_error "Failed #$? in function make_sdcard"
			return 1;
		};
	fi
	return 0;
}

function cmd_make_bcmfw() {
	make_prepare

	make_bcm_fw ${G_BCM_FW_SRC_DIR} ${G_ROOTFS_DIR} || {
		pr_error "Failed #$? in function make_bcm_fw"
		return 1;
	};

	return 0;
}

function cmd_make_firmware() {
	make_prepare

	make_imx_sdma_fw ${G_IMX_SDMA_FW_SRC_DIR} ${G_ROOTFS_DIR} || {
		pr_error "Failed #$? in function make_tarbar"
		return 4;
	};
	return 0;
}

function cmd_make_clean() {

	## clean kernel, dtb, modules
	clean_kernel ${G_LINUX_KERNEL_SRC_DIR} || {
		pr_error "Failed #$? in function clean_kernel"
		return 1;
	};

	## clean u-boot
	clean_uboot ${G_UBOOT_SRC_DIR} || {
		pr_error "Failed #$? in function clean_uboot"
		return 2;
	};

	## delete tmp dirs and etc
	pr_info "Delete tmp dir ${G_TMP_DIR}"
	rm -rf ${G_TMP_DIR} && :;

	pr_info "Delete rootfs dir ${G_ROOTFS_DIR}"
	rm -rf ${G_ROOTFS_DIR} && :;

	return 0;
}

#################### main function #######################
## test for root access support (msrc not allowed)
[ "$PARAM_CMD" != "deploy" ] && [ "$PARAM_CMD" != "bootloader" ] && [ "$PARAM_CMD" != "kernel" ] && [ "$PARAM_CMD" != "modules" ] && [ ${EUID} -ne 0 ] && {
	pr_error "this command must be run as root (or sudo/su)"
	exit 1;
};

V_RET_CODE=0;

pr_info "Command: \"$PARAM_CMD\" start..."

case $PARAM_CMD in
	deploy )
		cmd_make_deploy || {
			V_RET_CODE=1;
		};
		;;
	rootfs )
		cmd_make_rootfs || {
			V_RET_CODE=1;
		};
		;;
	bootloader )
		cmd_make_uboot || {
			V_RET_CODE=1;
		}
		;;
	kernel )
		cmd_make_kernel || {
			V_RET_CODE=1;
		};
		;;
	modules )
		cmd_make_kmodules || {
			V_RET_CODE=1;
		};
		;;
	bcmfw )
		cmd_make_bcmfw || {
			V_RET_CODE=1;
		};
		;;
	firmware )
		cmd_make_firmware || {
			V_RET_CODE=1;
		};
		;;
	sdcard )
		cmd_make_sdcard || {
			V_RET_CODE=1;
		};
		;;
	rtar )
		cmd_make_rfs_tar || {
			V_RET_CODE=1;
		};
		;;
	all )
		(cmd_make_uboot  &&
		 cmd_make_kernel &&
		 cmd_make_kmodules &&
		 cmd_make_rootfs) || {
			V_RET_CODE=1;
		};
		;;
	clean )
		cmd_make_clean || {
			V_RET_CODE=1;
		};
		;;
	* )
		pr_error "Invalid input command: \"${PARAM_CMD}\"";
		V_RET_CODE=1;
		;;
esac

pr_info ""
pr_info "Command: \"$PARAM_CMD\" end. Exit code: ${V_RET_CODE}"
pr_info ""


exit ${V_RET_CODE};
