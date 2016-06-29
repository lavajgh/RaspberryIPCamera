########################################################################################
# Installation procedure for the Raspberry Pi - IP Camera
########################################################################################

# This procedure was designed on top of a foundation Raspbian Jessie lite image with build date 10-05-2016
# Download the latest Raspbian Jessie Lite image from https://downloads.raspberrypi.org/raspbian_lite_latest
# Unzip your downloaded image, and write it to SD card with win32 disk imager.
# Boot up your SD card in your Raspberry Pi, and Log into the Raspbian Jessie OS, with pi as username and raspberry as password.
# Start executing below commands in sequence.

########################################################################################
# Bootstrap - Preparing the Raspbian OS.
########################################################################################
# Regen our security keys, it's a best practice
sudo /bin/rm -v /etc/ssh/ssh_host_*
sudo ssh-keygen -t dsa -N "" -f /etc/ssh/ssh_host_dsa_key
sudo ssh-keygen -t rsa -N "" -f /etc/ssh/ssh_host_rsa_key
sudo ssh-keygen -t ecdsa -N "" -f /etc/ssh/ssh_host_ecdsa_key
sudo ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
sudo systemctl restart sshd.service
# Resize our root partition to maximum size (only needed for older raspbian versions)
# the latest version resizes automatically
# sudo raspi-config --expand-rootfs
# sudo partprobe
# sudo resize2fs /dev/mmcblk0p2

########################################################################################
# Update Firmware - Making sure that your Raspbian firmware is the latest version.
########################################################################################
# update firmware
sudo apt-get -y install rpi-update
sudo rpi-update
# update raspbian
sudo apt-get update && sudo apt-get -y upgrade

########################################################################################
# Download a copy of our git repository and extract it
########################################################################################
wget -O /home/pi/RaspberryIPCamera.zip https://github.com/ronnyvdbr/RaspberryIPCamera/archive/v1.6-beta.zip
unzip /home/pi/RaspberryIPCamera.zip -d /home/pi
mv /home/pi/RaspberryIPCamera-1.6-beta /home/pi/RaspberryIPCamera
rm /home/pi/RaspberryIPCamera.zip

########################################################################################
# Set-up nginx with php support and enable our Raspberry IP Camera website.
########################################################################################
# Install nginx with php support.
sudo apt-get -y install nginx php5-fpm
# Disable the default nginx website.
sudo rm /etc/nginx/sites-enabled/default
# Copy our siteconf into place
sudo cp /home/pi/RaspberryIPCamera/DefaultConfigFiles/RaspberryIPCamera.Nginx.Siteconf /etc/nginx/sites-available/RaspberryIPCamera.Nginx.Siteconf
# Lets enable our website
sudo ln -s /etc/nginx/sites-available/RaspberryIPCamera.Nginx.Siteconf /etc/nginx/sites-enabled/RaspberryIPCamera.Nginx.Siteconf
# Disable output buffering in php.
sudo sed -i 's/output_buffering = 4096/;output_buffering = 4096/g' /etc/php5/fpm/php.ini
# Set permissions for the config files
sudo chgrp www-data /home/pi/RaspberryIPCamera/www/RaspberryIPCameraSettings.ini
chmod 664 /home/pi/RaspberryIPCamera/www/RaspberryIPCameraSettings.ini
sudo chgrp www-data /home/pi/RaspberryIPCamera/secret/RaspberryIPCamera.secret
chmod 664 /home/pi/RaspberryIPCamera/secret/RaspberryIPCamera.secret

########################################################################################
# Enable our Raspberry Pi Camera Module in our boot configuration.
########################################################################################
# First mount our boot partition read-write so we can make changes to our boot config.
sudo mount -o remount rw /boot
# Now modify our config.txt for the changes.
echo "start_x=1" | sudo tee -a /boot/config.txt
echo "gpu_mem=256" | sudo tee -a /boot/config.txt
echo "disable_camera_led=1" | sudo tee -a /boot/config.txt

########################################################################################
# Install all UV4L components
########################################################################################
# Add the supplier's repository key to our key database
curl http://www.linux-projects.org/listing/uv4l_repo/lrkey.asc | sudo apt-key add -
echo "deb http://www.linux-projects.org/listing/uv4l_repo/raspbian/ wheezy main" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
# Now fetch and install the required modules.
sudo apt-get -y install uv4l uv4l-raspicam
sudo apt-get -y install uv4l-raspicam-extras
sudo apt-get -y install uv4l-server
# Let's copy our own config files in place.
sudo cp /home/pi/RaspberryIPCamera/DefaultConfigFiles/uv4l-raspicam.conf /etc/uv4l/uv4l-raspicam.conf
sudo cp /home/pi/RaspberryIPCamera/DefaultConfigFiles/uv4l-server.conf /etc/uv4l/uv4l-server.conf
sudo sed -i "s/--editable-config-file=\$CONFIGFILE/--server-config-file=\/etc\/uv4l\/uv4l-server.conf/g" /etc/init.d/uv4l_raspicam
# Notify systemd of service changes.
sudo systemctl daemon-reload
# Set some permissions so our web gui can modify the config files.
sudo chgrp www-data /etc/uv4l/uv4l-raspicam.conf
sudo chmod 664 /etc/uv4l/uv4l-raspicam.conf

########################################################################################
# Install the RTSP server
########################################################################################
sudo apt-get -y install g++ cmake
# first compile the live555 library as a prerequisite
wget http://www.live555.com/liveMedia/public/live555-latest.tar.gz
tar -zxvf live555-latest.tar.gz
cd live
./genMakefiles linux
sudo make CPPFLAGS=-DALLOW_RTSP_SERVER_PORT_REUSE=1 install
# clone the rtsp server's git repository, compile and install
sudo apt-get install git
git clone https://github.com/mpromonet/v4l2rtspserver.git
# now requires  libasound2-dev as dependance to cmake - audio added 
# this library will take a long time to build
sudo apt-get -y install libasound2-dev
cd v4l2rtspserver
cmake . && make
sudo make install

###### old and deprecated ################
# Download pre-compiled versions of the RTSP server to facilitate in bug fixing.
# In the original compile, the services could not be restarted immediately because of a port not being released.
# wget -O /home/pi/h264-v4l2-rtspserver_20160306-1_armhf.deb https://dl.dropboxusercontent.com/s/1nkuoaemreesu4g/h264-v4l2-rtspserver_20160306-1_armhf_2.deb?dl=0
# wget -O /home/pi/live555_20160306-1_armhf.deb https://dl.dropboxusercontent.com/s/k7uncvqeugd9gpv/live555_20160306-1_armhf.deb?dl=0
# Install our pre-compiled packages
# sudo dpkg -i /home/pi/h264-v4l2-rtspserver_20160306-1_armhf.deb
# sudo dpkg -i /home/pi/live555_20160306-1_armhf.deb
# Remove the packages to consume disk space.
# rm /home/pi/h264-v4l2-rtspserver_20160306-1_armhf.deb
# rm /home/pi/live555_20160306-1_armhf.deb
###### end old and deprecated ################

# Put system service file for RTSP server into place
sudo cp /home/pi/RaspberryIPCamera/DefaultConfigFiles/RTSP-Server.service /etc/systemd/system/RTSP-Server.service
# Notify systemd of a service installation.
sudo systemctl daemon-reload
# Set the startup for the service to disabled for our default config.
sudo systemctl disable RTSP-Server.service


########################################################################################
# Set some additional rights and config files
########################################################################################
# put a sudoers file in the correct location for php shell commands integration
sudo cp /home/pi/RaspberryIPCamera/DefaultConfigFiles/sudoers_commands /etc/sudoers.d/sudoers_commands
# Put correct security rights on configuration files
sudo chgrp www-data /etc/timezone
sudo chmod 664 /etc/timezone
sudo chgrp www-data /etc/ntp.conf
sudo chmod 664 /etc/ntp.conf

########################################################################################
# Make our SD card read only, to preserve it and contribute to system stability
########################################################################################
# First get rid of some unnecessary pagkages.
sudo apt-get -y remove --purge  logrotate triggerhappy dphys-swapfile fake-hwclock samba-common
sudo apt-get -y autoremove --purge
# remove rsyslog and install a memory resident variant
sudo apt-get -y remove --purge rsyslog
sudo apt-get -y install busybox-syslogd
# now remap some folders to memory temp space
sudo rm -rf /var/lib/dhcp/ /var/spool /var/lock 
sudo rm /etc/resolv.conf
sudo ln -s /tmp /var/lib/dhcp
sudo ln -s /tmp /var/spool
sudo ln -s /tmp /var/lock
sudo ln -s /tmp/resolv.conf /etc/resolv.conf
sudo rm -rf /var/lib/php5/sessions
sudo ln -s /tmp/phpsessions /var/lib/php5/sessions
# configure the boot options to be read-only on next boot
sudo mount -o remount rw /boot
echo "dwc_otg.lpm_enable=0 console=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait fastboot noswap ro" | sudo tee /boot/cmdline.txt
# Our /etc/fstab should look like the one below
proc            /proc           proc    defaults              0 0
/dev/mmcblk0p1  /boot           vfat    ro,defaults           0 2
/dev/mmcblk0p2  /               ext4    ro,defaults,noatime   0 1
tmpfs           /var/log        tmpfs   nodev,nosuid          0 0
tmpfs           /var/tmp        tmpfs   nodev,nosuid          0 0
tmpfs           /tmp            tmpfs   nodev,nosuid          0 0
# Modify service unit of nginx service to create log folder before starting, otherwise error
sudo sed -i '20i\ExecStartPre=/bin/mkdir /var/log/nginx' /lib/systemd/system/nginx.service
# Modify service unit of php5-fpm service to create a tmp folder to store sessions in, otherwise error
sudo sed -i '8i\ExecStartPre=/bin/mkdir /tmp/phpsessions' /lib/systemd/system/php5-fpm.service
sudo sed -i '9i\ExecStartPre=/bin/chgrp www-data /tmp/phpsessions' /lib/systemd/system/php5-fpm.service
sudo sed -i '10i\ExecStartPre=/bin/chmod 775 /tmp/phpsessions' /lib/systemd/system/php5-fpm.service

########################################################################################
# Clean unneeded packages from our design to make the image size smaller for redistribution
########################################################################################
# Let's clean as much rubbish from our image so we can repack this for internet distribution in a normal size.
sudo mount -o remount rw /
sudo apt-get -y install localepurge
sudo localepurge
sudo apt-get -y remove --purge localepurge
sudo apt-get -y remove --purge avahi-daemon build-essential nfs-common console-setup curl dosfstools lua5.1 luajit manpages-dev parted python-rpi.gpio python
sudo apt-get -y autoremove --purge
sudo apt-get clean
sudo rm -rf /var/swap

########################################################################################
# Final reboot before we can start using our IP Camera
########################################################################################
sudo reboot

# to check
# add our pi user to www-data group.
# sudo usermod -a -G www-data pi
