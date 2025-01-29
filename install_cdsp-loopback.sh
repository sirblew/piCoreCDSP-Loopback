#!/bin/sh -e

CDSP_VERSION="v3.0.0"  # https://github.com/HEnquist/camilladsp/releases/tag/v3.0.0
CAMILLA_GUI_VERSION="v3.0.0"  # https://github.com/HEnquist/camillagui-backend/releases
PYCDSP_VERSION="v3.0.0"  # https://github.com/HEnquist/pycamilladsp/releases
PYCDSP_PLOT_VERSION="v3.0.0"  # https://github.com/HEnquist/pycamilladsp-plot/releases

BUILD_DIR="/tmp/piCoreCDSP"

### Decide for 64bit or 32bit installation
if [ "aarch64" = "$(uname -m)" ]; then
    use32bit=false
else
    use32bit=true
fi

### Abort, if piCoreCDSP extension is already installed
if [ -f "/etc/sysconfig/tcedir/optional/piCoreCDSP.tcz" ]; then
    >&2 echo "Uninstall the piCoreCDSP Extension and reboot, before installing it again"
    >&2 echo "In Main Page > Extensions > Installed > select 'piCoreCDSP.tcz' and press 'Delete'"
    exit 1
fi

### Exit, if not enough free space
requiredSpaceInMB=100
availableSpaceInMB=$(/bin/df -m /dev/mmcblk0p2 | awk 'NR==2 { print $4 }')
if [[ $availableSpaceInMB -le $requiredSpaceInMB ]]; then
    >&2 echo "Not enough free space"
    >&2 echo "Increase SD-Card size: Main Page > Additional functions > Resize FS"
    exit 1
fi

### Ensure fresh build dir exists
if [ -d $BUILD_DIR ]; then
    >&2 echo "Reboot before running the script again."
    exit 1
fi
mkdir -p $BUILD_DIR

# Installs a module from the piCorePlayer repository - if not already installed.
# Call like this: install_if_missing module_name
install_if_missing(){
  if ! tce-status -i | grep -q "$1" ; then
    pcp-load -wil "$1"
  fi
}

# Installs a module from the piCorePlayer repository, at least until the next reboot - if not already installed.
# Call like this: install_temporarily_if_missing module_name
install_temporarily_if_missing(){
  if ! tce-status -i | grep -q "$1" ; then
    pcp-load -wil -t /tmp "$1" # Downloads to /tmp/optional and loads extensions temporarily
  fi
}

set -v


### Creating CDSP data folders with default configuration

cd /mnt/mmcblk0p2/tce
mkdir -p camilladsp/configs
mkdir -p camilladsp/coeffs
cd /mnt/mmcblk0p2/tce/camilladsp

echo '
devices:
  samplerate: 192000
  chunksize: 2048
  queuelimit: 4
  capture:
    type: Stdin
    channels: 2
    device:  "hw:CARD=Loopback,DEV=0"
    format: S32LE
  playback:
    type: Alsa
    channels: 2
    device:  "hdmi:CARD=vc4hdmi,DEV=0"
    format: S24LE
filters: []
mixers: {}
processors: []
pipeline: []
' > default_config.yml
/bin/cp default_config.yml configs/Null.yml

echo '
config_path: /mnt/mmcblk0p2/tce/camilladsp/configs/Null.yml
mute:
- false
- false
- false
- false
- false
volume:
- 0.0
- 0.0
- 0.0
- 0.0
- 0.0
' > camilladsp_statefile.yml


### Configuring ALSA 

sudo chmod 664 /etc/asound.conf
sudo chown root:staff /etc/asound.conf
echo "options snd-aloop" > /tmp/snd-aloop.conf
sudo cp /tmp/snd-aloop.conf /etc/modprobe.d/snd-aloop.conf
echo "etc/modprobe.d/snd-aloop.conf" >> /opt/.filetool.lst

### Set Squeezelite and Shairport output to CamillaDSP

sed 's/^OUTPUT=.*/OUTPUT="hw:CARD=Loopback,DEV=1"/' -i /usr/local/etc/pcp/pcp.cfg
sed 's/^SHAIRPORT_OUT=.*/SHAIRPORT_OUT="hw:CARD=Loopback,DEV=0"/' -i /usr/local/etc/pcp/pcp.cfg


### Downloading CamillaDSP

mkdir -p ${BUILD_DIR}/usr/local/
cd ${BUILD_DIR}/usr/local/
if $use32bit; then
    CDSP_URL=https://github.com/HEnquist/camilladsp/releases/download/${CDSP_VERSION}/camilladsp-linux-armv7.tar.gz
else
    CDSP_URL=https://github.com/HEnquist/camilladsp/releases/download/${CDSP_VERSION}/camilladsp-linux-aarch64.tar.gz
fi
wget -O camilladsp.tar.gz $CDSP_URL
tar -xvf camilladsp.tar.gz
rm -f camilladsp.tar.gz


### Building CamillaGUI

install_if_missing python3.11
install_temporarily_if_missing python3.11-pip
$use32bit && install_temporarily_if_missing python3.11-dev
sudo mkdir -m 775 /usr/local/camillagui
sudo chown root:staff /usr/local/camillagui
cd /usr/local/camillagui
python3 -m venv environment
(tr -d '\r' < environment/bin/activate) > environment/bin/activate_new # Create fixed version of the activate script. See https://stackoverflow.com/a/44446239
mv -f environment/bin/activate_new environment/bin/activate
source environment/bin/activate # activate custom python environment
python3 -m pip install --upgrade pip
pip install websocket_client aiohttp jsonschema setuptools
pip install git+https://github.com/HEnquist/pycamilladsp.git@${PYCDSP_VERSION}
pip install git+https://github.com/HEnquist/pycamilladsp-plot.git@${PYCDSP_PLOT_VERSION}
deactivate # deactivate custom python environment
wget https://github.com/HEnquist/camillagui-backend/releases/download/${CAMILLA_GUI_VERSION}/camillagui.zip
unzip camillagui.zip
rm -f camillagui.zip
echo '
camilla_host: "0.0.0.0"
camilla_port: 1234
bind_address: "0.0.0.0"
port: 5000
ssl_certificate: null
ssl_private_key: null
gui_config_file: null
config_dir: "/mnt/mmcblk0p2/tce/camilladsp/configs"
coeff_dir: "/mnt/mmcblk0p2/tce/camilladsp/coeffs"
default_config: "/mnt/mmcblk0p2/tce/camilladsp/default_config.yml"
statefile_path: "/mnt/mmcblk0p2/tce/camilladsp/camilladsp_statefile.yml"
log_file: "/tmp/camilladsp.log"
on_set_active_config: null
on_get_active_config: null
supported_capture_types: ["Stdin", "Alsa"]
supported_playback_types: ["Alsa"]
' > config/camillagui.yml
mkdir -p ${BUILD_DIR}/usr/local/
sudo mv /usr/local/camillagui ${BUILD_DIR}/usr/local/


### Creating autorun script

mkdir -p ${BUILD_DIR}/usr/local/tce.installed/
cd ${BUILD_DIR}/usr/local/tce.installed/
echo "#!/bin/sh

sudo -u tc sh -c 'while [ ! -f /usr/local/bin/python3 ]; do sleep 1; done
source /usr/local/camillagui/environment/bin/activate
python3 /usr/local/camillagui/main.py &' &" > piCoreCDSP
chmod 775 piCoreCDSP


### Building and installing piCoreCDSP extension

cd /tmp
install_temporarily_if_missing squashfs-tools
mksquashfs piCoreCDSP piCoreCDSP.tcz
mv -f piCoreCDSP.tcz /etc/sysconfig/tcedir/optional
echo "python3.11.tcz" > /etc/sysconfig/tcedir/optional/piCoreCDSP.tcz.dep
echo piCoreCDSP.tcz >> /etc/sysconfig/tcedir/onboot.lst


### Saving changes and rebooting

pcp backup
pcp reboot
