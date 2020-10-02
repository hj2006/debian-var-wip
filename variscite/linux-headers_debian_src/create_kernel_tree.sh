#$1 - src/kernel/
#$2 - output/kernel-headers/
#$3 - variscite/
function create_debian_kernel_headers_package()
{
KERNEL_SRC_DIR=$1
OUTPUT_DIR=$2
ORIG_DIR=$3
LOCAL_KERNEL_VERSION=`cat ${KERNEL_SRC_DIR}/include/config/kernel.release`
echo "LOCAL Kernel Version is ${LOCAL_KERNEL_VERSION}"
rm -rf ${OUTPUT_DIR}
mkdir -p ${OUTPUT_DIR}/debian
rm -rf ${OUTPUT_DIR}/kernel
tar -xjf ${3}/linux-headers_debian_src/kernel-headers-template.tar.bz2 -C ${OUTPUT_DIR}/
ln -sf ${KERNEL_SRC_DIR} ${OUTPUT_DIR}/kernel-src
cd ${OUTPUT_DIR}
#Prepare the kbuild package
echo "" > ${OUTPUT_DIR}/debian/linux-kbuild-${LOCAL_KERNEL_VERSION}.install
cat ${ORIG_DIR}/linux-headers_debian_src/kbuild_file_list.txt | while read line || [[ -n $line ]];
do
	dst=`echo $line | sed 's/kernel-src/kernel/g'`
	echo  "cp $line $dst"
	install=`echo $line | sed -e "s/kernel-src/\/usr\/lib\/linux-kbuild-${LOCAL_KERNEL_VERSION}/g"`
	echo "$dst $install" >> ${OUTPUT_DIR}/debian/linux-kbuild-${LOCAL_KERNEL_VERSION}.install
	cp $line $dst
done

#Prepare linux-headers-5.x file liest
LINUX_HEADERS_COMMON_DIRS=`find kernel-src/arch/  -type d`
LINUX_HEADERS_COMMON_INCLUDE_DIRS=`find kernel-src/include  -type d`
LINUX_HEADERS_FILES=`find kernel-src/arch/ kernel-src/include/ -iname "*.h"  | sed -e "/generated/d" -e "/config/d"`
LINUX_ASSEMBLY_FILES=`find kernel-src/arch/ kernel-src/include/ -iname "*.S"  | sed -e "/generated/d" -e "/config/d"`
LINUX_LDS_FILES=`find kernel-src/arch/ kernel-src/include/ -iname "*module*.lds"  | sed -e "/generated/d" -e "/config/d"`
LINUX_KBUILD_FILES=`find kernel-src/arch/ kernel-src/include/ -iname "*Kbuild*"  | sed -e "/generated/d" -e "/config/d"`
LINUX_Makefile_FILES=`find kernel-src/arch/ kernel-src/include/ -iname "*Makefile*"  | sed -e "/generated/d" -e "/config/d"`

echo "" > ${OUTPUT_DIR}/debian/linux-headers-${LOCAL_KERNEL_VERSION}-common.install
for i in ${LINUX_HEADERS_COMMON_DIRS}
do
	dst=`echo $i | sed -e 's/kernel-src/kernel/g'`
	mkdir -p $dst
done

for i in ${LINUX_HEADERS_COMMON_INCLUDE_DIRS}
do
	dst=`echo $i | sed -e 's/kernel-src/kernel/g'`
	mkdir -p $dst
done

for i in ${LINUX_HEADERS_FILES}
do
	dst=`echo $i | sed -e 's/kernel-src/kernel/g'`
	install=`echo $i | sed -e "s/kernel-src/\/usr\/src\/linux-headers-${LOCAL_KERNEL_VERSION}-common/g"`
	echo "$dst $install" >> ${OUTPUT_DIR}/debian/linux-headers-${LOCAL_KERNEL_VERSION}-common.install
	cp $i $dst
done
for i in ${LINUX_ASSEMBLY_FILES}
do
	dst=`echo $i | sed -e 's/kernel-src/kernel/g'`
	install=`echo $i | sed -e "s/kernel-src/\/usr\/src\/linux-headers-${LOCAL_KERNEL_VERSION}-common/g"`
	echo "$dst $install" >> ${OUTPUT_DIR}/debian/linux-headers-${LOCAL_KERNEL_VERSION}-common.install
	cp $i $dst
done
for i in ${LINUX_LDS_FILES}
do
	dst=`echo $i | sed -e 's/kernel-src/kernel/g'`
	install=`echo $i | sed -e "s/kernel-src/\/usr\/src\/linux-headers-${LOCAL_KERNEL_VERSION}-common/g"`
	echo "$dst $install" >> ${OUTPUT_DIR}/debian/linux-headers-${LOCAL_KERNEL_VERSION}-common.install
	cp $i $dst
done
for i in ${LINUX_KBUILD_FILES}
do
	dst=`echo $i | sed -e 's/kernel-src/kernel/g'`
	install=`echo $i | sed -e "s/kernel-src/\/usr\/src\/linux-headers-${LOCAL_KERNEL_VERSION}-common/g"`
	echo "$dst $install" >> ${OUTPUT_DIR}/debian/linux-headers-${LOCAL_KERNEL_VERSION}-common.install
	cp $i $dst
done

for i in ${LINUX_Makefile_FILES}
do
	dst=`echo $i | sed -e 's/kernel-src/kernel/g'`
	install=`echo $i | sed -e "s/kernel-src/\/usr\/src\/linux-headers-${LOCAL_KERNEL_VERSION}-common/g"`
	echo "$dst $install" >> ${OUTPUT_DIR}/debian/linux-headers-${LOCAL_KERNEL_VERSION}-common.install
	cp $i $dst
done

#prepare linux-headers-5.x-arm64
cp ${KERNEL_SRC_DIR}/.config kernel/.config
cp ${KERNEL_SRC_DIR}/Makefile kernel/Makefile
cp ${KERNEL_SRC_DIR}/Module.symvers kernel/Module.symvers
LINUX_ARCH64_HEADERS_FILES=`find kernel-src/arch/arm64/include kernel-src/include/config/ kernel-src/include/generated/ -iname "*.h"`

echo "" > ${OUTPUT_DIR}/debian/linux-headers-${LOCAL_KERNEL_VERSION}-arm64.install
for i in ${LINUX_ARCH64_HEADERS_FILES}
do
	dst=`echo $i | sed 's/kernel-src/kernel/g'`
	install=`echo $i | sed -e "s/kernel-src/\/usr\/src\/linux-headers-${LOCAL_KERNEL_VERSION}-arm64/g"`
	cp $i $dst
	echo "$dst $install" >> ${OUTPUT_DIR}/debian/linux-headers-${LOCAL_KERNEL_VERSION}-arm64.install
done
echo "kernel/Makefile /usr/src/linux-headers-${LOCAL_KERNEL_VERSION}-arm64/Makefile" >> ${OUTPUT_DIR}/debian/linux-headers-${LOCAL_KERNEL_VERSION}-arm64.install
echo "kernel/.config /usr/src/linux-headers-${LOCAL_KERNEL_VERSION}-arm64/.config" >> ${OUTPUT_DIR}/debian/linux-headers-${LOCAL_KERNEL_VERSION}-arm64.install
echo "kernel/Module.symvers /usr/src/linux-headers-${LOCAL_KERNEL_VERSION}-arm64/Module.symvers" >> ${OUTPUT_DIR}/debian/linux-headers-${LOCAL_KERNEL_VERSION}-arm64.install
touch kernel/linux-headers-arm64
cp ${ORIG_DIR}/linux-headers_debian_src/debian/control ${OUTPUT_DIR}/debian/control
cp ${ORIG_DIR}/linux-headers_debian_src/debian/rules ${OUTPUT_DIR}/debian/rules
cp ${ORIG_DIR}/linux-headers_debian_src/debian/changelog ${OUTPUT_DIR}/debian/changelog
sed -i -e "s/5.4.3/${LOCAL_KERNEL_VERSION}/g" ${OUTPUT_DIR}/debian/control
sed -i -e "s/5.4.3/${LOCAL_KERNEL_VERSION}/g" ${OUTPUT_DIR}/debian/changelog

tar -xjf ${3}/linux-headers_debian_src/kernel-arm64-template.tar.bz2 -C ${OUTPUT_DIR}/

echo "9" > ${OUTPUT_DIR}/debian/compat
cd ${ORIG_DIR}
rm -f ${OUTPUT_DIR}/kernel-src
}
