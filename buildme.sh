#!/bin/sh

#  buildme.sh is stupid simple.  it requires gem "fpm" and package "rpm-build" (for rhel systems) is installed
#
#  drop this script into the root of a git repo, and it will build you an RPM of all the files in the path
#  excluding the .git dir and this script (buildme.sh)
#
#  this will place a package in the same location you ran the script and remove it's temporary files

########################################### edit below to suit your needs

VERSION=0.0
ITERATION=5
# this is the target system architecture for the pacakge
PKGARCH=noarch
# this is the package name
PKGNAME=webrockit-poller
# this prefix will be added to all files in the package
INSTALLDIR=/opt/phantomjs/collectoids/webrockit-poller
# this is the target type of package, usually deb or rpm
PKGTYPE=rpm
# this is the relative path where the final package should be copied into
FINALPKGDROP=finalpkg
# this should either be "files" to create an package out of this entire repo, or relative path+name of a files tarball
# often  binpkg/*.tar.gz is sufficient here
SRCTYPE=files

URL="http://webrockit.io"

# cheap verify if we're on an rpm or dpkg system
if [ -e /etc/redhat-release ]
then
    PKGTOOL=rpm
else
    PKGTOOL=dpkg
fi

########################################### 
# don't edit below here, unless you're feeling... dangerous

# check build tools
gem list fpm | grep -q fpm || sudo gem install fpm
if [ "${PKGTOOL}" == "rpm" ];
then
    rpm --quiet -q rpm-build || sudo yum -q -y install rpm-build
else
    dpkg -s XXTODO
fi

# check specific build dependencies
./build-requires.sh
if [ $? -ne 0 ]
then
    exit 1
fi

# fetch source/binary bundle if we're that type of build
if [ ${SRCTYPE} != "files" ]
then
    # *******  run fetch-binary.sh first, to stage the binary tarball first
    ./fetch-binary.sh
    if [ $? -ne 0 ]
    then
        echo ERROR on binary download via ./fetch-binary.sh
        exit 1
    fi
fi

# build me a package, for great justice!

OLDPWD=`pwd`
builddir=/var/tmp/`date +%s`
buildtargetpath=${builddir}${INSTALLDIR}
mkdir -p ${FINALPKGDROP}
mkdir -vp ${buildtargetpath}
if [ "$SRCTYPE" == "files" ]
then
    find . -type d -exec mkdir -p ${buildtargetpath}/{} \; 
    find . -type f -exec cp -v {} ${buildtargetpath}/{} \; 
    rm -rf ${buildtargetpath}/${FINALPKGDROP}
    rm -rf ${buildtargetpath}/.git
    rm -rf ${buildtargetpath}/buildme.sh
    rm -f ${buildtargetpath}/.gitignore
    #rm -f ${buildtargetpath}/Changelog
    #rm -f ${buildtargetpath}/LICENSE.txt
    #rm -f ${buildtargetpath}/README.md
    rm -f ${buildtargetpath}/extra-build-commands.sh
    rm -f ${buildtargetpath}/fetch-binary.sh
    rm -f ${buildtargetpath}/build-request.sh
else
    tar xvf ${SRCTYPE} --strip-components=1 -C ${buildtargetpath}
fi
cd ${builddir}
sh ${OLDPWD}/extra-build-commands.sh
fpm -s dir -t ${PKGTYPE} -n ${PKGNAME} -v ${VERSION} --iteration ${ITERATION} --url ${URL} -a ${PKGARCH} ./*
mv ${PKGNAME}-${VERSION}-${ITERATION}.${PKGARCH}.${PKGTYPE} ${OLDPWD}/${FINALPKGDROP}
cd ${OLDPWD}
rm -rf ${builddir}
