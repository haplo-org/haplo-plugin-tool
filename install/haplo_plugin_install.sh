#!/bin/sh

# exit the script if any command has a non-zero exit value
set -e

DEV_SUPPORT_DIR=~/haplo-dev-support
HAPLO_PLUGIN_INSTALL_DIR=$DEV_SUPPORT_DIR/haplo-plugin
mkdir -p $HAPLO_PLUGIN_INSTALL_DIR
cd $HAPLO_PLUGIN_INSTALL_DIR

# you must update the checksum if updating the version
jruby_version="9.0.5.0"
jruby_filename="jruby-bin-$jruby_version.tar.gz"
jruby_checksum="9369cfd8b19841eae2a764988121fc7d43b313b3"

# clear up any previous install clutter
if [ -d jruby ]; then rm -r jruby; fi
if [ -d jruby-$jruby_version ]; then rm -r jruby-$jruby_version; fi

jruby_checksum_matches() {
  downloaded_checksum=`openssl sha1 < $jruby_filename`
  [ $jruby_checksum = $downloaded_checksum ]
}

download_jruby() {
  echo "Downloading JRuby $jruby_version ..."
  curl -O "https://s3.amazonaws.com/jruby.org/downloads/$jruby_version/$jruby_filename"
}

if [ -f $jruby_filename ]; then
  if ! jruby_checksum_matches; then
    download_jruby
  else
    echo "Found $jruby_filename - skipping download ..."
  fi
else
  download_jruby
fi

echo "Verifying SHA1 checksum ..."
if ! jruby_checksum_matches; then
  echo "ERROR: SHA1 checksum mismatch, couldn't verify JRuby download"; exit
fi

echo "Unpacking JRuby ..."
tar -zxf $jruby_filename
# assumes that jruby maintains "jruby-version" naming scheme for release tarballs
mv jruby-$jruby_version jruby

export PATH=$HAPLO_PLUGIN_INSTALL_DIR/jruby/bin:$PATH
echo "Installing Haplo plugin tool gem ..."
jgem install haplo

if grep -q "# added by haplo-plugin-install" ~/.profile; then
  echo "****"
  echo "  Not automatically adding install location to PATH in ~/.profile:"
  echo "    > Found a line in ~/.profile from a previous run of the install tool"
  echo ""
  echo "  Please check your ~/.profile and either:"
  echo "    1) Delete the line inside ~/.profile containing \"# added by haplo-plugin-install\""
  echo "       and re-run the install tool"
  echo "    or"
  echo "    2) Manually fix the line to point to the correct location as below:"
  echo "          export PATH=\$PATH:$HAPLO_PLUGIN_INSTALL_DIR/jruby/bin"
  echo "       and then run:"
  echo "          source ~/.profile"
  echo "       to complete the installation"
  echo "****"
else
  echo ""
  echo "Appending JRuby to user path in ~/.profile to persist across sessions ..."
  echo "export PATH=\$PATH:$HAPLO_PLUGIN_INSTALL_DIR/jruby/bin # added by haplo-plugin-install" >> ~/.profile
  echo ""
  echo "JRuby & Haplo plugin tool successfully installed"
  echo ""
  echo "  For the changes to the PATH to be reflected in your shell run:"
  echo "      source ~/.profile"
  echo "  or open a new Terminal window"
  echo ""
  echo "To get started with the plugin tool run: haplo-plugin --help"
  echo "or view the documentation at: http://docs.haplo.org/dev/tool/plugin"
  echo ""
fi

