#!/bin/bash

# This script downloads and builds the OpenSSL FIPS capable binary.

# This scripts was done after digging from multiple sources:
# https://github.com/st3fan/ios-openssl
# https://github.com/x2on/OpenSSL-for-iPhone/blob/master/build-libssl.sh
# https://gist.github.com/foozmeat/5154962
# Peter Steinberger, PSPDFKit GmbH, @steipete.
# Felix Schwarz, IOSPIRIT GmbH, @felix_schwarz.

set -e

usage ()
{
	echo "usage: $0 [iOS SDK version (defaults to latest)] [tvOS SDK version (defaults to latest)] [OS X minimum deployment target (defaults to 10.7)]"
	exit 127
}

if [ $1 -e "-h" ]; then
	usage
fi

if [ -z $1 ]; then
	IOS_SDK_VERSION="" #"9.1"
	IOS_MIN_SDK_VERSION="7.0"
else
	IOS_SDK_VERSION=$1
fi

export http_proxy=proxy-fr-croissy.gemalto.com:8080
export https_proxy=$http_proxy

OPENSSL_VERSION="openssl-1.0.1c"
FIPS_VERSION="openssl-fips-2.0.10"
INCORE_VERSION="ios-incore-2.0.1"
DEVELOPER=`xcode-select -print-path`

buildIncore()
{
	resetFIPS
	resetIncore
	pushd "${FIPS_VERSION}" > /dev/null
	
	echo "Building Fips"
	
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc"
	SYSTEM="darwin"
	MACHINE="i386"

	SYSTEM="Darwin"
	MACHINE="i386"
	KERNEL_BITS=32

	export MACHINE
	export SYSTEM
	export KERNEL_BITS
	
	./config &> "/tmp/${FIPS_VERSION}-Incore.log"
	make >> "/tmp/${FIPS_VERSION}-Incore.log" 2>&1
	echo "Building Incore"
	cd iOS
	make >> "/tmp/${FIPS_VERSION}-Incore.log" 2>&1
	echo "Copying incore_macho to /usr/local/bin"
	cp incore_macho /usr/local/bin
	popd > /dev/null
}

buildFIPS()
{
	ARCH=$1
	resetFIPS
	echo "Building ${FIPS_VERSION} for ${ARCH}"
	
	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
	fi
  
	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc"

	MACHINE=`echo -"$ARCH" | sed -e 's/^-//'`
	SYSTEM="iphoneos"
	BUILD="build"

	export MACHINE
	export SYSTEM
	export BUILD

	export FIPSDIR="/tmp/$FIPS_VERSION-$ARCH"
	export FIPSLIBDIR=$FIPSDIR/lib
	export CONFIG_OPTIONS="no-asm no-shared"

	export HOSTCC=/usr/bin/cc
	export HOSTCFLAGS="-arch i386"

	pushd . > /dev/null
	cd "${FIPS_VERSION}"
	./config

	if [[ "${PLATFORM}" == "iPhoneOS" ]]; then
		sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min="$IOS_MIN_SDK_VERSION" !" "Makefile"
	else
		sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -mios-simulator-version-min="$IOS_MIN_SDK_VERSION" !" "Makefile"
	fi

	make
	make install
	make clean
	popd > /dev/null
}

buildIOS()
{
	ARCH=$1
	resetOpenSSL
	
	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"
  
	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
	fi
  
	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc -arch ${ARCH}"
		
	export HOSTCC=/usr/bin/cc
	export HOSTCFLAGS="-arch ${ARCH}ß"
	export FIPS_SIG=/usr/local/bin/incore_macho
	export CROSS_TYPE=OS
	cross_arch="-${ARCH}"
    cross_type=`echo $CROSS_TYPE | tr '[A-Z]' '[a-z]'`
    MACHINE=`echo "$cross_arch" | sed -e 's/^-//'`
	SYSTEM="iphoneos"
	BUILD="build"

	export MACHINE
	export SYSTEM
	export BUILD	
	export FIPSDIR="/tmp/$FIPS_VERSION-$ARCH"
	export FIPSLIBDIR=$FIPSDIR/lib
	
	echo "Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"

	./config fips no-asm no-shared
	echo "Done Configuring"

	if [[ "${PLATFORM}" == "iPhoneOS" ]]; then
		sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min="$IOS_MIN_SDK_VERSION" !" "Makefile"
	else
		sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -mios-simulator-version-min="$IOS_MIN_SDK_VERSION" !" "Makefile"
	fi

	echo "Running make"
	make

    echo "Copy libcrypto.a to /tmp/"
    mkdir -p /tmp/$OPENSSL_VERSION-$ARCH/lib
    cp libcrypto.a /tmp/$OPENSSL_VERSION-$ARCH/lib

	popd > /dev/null
}

# use this script if you want to build using openssl above 1.0.1c
# it is not guaranted that the final libcrypto.a will contains any fips symbols
buildIOS_1_0_1c_above()
{
	ARCH=$1
	resetOpenSSL
	
	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"
  
	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
	fi
  
	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc -arch ${ARCH}"
		
	export HOSTCC=/usr/bin/cc
	export HOSTCFLAGS="-arch ${ARCH}ß"
	export FIPS_SIG=/usr/local/bin/incore_macho
	export CROSS_TYPE=OS
	cross_arch="-${ARCH}"
    cross_type=`echo $CROSS_TYPE | tr '[A-Z]' '[a-z]'`
    MACHINE=`echo "$cross_arch" | sed -e 's/^-//'`
	SYSTEM="iphoneos"
	BUILD="build"

	export MACHINE
	export SYSTEM
	export BUILD

	export FIPSDIR="/tmp/$FIPS_VERSION-$ARCH"
	export FIPSLIBDIR=$FIPSDIR/lib

	# Use below config options if you want to disable some options, see here for more details https://wiki.openssl.org/index.php/Compilation_and_Installation#Configure_Options
	# Some of the config might give compile error
	#export CONFIG_OPTIONS="no-asm no-shared no-sha0 no-cast no-md2 no-seed no-ssl2 no-ssl3 no-srp no-psk"
	
	echo "Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"

	./config fips no-asm no-shared

	echo "Done Configuring"

	if [[ "${PLATFORM}" == "iPhoneOS" ]]; then
		sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min="$IOS_MIN_SDK_VERSION" !" "Makefile"
	else
		sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -mios-simulator-version-min="$IOS_MIN_SDK_VERSION" !" "Makefile"
	fi

	# there's an issue when building openssl on Mac, see here https://stackoverflow.com/questions/37063202/getting-libcrypto-ar-error-while-compiling-openssl-for-mac
	echo "Patch files"
    patch Makefile < ../MainMake.patch
    patch apps/Makefile < ../AppMake.patch
    patch test/Makefile < ../TestMake.patch
    patch apps/openssl.cnf < ../openssl-conf.patch

	echo "Running make"
	make

    echo "Copy libcrypto.a to /tmp/"
    mkdir -p /tmp/$OPENSSL_VERSION-iOS-$ARCH/lib
    cp libcrypto.a /tmp/$OPENSSL_VERSION-iOS-$ARCH/lib
    cp -rf /tmp/$FIPS_VERSION-$ARCH/include/openssl include/openssl
    cp -rf /tmp/$OPENSSL_VERSION-$ARCH/include/openssl include/openssl

	echo "Running make install"
	make install_sw

	echo "Running make clean"
	make clean && make dclean

	echo "Unpatch files"
    patch -R Makefile < ../MainMake.patch
    patch -R apps/Makefile < ../AppMake.patch
    patch -R test/Makefile < ../TestMake.patch
    patch -R apps/openssl.cnf < ../openssl-conf.patch

	popd > /dev/null
}

resetIncore()
{
	rm -rf "${INCORE_VERSION}"
	echo "Unpacking incore"
	
	tar xfz "${INCORE_VERSION}.tar.gz"
	cp -R "openssl-fips-2.0.1/iOS" ${FIPS_VERSION}
	cp incore_macho.c "${FIPS_VERSION}/iOS"
}

resetFIPS()
{
	rm -rf "${FIPS_VERSION}"
	echo "Unpacking fips"
	
	tar xfz "${FIPS_VERSION}.tar.gz"
	chmod +x "${FIPS_VERSION}/Configure"
}

resetOpenSSL()
{
	rm -rf "${OPENSSL_VERSION}"
	echo "Unpacking openssl"
	tar xfz "${OPENSSL_VERSION}.tar.gz"
	chmod +x "${OPENSSL_VERSION}/Configure"
}

cleanupTemp()
{
	echo "Cleaning up /tmp"
	rm -rf /tmp/${OPENSSL_VERSION}-*
	rm -rf /tmp/${FIPS_VERSION}-*
	rm -rf /usr/local/ssl 
	mkdir -p /usr/local/ssl/fips-2.0
}

echo "Cleaning up"
rm -rf include/openssl/* lib/*

mkdir -p lib
mkdir -p include/openssl/

cleanupTemp

if [ ! -e ${FIPS_VERSION}.tar.gz ]; then
	echo "Downloading ${FIPS_VERSION}.tar.gz"
	curl -O https://www.openssl.org/source/${FIPS_VERSION}.tar.gz
else
	echo "Using ${FIPS_VERSION}.tar.gz"
fi

if [ ! -e ${OPENSSL_VERSION}.tar.gz ]; then
	echo "Downloading ${OPENSSL_VERSION}.tar.gz"
	curl -O https://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz
else
	echo "Using ${OPENSSL_VERSION}.tar.gz"
fi

if [ ! -e ${INCORE_VERSION}.tar.gz ]; then
	echo "Downloading ${INCORE_VERSION}.tar.gz"
	curl -O http://openssl.com/fips/2.0/platforms/ios/${INCORE_VERSION}.tar.gz
else
	echo "Using ${INCORE_VERSION}.tar.gz"
fi

if [ ! -e incore_macho.c ]; then
	echo "Downloading updated incore_macho.c"
	curl -O https://raw.githubusercontent.com/noloader/incore_macho/master/incore_macho.c
else
	echo "Using incore_macho.c"
fi

echo "Building Incore Library"
buildIncore

echo "Building FIPS iOS libraries"

buildFIPS "armv7s"
buildFIPS "armv7"
buildFIPS "arm64"
buildFIPS "i386"
buildFIPS "x86_64"

echo "Building OpenSSL iOS libraries"

buildIOS "armv7s"
buildIOS "armv7"
buildIOS "arm64"
buildIOS "i386"
buildIOS "x86_64"

echo "Building iOS libraries"
lipo -create -output lib/libcrypto_iOS.a \
	"/tmp/${OPENSSL_VERSION}-armv7/lib/libcrypto.a" \
	"/tmp/${OPENSSL_VERSION}-armv7s/lib/libcrypto.a" \
	"/tmp/${OPENSSL_VERSION}-arm64/lib/libcrypto.a" \	
	"/tmp/${OPENSSL_VERSION}-i386/lib/libcrypto.a" \
	"/tmp/${OPENSSL_VERSION}-x86_64/lib/libcrypto.a" \
	
echo "Copy Header files"
cp -rf /tmp/$FIPS_VERSION-$ARCH/include/openssl/* include/openssl/
cp -rf $OPENSSL_VERSION/include/openssl/* include/openssl/

echo "Cleaning up"

cleanupTemp

rm -rf ${OPENSSL_VERSION}
rm -rf ${FIPS_VERSION}

echo "Done..."
