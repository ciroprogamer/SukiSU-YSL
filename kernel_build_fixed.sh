#!/bin/bash

echo -e "\n[INFO]: BUILD STARTED..!\n"

#init submodules
git submodule init && git submodule update

export KERNEL_ROOT="$(pwd)"
export ARCH=arm64
export KBUILD_BUILD_USER="@ravindu644"

# Function to detect OS and install dependencies
install_dependencies() {
    echo -e "\n[INFO]: Detecting OS and installing dependencies...\n"

    if command -v dnf &> /dev/null; then
        echo -e "[INFO]: Fedora/RHEL-based system detected, using dnf...\n"
        sudo dnf group install "c-development" "development-tools" && \
        sudo dnf install -y dtc lz4 xz zlib-devel java-latest-openjdk-devel python3 \
            p7zip p7zip-plugins android-tools erofs-utils \
            ncurses-devel libX11-devel readline-devel mesa-libGL-devel python3-markdown \
            libxml2 libxslt dos2unix kmod openssl elfutils-libelf-devel dwarves \
            openssl-devel rsync openssl-devel-engine --skip-unavailable

    elif command -v apt &> /dev/null; then
        echo -e "[INFO]: Ubuntu/Debian-based system detected, using apt...\n"
        sudo apt update && sudo apt install -y git device-tree-compiler lz4 xz-utils zlib1g-dev openjdk-17-jdk gcc g++ python3 python-is-python3 p7zip-full android-sdk-libsparse-utils erofs-utils \
            default-jdk git gnupg flex bison gperf build-essential zip curl libc6-dev libncurses-dev libx11-dev libreadline-dev libgl1 libgl1-mesa-dev \
            python3 make sudo gcc g++ bc grep tofrodos python3-markdown libxml2-utils xsltproc zlib1g-dev python-is-python3 libc6-dev libtinfo6 \
            make repo cpio kmod openssl libelf-dev pahole libssl-dev --fix-missing && wget http://security.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2ubuntu0.1_amd64.deb && sudo dpkg -i libtinfo5_6.3-2ubuntu0.1_amd64.deb

    else
        echo -e "[ERROR]: Neither dnf nor apt package manager found. Please install dependencies manually.\n"
        exit 1
    fi

    touch .requirements
}

# Install the requirements for building the kernel when running the script for the first time
if [ ! -f ".requirements" ]; then
    install_dependencies
fi

# Create necessary directories
mkdir -p "${KERNEL_ROOT}/out" "${KERNEL_ROOT}/build" "${HOME}/toolchains"

# Clone AOSP Clang 4691093 (good for 4.9 kernels)
if [ ! -d "${HOME}/toolchains/clang-4691093" ]; then
    echo -e "\n[INFO]: Downloading AOSP Clang 4691093...\n"
    mkdir -p "${HOME}/toolchains/clang-4691093"
    cd "${HOME}/toolchains"
    wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android10-release/clang-r353983c.tar.gz -O clang-r353983c.tar.gz
    tar -xzf clang-r353983c.tar.gz -C clang-4691093
    rm clang-r353983c.tar.gz
    cd "${KERNEL_ROOT}"
fi

# Download and extract GCC 4.9 for arm64 (stable for 4.9 kernels)
if [ ! -d "${HOME}/toolchains/aarch64-linux-android-4.9" ]; then
    echo -e "\n[INFO]: Downloading GCC 4.9 toolchain...\n"
    cd "${HOME}/toolchains"
    git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r61
    cd "${KERNEL_ROOT}"
fi

# Download and extract GCC 4.9 for arm (32-bit, needed for vDSO)
if [ ! -d "${HOME}/toolchains/arm-linux-androideabi-4.9" ]; then
    echo -e "\n[INFO]: Downloading GCC 4.9 32-bit toolchain...\n"
    cd "${HOME}/toolchains"
    git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android-9.0.0_r61
    cd "${KERNEL_ROOT}"
fi

# Set toolchain paths
export CLANG_PATH="${HOME}/toolchains/clang-4691093/bin"
export GCC_PATH="${HOME}/toolchains/aarch64-linux-android-4.9/bin"
export GCC_ARM32_PATH="${HOME}/toolchains/arm-linux-androideabi-4.9/bin"

export CC="${CLANG_PATH}/clang"
export CLANG_TRIPLE="aarch64-linux-gnu-"
export CROSS_COMPILE="${GCC_PATH}/aarch64-linux-android-"
export CROSS_COMPILE_ARM32="${GCC_ARM32_PATH}/arm-linux-androideabi-"

build_kernel(){
    echo -e "\n[INFO]: Building kernel for Xiaomi YSL (MSM8953)...\n"
    
    # Only clean if --clean flag is passed
    if [[ "$1" == "--clean" ]]; then
        echo -e "[INFO]: Cleaning build directory...\n"
        rm -rf "${KERNEL_ROOT}/out"
        mkdir -p "${KERNEL_ROOT}/out"
    else
        echo -e "[INFO]: Using incremental build (pass --clean to start fresh)...\n"
        mkdir -p "${KERNEL_ROOT}/out"
    fi
    
    # STEP 1: Generate defconfig (only if .config doesn't exist)
    if [ ! -f "${KERNEL_ROOT}/out/.config" ]; then
        echo -e "[INFO]: Generating defconfig...\n"
        make -j"$(nproc)" \
            -C "${KERNEL_ROOT}" \
            O="${KERNEL_ROOT}/out" \
            ARCH=arm64 \
            ysl-perf_defconfig
        
        if [ $? -ne 0 ]; then
            echo -e "\n[ERROR]: defconfig generation failed!\n"
            exit 1
        fi

        # STEP 2: Disable problematic options for older Clang
        echo -e "\n[INFO]: Adjusting kernel config for compatibility...\n"
        scripts/config --file "${KERNEL_ROOT}/out/.config" \
            --disable CONFIG_CC_STACKPROTECTOR_STRONG \
            --disable CONFIG_RANDOMIZE_BASE \
            --disable LTO_CLANG \
            --disable CFI_CLANG
        
        # Regenerate config with new settings
        make -j"$(nproc)" \
            -C "${KERNEL_ROOT}" \
            O="${KERNEL_ROOT}/out" \
            ARCH=arm64 \
            olddefconfig

        # STEP 3: Open menuconfig (optional)
        echo -e "\n[INFO]: Opening menuconfig...\n"
        make -j"$(nproc)" \
            -C "${KERNEL_ROOT}" \
            O="${KERNEL_ROOT}/out" \
            ARCH=arm64 \
            menuconfig
        
        if [ $? -ne 0 ]; then
            echo -e "\n[ERROR]: menuconfig failed!\n"
            exit 1
        fi
    else
        echo -e "[INFO]: Using existing .config (pass --clean to regenerate)...\n"
    fi

    # STEP 4: Build the kernel (incremental if files exist)
    echo -e "\n[INFO]: Building kernel Image...\n"
    echo -e "[INFO]: Build log will be saved to ${KERNEL_ROOT}/build.log\n"
    
    PATH="${CLANG_PATH}:${GCC_PATH}:${GCC_ARM32_PATH}:${PATH}" \
    make -k -j"$(nproc)" \
        -C "${KERNEL_ROOT}" \
        O="${KERNEL_ROOT}/out" \
        ARCH=arm64 \
        CC="${CC}" \
        CLANG_TRIPLE="${CLANG_TRIPLE}" \
        CROSS_COMPILE="${CROSS_COMPILE}" \
        CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32}" \
        KCFLAGS="-Wno-unknown-warning-option" \
        Image.gz-dtb 2>&1 | tee "${KERNEL_ROOT}/build.log"
    
    BUILD_RESULT=${PIPESTATUS[0]}
    
    if [ $BUILD_RESULT -ne 0 ]; then
        echo -e "\n[ERROR]: Kernel build failed!\n"
        echo -e "[INFO]: Extracting errors from build log...\n"
        echo -e "\n========== BUILD ERRORS ==========\n"
        grep -i "error:" "${KERNEL_ROOT}/build.log" | tail -20
        echo -e "\n========== LAST 30 LINES OF BUILD LOG ==========\n"
        tail -30 "${KERNEL_ROOT}/build.log"
        echo -e "\n[INFO]: Full build log saved at: ${KERNEL_ROOT}/build.log\n"
        exit 1
    fi

    # Copy the built kernel to the build directory
    if [ -f "${KERNEL_ROOT}/out/arch/arm64/boot/Image.gz-dtb" ]; then
        cp "${KERNEL_ROOT}/out/arch/arm64/boot/Image.gz-dtb" "${KERNEL_ROOT}/build"
        echo -e "\n[INFO]: BUILD FINISHED..!"
        echo -e "[INFO]: Kernel image: ${KERNEL_ROOT}/build/Image.gz-dtb\n"
    elif [ -f "${KERNEL_ROOT}/out/arch/arm64/boot/Image.gz" ]; then
        cp "${KERNEL_ROOT}/out/arch/arm64/boot/Image.gz" "${KERNEL_ROOT}/build"
        echo -e "\n[INFO]: BUILD FINISHED..!"
        echo -e "[INFO]: Kernel image: ${KERNEL_ROOT}/build/Image.gz\n"
    else
        echo -e "\n[ERROR]: Kernel image not found!\n"
        exit 1
    fi
}

build_kernel "$@"
