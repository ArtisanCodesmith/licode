#!/bin/bash
SCRIPT=`pwd`/$0
FILENAME=`basename $SCRIPT`
PATHNAME=`dirname $SCRIPT`
ROOT=$PATHNAME/..
BUILD_DIR=$ROOT/build
CURRENT_DIR=`pwd`

LIB_DIR=$BUILD_DIR/libdeps
PREFIX_DIR=$LIB_DIR/build/

pause() {
  read -p "$*"
}

parse_arguments(){
  while [ "$1" != "" ]; do
    case $1 in
      "--enable-gpl")
        ENABLE_GPL=true
        ;;
    esac
    shift
  done
}

install_homebrew(){
  which -s brew
  if [[ $? != 0 ]] ; then
    # Install Homebrew
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi
}

install_brew_deps(){
  brew install glib pkg-config boost libnice cmake mongodb rabbitmq yasm log4cxx
  npm install -g node-gyp
}

install_openssl(){
  if [ -d $LIB_DIR ]; then
    cd $LIB_DIR
    curl -O http://www.openssl.org/source/openssl-1.0.1g.tar.gz
    tar -zxvf openssl-1.0.1g.tar.gz
    cd openssl-1.0.1g
    ./Configure --prefix=$PREFIX_DIR darwin64-x86_64-cc -shared -fPIC
    make -s V=0
    make install_sw
    cd $CURRENT_DIR
  else
    mkdir -p $LIB_DIR
    install_openssl
  fi
}

install_libnice(){
  if [ -d $LIB_DIR ]; then
    cd $LIB_DIR
    curl -O https://nice.freedesktop.org/releases/libnice-0.1.4.tar.gz
    tar -zxvf libnice-0.1.4.tar.gz
    cd libnice-0.1.4
    patch -R ./agent/conncheck.c < $PATHNAME/libnice-014.patch0
    echo nice_agent_set_port_range >> nice/libnice.sym
    ./configure --prefix=$PREFIX_DIR
    make -s V=0
    make install
    cd $CURRENT_DIR
  else
    mkdir -p $LIB_DIR
    install_libnice
  fi
}

install_libsrtp(){
  cd $ROOT/third_party/srtp
  CFLAGS="-fPIC" ./configure --enable-openssl --prefix=$PREFIX_DIR
  make -s V=0
  make uninstall
  make install
  cd $CURRENT_DIR
}

install_mediadeps(){
  brew install opus libvpx x264 
  if [ -d $LIB_DIR ]; then
    cd $LIB_DIR
    curl -O https://www.libav.org/releases/libav-11.6.tar.gz
    tar -zxvf libav-11.6.tar.gz
    cd libav-11.6
    curl -O https://github.com/libav/libav/commit/4d05e9392f84702e3c833efa86e84c7f1cf5f612.patch
    patch libavcodec/libvpxenc.c 4d05e9392f84702e3c833efa86e84c7f1cf5f612.patch
    PKG_CONFIG_PATH=${PREFIX_DIR}/lib/pkgconfig ./configure --prefix=$PREFIX_DIR --enable-shared --enable-gpl --enable-libvpx --enable-libx264 --enable-libopus
    make -s V=0
    make install
    cd $CURRENT_DIR
  else
    mkdir -p $LIB_DIR
    install_mediadeps
  fi
}

install_mediadeps_nogpl(){
  brew install opus libvpx 
  if [ -d $LIB_DIR ]; then
    cd $LIB_DIR
    curl -O https://www.libav.org/releases/libav-11.6.tar.gz
    tar -zxvf libav-11.6.tar.gz
    cd libav-11.6
    curl -O https://github.com/libav/libav/commit/4d05e9392f84702e3c833efa86e84c7f1cf5f612.patch
    patch libavcodec/libvpxenc.c 4d05e9392f84702e3c833efa86e84c7f1cf5f612.patch
    PKG_CONFIG_PATH=${PREFIX_DIR}/lib/pkgconfig ./configure --prefix=$PREFIX_DIR --enable-shared --enable-libvpx --enable-libopus
    make -s V=0
    make install
    cd $CURRENT_DIR
  else
    mkdir -p $LIB_DIR
    install_mediadeps_nogpl
  fi
}

parse_arguments $*

mkdir -p $LIB_DIR

pause "Installing homebrew... [press Enter]"
install_homebrew

pause "Installing deps via homebrew... [press Enter]"
install_brew_deps

pause 'Installing openssl... [press Enter]'
install_openssl


pause 'Installing libsrtp... [press Enter]'
install_libsrtp

if [ "$ENABLE_GPL" = "true" ]; then
  pause "GPL libraries enabled, installing media dependencies..."
  install_mediadeps
else
  pause "No GPL libraries enabled, this disables h264 transcoding, to enable gpl please use the --enable-gpl option"
  install_mediadeps_nogpl
fi
