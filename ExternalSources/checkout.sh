#!/bin/sh

set -x

git clone -b "v1.7" git://github.com/pokeb/asi-http-request.git

if [ "$1" = "st3fan" ]; then
  git clone git@github.com:st3fan/ios-openssl.git
  git clone git@github.com:st3fan/ios-jpake.git
else
  git clone -b "v1.0" git://github.com/st3fan/ios-openssl.git
  git clone -b "v1.0" git://github.com/st3fan/ios-jpake.git
fi

