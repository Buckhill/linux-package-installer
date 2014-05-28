## Linux Package Installer (LPI)

LPI is a script designed to simplify, automate and speed up the installation of LAMP components (PHP-FPM, Apache, MySQL) within Ubuntu 12.04 LTS+.  

Other distributions (CentOS, Redhat, Debian) are currently being developed for a later release.

Running LPI without arguments will return help text with available options.

With LPI, you can:-

- Install and configure Apache to work with PHP-FPM from within the Ubuntu repository
- Install MySQL Server (The root password is automatically generated and stored in the /root/.my.cnf file)
- Set DotDeb repository for PHP 5.4
- Install PHP-FPM
- Install additional packages, as required (configurable)
- Setup two user groups and automatically configure OpenSSH.  First user group has no SSH access, and second group has only chrooted SFTP access.


### Running LPI

To run LPI, first, check the required repositories are enabled (precise-updates/multiverse and precise/multiverse).

Edit: /etc/apt/sources.list and uncomment as required, then run apt-get update

To run LPI, simply execute the .sh script as sudo or root.

### Usage options

Usage: ./lpi-core.sh [options...]

- -a             Install all. Same as -m -p -w -o curl,unzip,rsync
- -r             Set DotDeb repo for php5.4.
- -p             Install php5-fpm
- -w             Install Apache2
- -o [ progs ]   Install extra packages like curl or unzip delimited with ","
- -m             Install mysql server
- -s PrimaryGroup,SecondaryGroup
- -d             Enable debug logging.

### Limitations

- LPI currently only works on Ubuntu 12.04+ LTS
- LPI cannot uninstall, reinstall or upgrade packages.  If existing packages or files are to be overwritten, LPI will stop with an error
- LPI assumes chroot directory is /home/chroot.  You can change CHROOT variable as required
