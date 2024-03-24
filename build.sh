#!/bin/bash

# Enable "exit on error"
set -e

VERSION=$1
REPO=$2
PLATFORM=$3
ARCH=$4
IS_MONOLITHIC_BUILD=$5
IS_DEBUG=$6
IOS_DEPLOY_TARGET=$7

cd ~
if [ "$PLATFORM" = "win" ]; then  
gclient
fi
# Build

mkdir v8
cd v8

echo "=====[ Fetching V8 ]====="
if [[ $PLATFORM == "win" || $PLATFORM == "mac" || $PLATFORM == "ios" ]]; then  
fetch v8
fi
if [[ "$PLATFORM" == "linux" || "$PLATFORM" == "android" ]]; then
fetch --nohooks v8
fi
echo "target_os = ['$PLATFORM']" >> .gclient
cd ~/v8/v8
git checkout $VERSION

if [[ $PLATFORM == "win" || "$PLATFORM" == "android" ]]; then
gclient sync
fi

if [[ "$PLATFORM" = "linux" || "$PLATFORM" == "android" ]]; then
if [[ $PLATFORM = "linux" ]]; then
./build/install-build-deps.sh --no-syms --no-nacl --no-prompt
else
./build/install-build-deps.sh --no-syms --no-nacl --no-prompt --android
fi
./build/linux/sysroot_scripts/install-sysroot.py --arch=$ARCH
fi
if [ $PLATFORM != "win" ]; then  
gclient runhooks
fi

echo "=====[ Building V8 ]====="

ARGS=""
if [ $PLATFORM = "win" ]; then
ARGS+="is_clang=true use_lld=false"
fi
if [ $PLATFORM = "ios" ]; then
ARGS+="v8_enable_pointer_compression=false ios_enable_code_signing=false ios_deployment_target=\"$IOS_DEPLOY_TARGET\""
fi
if [ $IS_MONOLITHIC_BUILD = "true" ]; then
ARGS+=" v8_monolithic=true is_component_build=false"
else
ARGS+=" v8_monolithic=false is_component_build=true"
fi
if [ $IS_DEBUG = "true" ]; then
ARGS+=" is_debug=true"
else
ARGS+=" is_debug=false"
fi

if [ $PLATFORM = "win" ]; then
 sed -i 's/"-Wmissing-field-initializers",/"-Wmissing-field-initializers","-D_SILENCE_ALL_CXX20_DEPRECATION_WARNINGS",/' BUILD.gn
fi

if [ $ARCH = "x86" ]; then
OARCH="x86"
ARCH="ia32"
else
OARCH=$ARCH
fi
python ./tools/dev/v8gen.py $ARCH.release -vv --no-goma -- $ARGS target_os=\"$PLATFORM\" target_cpu=\"$OARCH\" v8_target_cpu=\"$OARCH\" use_goma=false enable_nacl=false use_custom_libcxx=false v8_enable_sandbox=false v8_enable_i18n_support=true v8_use_external_startup_data=false symbol_level=0

ninja -C out.gn/$ARCH.release -t clean 1> nul
if [ $IS_MONOLITHIC_BUILD = "true" ]; then
ninja -C out.gn/$ARCH.release v8_monolith
else
ninja -C out.gn/$ARCH.release v8
fi

# ZIP

cd $REPO
mkdir -p ~/v8_zip 1> nul
cp -r ~/v8/v8/include ~/v8_zip 1> nul

# Disable "exit on error"
set +e
find ~/v8/v8/out.gn/$ARCH.release ~/v8/v8/out.gn/$ARCH.release/obj -type f -maxdepth 1 -not -name "*.stamp" -not -name "*.ninja" -not -name "*.json" -not -name "*.TOC"
cp ~/v8/v8/out.gn/$ARCH.release/args.gn ~/v8_zip
cp ~/v8/v8/out.gn/$ARCH.release/icudtl.dat ~/v8_zip
cp ~/v8/v8/out.gn/$ARCH.release/*.so ~/v8_zip
cp ~/v8/v8/out.gn/$ARCH.release/*.dylib ~/v8_zip
cp ~/v8/v8/out.gn/$ARCH.release/*.dll ~/v8_zip
cp ~/v8/v8/out.gn/$ARCH.release/obj/*.a ~/v8_zip
cp ~/v8/v8/out.gn/$ARCH.release/obj/*.lib ~/v8_zip

# Enable "exit on error"
set -e

if [ $PLATFORM != "win" ]; then
zip -r v8.zip ~/v8_zip/* 1> nul
else
7z a v8.zip ~/v8_zip/* 1> nul
fi
