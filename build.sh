#!/bin/bash

# Enable "exit on error"
set -e

VERSION=$1
REPO=$2
PLATFORM=$3
SHORT_PLATFORM=$4
ARCH=$5
SHORT_ARCH=$6
IS_MONOLITHIC_BUILD=$7
IOS_DEPLOY_TARGET=$8

# Conf
if [[ "$SHORT_PLATFORM" == "linux" || "$SHORT_PLATFORM" == "android" ]]; then
    sudo apt-get update -y 1> nul
    sudo apt-get upgrade -y 1> nul
fi

git config --global user.name "V8 Builder" 1> nul
git config --global user.email "v8.builder@localhost" 1> nul
git config --global core.autocrlf false 1> nul
git config --global core.filemode false 1> nul

cd ~
echo "=====[ Getting Depot Tools ]====="
if [ $SHORT_PLATFORM = "win" ]; then    
    powershell -command "Invoke-WebRequest https://storage.googleapis.com/chrome-infra/depot_tools.zip -O depot_tools.zip" 1> nul
    7z x depot_tools.zip -o* 1> nul
    export DEPOT_TOOLS_WIN_TOOLCHAIN=0
else
    git clone -q https://chromium.googlesource.com/chromium/tools/depot_tools.git 1> nul
fi
export PATH=$(pwd)/depot_tools:$PATH
if [ $SHORT_PLATFORM = "win" ]; then  
gclient
fi
# Build

mkdir v8
cd v8

echo "=====[ Fetching V8 ]====="
if [[ $SHORT_PLATFORM == "win" || $SHORT_PLATFORM == "mac" || $SHORT_PLATFORM == "ios" ]]; then  
fetch v8
fi
if [[ "$SHORT_PLATFORM" == "linux" || "$SHORT_PLATFORM" == "android" ]]; then
fetch --nohooks v8
fi
echo "target_os = ['$SHORT_PLATFORM']" >> .gclient
cd ~/v8/v8
git checkout $VERSION

if [[ $SHORT_PLATFORM == "win" || "$SHORT_PLATFORM" == "android" ]]; then
gclient sync
fi

if [[ "$SHORT_PLATFORM" = "linux" || "$SHORT_PLATFORM" == "android" ]]; then
if [[ $SHORT_PLATFORM = "linux" ]]; then
./build/install-build-deps.sh --no-syms --no-nacl --no-prompt
else
./build/install-build-deps.sh --no-syms --no-nacl --no-prompt --android
fi
./build/linux/sysroot_scripts/install-sysroot.py --arch=$SHORT_ARCH
fi
if [ $SHORT_PLATFORM != "win" ]; then  
gclient runhooks
fi

echo "=====[ Building V8 ]====="

ARGS=""
if [ $SHORT_PLATFORM = "win" ]; then
ARGS="is_clang=true use_lld=false"
sed -i 's/"-Wmissing-field-initializers",/"-Wmissing-field-initializers","-D_SILENCE_ALL_CXX20_DEPRECATION_WARNINGS",/' BUILD.gn
else if [[ "$SHORT_PLATFORM" = "linux" || "$SHORT_PLATFORM" == "android" ]]; then
sed -i 's/"-Wmissing-field-initializers",/"-Wmissing-field-initializers","-Wctad-maybe-unsupported",/' BUILD.gn
fi
fi
if [ $SHORT_PLATFORM = "ios" ]; then
ARGS="v8_enable_pointer_compression=false ios_enable_code_signing=false ios_deployment_target=\"$IOS_DEPLOY_TARGET\""
fi
if [ $IS_MONOLITHIC_BUILD = "true" ]; then
ARGS+=" v8_monolithic=true"
else
ARGS+=" v8_monolithic=false"
fi
python ./tools/dev/v8gen.py $ARCH -vv --no-goma -- $ARGS target_os=\"$SHORT_PLATFORM\" target_cpu=\"$SHORT_ARCH\" v8_target_cpu=\"$SHORT_ARCH\" is_component_build=false use_goma=false enable_nacl=false use_custom_libcxx=false v8_enable_sandbox=false v8_enable_i18n_support=true v8_use_external_startup_data=false symbol_level=0

ninja -C out.gn/$ARCH -t clean 1> nul
if [ $IS_MONOLITHIC_BUILD = "true" ]; then
ninja -C out.gn/$ARCH v8_monolith
else
ninja -C out.gn/$ARCH v8
fi

# ZIP

cd $REPO
mkdir -p ~/v8_zip 1> nul
cp -r ~/v8/v8/include ~/v8_zip 1> nul

# Disable "exit on error"
set +e
find ~/v8/v8/out.gn/$ARCH -type f -maxdepth 1 -not -name "*.stamp" -not -name "*.ninja"
find ~/v8/v8/out.gn/$ARCH/obj -type f -maxdepth 1 -not -name "*.stamp" -not -name "*.ninja"
cp ~/v8/v8/out.gn/$ARCH/args.gn ~/v8_zip
cp ~/v8/v8/out.gn/$ARCH/icudtl.dat ~/v8_zip
cp ~/v8/v8/out.gn/$ARCH/*.dll ~/v8_zip
cp ~/v8/v8/out.gn/$ARCH/obj/v8*.lib ~/v8_zip
cp ~/v8/v8/out.gn/$ARCH/obj/libv8*.a ~/v8_zip
cp ~/v8/v8/out.gn/$ARCH/obj/*.dylib ~/v8_zip

# Enable "exit on error"
set -e

if [ $IS_MONOLITHIC_BUILD = "true" ]; then
_NAME="v8_monolith_$PLATFORM.zip"
else
_NAME="v8_$PLATFORM.zip"
fi

if [ $SHORT_PLATFORM != "win" ]; then
zip -r $_NAME ~/v8_zip/* 1> nul
else
7z a $_NAME ~/v8_zip 1> nul
fi
