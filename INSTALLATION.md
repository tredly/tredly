# Tredly Installation

Use this guide if you want to install Tredly on an existing FreeBSD host, or a fresh installation. Note that we recommend you use the official Tredly FreeBSD ISO as it comes tested and preconfigured. A link can be found in README.md.

Tredly contains a configuration file that allows you to modify installation options. By default Tredly will ask you to set some/confirm certain information that it needs to complete the install. The configuration file also allows you to run an unattended install of Tredly, which is especially useful for larger environments where PXE boot is used.

Follow the below instructions to get Tredly installed.

1. Install FreeBSD (10.3 or above) as Root on ZFS.
2. Select all defaults except:
3. Deselect Ports (Tredly uses pkgs by default) and Source
4. Select Auto (ZFS) as partitioning scheme
5. Use whatever ZFS RAID you wish.
6. Wait for installation to complete - once the server has restarted continue
7. Log in as root and add a user that isn't root for SSH access
    ```
    pw useradd -n tredly -s /bin/tcsh -m
    passwd tredly
    pw groupmod wheel -m tredly
    ```
8. SSH into your Tredly server
    ```
    ssh tredly@aaa.bbb.ccc.ddd
    ```
9. Switch to the root user
    su root
10. Install SSL package and download Tredly
    ```
    cd /tmp && pkg install ca_root_nss && fetch https://github.com/tredly/tredly/archive/master.zip && unzip master.zip
    ```
11. Install Tredly
    ```
    cd /tmp/tredly-master && sh install.sh
    ```

    This will take some time (depending on the speed of your machine and internet connection) as Tredly uses a number of pieces of software. Note that this step will also re-compile your kernel for VIMAGE support if it is not supported in your current kernel.
12. Reboot

## SSH Access

By default Tredly is configured to allow SSH using passwords.

SSH is not required to manage Tredly if Tredly API is installed and configured.

If you wish to leave SSH enabled it is recommended you configure SSH to use ssh keys.

1. ssh into your Tredly server as "tredly"
2. mkdir ~/.ssh && vi ~/.ssh/authorized_keys
3. Get your SSH key from your local computer and paste it into the authorized keys file.
    ```
    vim ~/.ssh/id_rsa.pub
    su root
    vi /etc/ssh/sshd_config
    ```
4. Change the following values:
    ```
    "PubkeyAuthentication" from "no" to "yes"
    "PasswordAuthentication" from "yes" to "no"
    ```
5. Restart the SSH service
    ```
    service sshd restart
    ```
