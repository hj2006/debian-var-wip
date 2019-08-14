## LINUX kernel: git, config, paths and etc
readonly G_LINUX_KERNEL_SRC_DIR="${DEF_SRC_DIR}/kernel"
readonly G_LINUX_KERNEL_GIT="https://github.com/varigit/linux-imx.git"
readonly G_LINUX_KERNEL_BRANCH="imx_4.14.78_1.0.0_ga_var01"
readonly G_LINUX_KERNEL_REV="35148c96ae3be19f2732adb21d271bba39849414"
readonly G_LINUX_KERNEL_DEF_CONFIG='imx_v7_var_defconfig'
G_LINUX_DTB="imx6dl-var-som-cap.dtb
	     imx6dl-var-som-res.dtb
	     imx6dl-var-som-solo-cap.dtb
	     imx6dl-var-som-solo-res.dtb
	     imx6dl-var-som-solo-vsc.dtb
	     imx6dl-var-som-vsc.dtb
	     imx6q-var-dart.dtb
             imx6q-var-som-cap.dtb
             imx6q-var-som-res.dtb
             imx6q-var-som-vsc.dtb
	     imx6qp-var-som-cap.dtb
	     imx6qp-var-som-res.dtb
	     imx6qp-var-som-vsc.dtb"
## uboot
readonly G_UBOOT_SRC_DIR="${DEF_SRC_DIR}/uboot"
readonly G_UBOOT_GIT="https://github.com/varigit/uboot-imx.git"
readonly G_UBOOT_BRANCH="imx_v2018.03_4.14.78_1.0.0_ga_var01"
readonly G_UBOOT_REV="ddc95a6e5b319d6a649a81a5fc5a26ca3c117659"
readonly G_UBOOT_DEF_CONFIG_MMC='mx6var_som_sd_config'
readonly G_UBOOT_DEF_CONFIG_NAND='mx6var_som_nand_config'
readonly G_UBOOT_NAME_FOR_EMMC='u-boot.img.mmc'
readonly G_SPL_NAME_FOR_EMMC='SPL.mmc'
readonly G_UBOOT_NAME_FOR_NAND='u-boot.img.nand'
readonly G_SPL_NAME_FOR_NAND='SPL.nand'

## wilink8 ##
readonly G_WILINK8_GIT="git://git.ti.com/wilink8-wlan"
readonly G_WILINK8_UTILS_SRC_DIR="${DEF_SRC_DIR}/wilink8/utils"
readonly G_WILINK8_UTILS_GIT="${G_WILINK8_GIT}/18xx-ti-utils.git"
readonly G_WILINK8_UTILS_GIT_BRANCH="master"
readonly G_WILINK8_UTILS_GIT_SRCREV="5040274cae5e88303e8a895c2707628fa72d58e8"
readonly G_WILINK8_FW_WIFI_SRC_DIR="${DEF_SRC_DIR}/wilink8/fw_wifi"
readonly G_WILINK8_FW_WIFI_GIT="${G_WILINK8_GIT}/wl18xx_fw.git"
readonly G_WILINK8_FW_WIFI_GIT_BRANCH="master"
readonly G_WILINK8_FW_WIFI_GIT_SRCREV="d153edae2a75393937da43159b7e6251c2cd01b6"
readonly G_WILINK8_FW_BT_SRC_DIR="${DEF_SRC_DIR}/wilink8/fw_bt"
readonly G_WILINK8_FW_BT_GIT="git://git.ti.com/ti-bt/service-packs.git"
readonly G_WILINK8_FW_BT_GIT_BRANCH="master"
readonly G_WILINK8_FW_BT_GIT_SRCREV="31a43dc1248a6c19bb886006f8c167e2fd21cb78"

## imx accelerations ##
# much more standard replacement for Freescale's imx-gst1.0-plugin
# Freescale mirror
readonly G_FSL_MIRROR="http://www.freescale.com/lgfiles/NMG/MAD/YOCTO"
# apt-get install gstreamer1.0-x gstreamer1.0-tools gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-alsa
# sh firmware-imx-7.5.bin --auto-accept
readonly G_IMX_FW_PKG="firmware-imx-7.8"
readonly G_IMX_FW_LOCAL_DIR="${DEF_SRC_DIR}/imx/${G_IMX_FW_PKG}"
readonly G_IMX_FW_LOCAL_PATH="${DEF_SRC_DIR}/imx/${G_IMX_FW_PKG}.bin"
readonly G_IMX_FW_REMOTE_LINK="${G_FSL_MIRROR}/${G_IMX_FW_PKG}.bin"
# sh imx-vpu-5.4.38.bin --auto-accept
readonly G_IMX_VPU_PKG="imx-vpu-5.4.38"
readonly G_IMX_VPU_LOCAL_DIR="${DEF_SRC_DIR}/imx/${G_IMX_VPU_PKG}"
readonly G_IMX_VPU_LOCAL_PATH="${DEF_SRC_DIR}/imx/${G_IMX_VPU_PKG}.bin"
readonly G_IMX_VPU_REMOTE_LINK="${G_FSL_MIRROR}/${G_IMX_VPU_PKG}.bin"
# sh imx-codec-4.3.5.bin --auto-accept
readonly G_IMX_CODEC_PKG="imx-codec-4.4.2"
readonly G_IMX_CODEC_LOCAL_DIR="${DEF_SRC_DIR}/imx/${G_IMX_CODEC_PKG}"
readonly G_IMX_CODEC_LOCAL_PATH="${DEF_SRC_DIR}/imx/${G_IMX_CODEC_PKG}.bin"
readonly G_IMX_CODEC_REMOTE_LINK="${G_FSL_MIRROR}/${G_IMX_CODEC_PKG}.bin"
# sh imx-gpu-g2d-6.2.4.p1.2.bin --auto-accept
readonly G_IMX_GPU_G2D_PKG="imx-gpu-g2d-6.2.4.p1.8-aarch32"
readonly G_IMX_GPU_G2D_LOCAL_DIR="${DEF_SRC_DIR}/imx/${G_IMX_GPU_G2D_PKG}"
readonly G_IMX_GPU_G2D_LOCAL_PATH="${DEF_SRC_DIR}/imx/${G_IMX_GPU_G2D_PKG}.bin"
readonly G_IMX_GPU_G2D_REMOTE_LINK="${G_FSL_MIRROR}/${G_IMX_GPU_G2D_PKG}.bin"
# sh imx-gpu-viv-6.2.4.p1.2-aarch32.bin --auto-accept
readonly G_IMX_GPU_VIV_PKG="imx-gpu-viv-6.2.4.p1.8-aarch32"
readonly G_IMX_GPU_VIV_LOCAL_DIR="${DEF_SRC_DIR}/imx/${G_IMX_GPU_VIV_PKG}"
readonly G_IMX_GPU_VIV_LOCAL_PATH="${DEF_SRC_DIR}/imx/${G_IMX_GPU_VIV_PKG}.bin"
readonly G_IMX_GPU_VIV_REMOTE_LINK="${G_FSL_MIRROR}/${G_IMX_GPU_VIV_PKG}.bin"
# i.MX X.org Video Driver for i.MX Graphics 2D acceleration
readonly G_IMX_XORG_DRV_SRC_DIR="${DEF_SRC_DIR}/imx/xf86-video-imx-vivante"
readonly G_IMX_XORG_DRV_GIT="https://source.codeaurora.org/external/imx/xf86-video-imx-vivante.git"
readonly G_IMX_XORG_DRV_GIT_BRANCH="imx_exa_viv6_g2d"
readonly G_IMX_XORG_DRV_GIT_SRCREV="946e8603ed9a52f36d305405dbb2ab8ff90943d0"
# replacement for Freescale's closed-development libfslvapwrapper library
readonly G_IMX_VPU_API_SRC_DIR="${DEF_SRC_DIR}/imx/libimxvpuapi"
readonly G_IMX_VPU_API_GIT="https://github.com/Freescale/libimxvpuapi.git"
readonly G_IMX_VPU_API_GIT_BRANCH="master"
readonly G_IMX_VPU_API_GIT_SRCREV="4afb52f97e28c731c903a8538bf99e4a6d155b42"
# much more standard replacement for Freescale's imx-gst1.0-plugin
readonly G_IMX_GSTREAMER_SRC_DIR="${DEF_SRC_DIR}/imx/gstreamer-imx"
readonly G_IMX_GSTREAMER_GIT="https://github.com/Freescale/gstreamer-imx.git"
readonly G_IMX_GSTREAMER_GIT_BRANCH="master"
readonly G_IMX_GSTREAMER_GIT_SRCREV="889b8352ca09cd224be6a2f8d53efd59a38fa9cb"
readonly ARCH_CPU="32BIT"
