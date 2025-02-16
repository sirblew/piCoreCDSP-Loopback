# piCoreCDSP-Loopback

This script provides an easy way to turn a Raspberry Pi into an audio streamer with DSP and HDMI output, such as to an AVR. It will install [CamillaDSP](https://github.com/HEnquist/camilladsp) 3.0.0 including [GUI](https://github.com/HEnquist/camillagui-backend) on a fresh [piCorePlayer](https://www.picoreplayer.org/) installation. 

This is a fork of [piCoreCDSP](https://github.com/JWahle/piCoreCDSP) by [Johannes Wahle](https://github.com/JWahle).
This fork excludes the `alsa_csdp` plugin which doesn't seem to work with the HDMI drivers. Instead, it uses the ALSA Loopback device which requires a constant sample rate. Therefore, Squeezelite is configured to resamples all audio to the configured maximum sample rate using a very high quality resampler.

## Requirements
- a fresh piCorePlayer 9.2.0 installation without any modifications
- on an armv7 or arch64 compatible device (Raspi 2/3/4/5)

## Pre-requisite configuration steps
 * Flash [piCorePlayer](https://docs.picoreplayer.org/releases/pcp920/) 9.2.0 onto an SD card.
 * Set the password
 * Enable SSH under the SSH tab on the Security page. No need to reboot just yet.
 * Update Squeezelite using the Update button on the main page.
 * Patch piCorePlayer using the Patch Update under piCorePlayer updates on the main page.
 * Resize the filesystem using the Resize FS button under Additional functions on the main page. Minimum 200MB. Reboot.
 * For HDMI audio, set the audio device to vc4 (HDMI0) on the Squeezelite Settings page. Reboot. Don't worry if Squeezelite doesn't start again
  * SSH to piCorePlayer as the default user "tc".
   - Eg: `ssh tc@pcp` or `ssh tc@<IP of your piCorePlayer>`
   - [How to find the IP address of your piCorePlayer](https://docs.picoreplayer.org/how-to/determine_your_pcp_ip_address/)
 
## Installation Steps
2. Run `install_cdsp-loopback.sh` on piCorePlayer from a terminal:
   - SSH onto the piCorePlayer as user `tc`
     - Eg `ssh tc@pcp.local` or `ssh tc@<IP of your piCorePlayer>`
     - [How to find the IP address of your piCorePlayer](https://docs.picoreplayer.org/how-to/determine_your_pcp_ip_address/)
   - Run  
     `wget https://github.com/JWahle/piCoreCDSP/raw/main/install_cdsp-loopback.sh && chmod u+x install_cdsp.sh && ./install_cdsp-loopback.sh`
   - Or if you want to run a modified version of the script or an older version, see the [For developers and tinkerers](#for-developers-and-tinkerers) section
3. Open CamillaGUI in the browser:
   - It will be running on port 5000 of piCorePlayer.  
     Usually can be opened via [pcp.local:5000](http://pcp.local:5000) or `<IP of your piCorePlayer>:5000`
   - Under `Playback device` enter the settings for your DAC/AVR (by default, the Raspi headphone output is used)
     - These HAVE TO BE CORRECT, otherwise CamillaDSP and Squeezelite won't start!
       - `device`: The Alsa device name of the DAC/AVR
         - A list of available devices can be found in `Squeezelite settings > Output setting`
         - If you know the `sampleformat` for your DAC or want to find it through trial and error,
           then choose a device with `hw:` prefix for an external DAC or the `hdmi:` prefix when using the HDMI interface for audio. Otherwise use one with `plughw:` prefix, however this is not advised as it resamples all audio.
       - `channels`: a supported channel count for the DAC/AVR
         Usually 2 for a stereo DAC/AVR.
       - `sampleformat`: a supported sample format for the DAC/AVR. (Only important, when NOT using a `plughw:` device)
   - Hit `Apply and save`
     - You should see channel meters and `State: RUNNING` on the left
     - If things go wrong, check the CamillaDSP log file via the `Show log file` button for more info.
       After changing the settings, go to the pCP `Main Page` and press `Restart` to restart Squeezelite.
       If the settings are correct, the channel meters and `State: RUNNING` on the left side should be visible in CamillaGUI.

## Troubleshooting

### Just try again
Check, your system meets all the requirements, reboot and try to install again.

Sometimes, the script's dependencies get corrupted while downloading.  
In that case, you'll see messages like this somewhere in the log:  
`Checking MD5 of: openssl.tcz.....FAIL`  
There are a couple of things, you can try to work around this:
1. reboot and try to install again, repeat until successful
2. You can try to switch the extension repo:  
   - Reboot, then go to Main Page > Extensions > wait for the check to complete (until you see 5 green check marks)  
   - Then go to Available > Current repository > select "piCorePlayer mirror repository" and "Set".  
   - Run the script again.

If the error persists, post the error message on the piCoreCDSP Thread on
[diyaudio.com](https://www.diyaudio.com/community/threads/camilladsp-for-picoreplayer.402255/)
or [lyrion.org](https://forums.lyrion.org/forum/user-forums/linux-unix/1646681-camilladsp-for-picoreplayer).

### Enough RAM?
If you have a Raspberry Pi with less than 1 GB of RAM, you might need to increase the swap partition to make up for it.

## How to update
You can update to the current version, if you have PCP 9.x installed.
For older versions, updating is difficult and not recommended - just do a fresh install and enjoy life.
*** Be sure to edit the version numbers set at the top of the script ***

To update, you have to:
- [remove the piCoreCDSP extension](#picorecdsp-extension)
- [remove the installation script](#picorecdsp-installation-script)
- [install the new version](#how-to-install)
- Update your CamillaDSP config files in the GUI at [pcp.local:5000](http://pcp.local:5000)
  - go to the `Files` tab
  - press "New config from default"
  - press "Import config"
  - select the config you want to update
  - select all checkboxes
  - press "Import"
  - save the config
  - the newly saved config should show as 

## How to uninstall
SSH onto the piCorePlayer and enter the following commands depending on what you want to uninstall.

### piCoreCDSP extension
If you want to uninstall without setting up piCorePlayer again,
you have to reconfigure your audio output device in the pCP UI.
Then uninstall the piCoreCDSP Extension
(In `Main Page > Extensions > Installed >` select `piCoreCDSP.tcz`, press `Delete`)
and reboot.

### piCoreCDSP installation script
`rm -f /home/tc/install_cdsp-loopback.sh`

### CamillaDSP configuration files and filters
`rm -rf /etc/sysconfig/tcedir/camilladsp/`

### Save the changes
If you just restart, some changes will not be persistent. To make all your changes persistent, run:
`pcp backup`

## Implementation
The `install_cdsp-loopback.sh` script downloads the following projects including dependencies
and installs them with convenient default settings:
- https://github.com/HEnquist/camilladsp
- https://github.com/HEnquist/camillagui-backend

## For developers and tinkerers

In this section it is assumed, that your piCorePlayer is available on [pcp.local](http://pcp.local).
If this is not the case, replace occurrences of `pcp.local` with the IP-address/hostname of your piCorePlayer.

### Modifying the installation script
If you made some changes to the installation script on your local machine and want to run it quickly on the piCorePlayer, 
run the following command from the location of the script:  
```shell
scp install_cdsp-Loopback.sh tc@pcp.local:~ && ssh tc@pcp.local "./install_cdsp-Loopback.sh"
```

### Running your own python scripts
You can run python scripts requiring `pycamilladsp` or `pycamilladsp-plot` like this:
1. Copy your script from your local machine to pCP: `scp <your_script> tc@pcp.local:~`
2. In `Tweaks > User Commands` set one of the commands to this:  
   `sudo -u tc sh -c 'source /usr/local/camillagui/environment/bin/activate; python3 /home/tc/<your_script>'`
3. Save and reboot

If you need to access files in your script, make sure to use absolute paths.

### Running CamillaDSP standalone

You can run CamillaDSP standalone. This might be useful, if you want to capture audio from some audio device.
Although, in this case you won't be able to use any of the Squeezelite/airPlay/Bluetooth audio sources.

1. Go to `Tweaks > Audio Tweaks` and set `Squeezelite` to `no`.
2. Then go to `Tweaks > User commands` and set one of the commands to  
   `sudo -u tc sh -c '/usr/local/camilladsp -p 1234 -a 0.0.0.0 -o /tmp/camilladsp.log --statefile /mnt/mmcblk0p2/tce/camilladsp/camilladsp_statefile.yml'`  
   or if you want a fixed volume of e.g. -30dB, use this command:  
   `sudo -u tc sh -c '/usr/local/camilladsp -p 1234 -a 0.0.0.0 -o /tmp/camilladsp.log --statefile /mnt/mmcblk0p2/tce/camilladsp/camilladsp_statefile.yml --gain=-30'`
3. Save and reboot
