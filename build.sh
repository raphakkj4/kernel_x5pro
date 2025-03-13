#!/bin/bash

SECONDS=0 # builtin bash timer
TC_DIR="$HOME/tc/clang"
DEFCONFIG="redwood_defconfig"
AK3_DIR="$HOME/AnyKernel3"
ZIPNAME="Hawkeye-BETA$(date '+%Y%m%d-%H%M').zip"
ZIP_DIR="out/zip"

export PATH="$TC_DIR/bin:$PATH"

if ! [ -d "$TC_DIR" ]; then
 echo "clang é coisa de boiola! Cloning to $TC_DIR..."
 if ! git clone --depth=1 https://github.com/kdrag0n/proton-clang "$TC_DIR"; then
  echo "Cloning failed! Aborting..."
  exit 1
 fi
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "\nComeçando a putaria...\n"

make O=out ARCH=arm64 CC=clang LLVM=1 LLVM_IAS=1 \
                CROSS_COMPILE=$TC_DIR/bin/aarch64-linux-gnu- CROSS_COMPILE_ARM32=$TC_DIR/bin/arm-linux-gnueabi- LD=ld.lld 2>&1 \
                TARGET_PRODUCT=redwood

# Check if necessary files are compiled
            kernel="out/arch/arm64/boot/Image"
            dtb="out/arch/arm64/boot/dts/vendor/qcom/yupik.dtb"
            dtbo="out/arch/arm64/boot/dts/vendor/qcom/redwood-sm7325-overlay.dtbo"

            # Packaging the kernel
            echo -e "${GREEN}Kernel compiled successfully! Zipping up...${NC}"
            if [ -d "$AK3_DIR" ]; then
                cp -r $AK3_DIR AnyKernel3
                git -C AnyKernel3 checkout redwood &> /dev/null
            elif ! git clone -q https://github.com/raphakkj4/AnyKernel3 -b redwood; then
                echo -e "${RED}AnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting...${NC}"
                exit 1
            fi

            cp $kernel AnyKernel3
            cp $dtb AnyKernel3/dtb
            python2 scripts/dtc/libfdt/mkdtboimg.py create AnyKernel3/dtbo.img --page_size=4096 $dtbo
            cp $(find out/modules/lib/modules/5.4* -name '*.ko') AnyKernel3/modules/vendor/lib/modules/
            cp out/modules/lib/modules/5.4*/modules.{alias,dep,softdep} AnyKernel3/modules/vendor/lib/modules
            cp out/modules/lib/modules/5.4*/modules.order AnyKernel3/modules/vendor/lib/modules/modules.load
            sed -i 's/\(kernel\/[^: ]*\/\)\([^: ]*\.ko\)/\/vendor\/lib\/modules\/\2/g' AnyKernel3/modules/vendor/lib/modules/modules.dep
            sed -i 's/.*\///g' AnyKernel3/modules/vendor/lib/modules/modules.load
            rm -rf out/arch/arm64/boot out/modules
            cd AnyKernel3
            zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
            cd ..
            rm -rf AnyKernel3

            # Move the zip file to the output directory
            mkdir -p "$ZIP_DIR"
            mv "$ZIPNAME" "$ZIP_DIR"

