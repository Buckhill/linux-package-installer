#!/bin/bash

#Author: Marko Bencek
#email: marko@buckhill.co.uk
#Date 04/17/2014
#Copyright Buckhill Ltd 2014
#Website www.buckhill.co.uk
#GitHub: https://github.com/Buckhill/linux-package-installer
#License GPLv3

CHROOT=/home/chroot

TS=`date +%s`

#displays error message for function
function error_msg
{
	COM_TMP=$1
	shift
	case $COM_TMP in
		check_file_ne)
			echo "At least one of the files ($*) exists. Cannot proceed."
                        ;;
		check_file_e)
			echo "At least one of the files ($*) is missing. Cannot proceed."
			;;
		check_bin_ne)
			echo "At least one of the binaries ($*) exists. Cannot proceed."
			;;
		check_bin_n)
			echo "At least one of the binaries ($*) is missing. Cannot proceed."
			;;
	esac
}

function group_sanity_check
{
        if echo "$1" |grep -q '^[a-z][a-z0-9_\-]\{1,14\}[^\-]$'
        then
                [ "$DEBUG" == "1" ] && echo "Sanity and length check for $1 - successful"
		return 0
        else
                
                [ "$DEBUG" == "1" ] && echo "Sanity and length check length for $1 - failed"
                return 1
        fi
}

function  check_multiverse_repo
{
	apt-cache policy |grep -q 'precise/multiverse' && apt-cache policy |grep -q 'precise-updates/multiverse' || 
	{
		echo "precise-updates/multiverse and precise/multivers repositories are needed"
		exit 1
	}
}


function apt-get_update
{
	if [ $APT_GET_UPDATE -eq 0 ]
	then
		apt-get -q=2 update
		check_multiverse_repo
		APT_GET_UPDATE=1
	fi
}

function check_bin
{
	 if which $1 >/dev/null
         then
        	[ "$DEBUG" == "1" ] && echo Binary $1 exists
		return 0
         else
         	[ "$DEBUG" == "1" ] && echo "Binary $1  doesn't exist"
		return 1
         fi
}

function check_bin_e
{
	for BIN in $*
	do
		check_bin $BIN  || return 1 
	done
	return 0
}

function check_bin_ne
{
        for BIN in $*
        do
                check_bin $BIN  &&  return 1 
        done
        return 0
}

function check_file
{
	if [ -f  $1 ]
	then
		[ "$DEBUG" == "1" ] && echo The $1 exists
		return 0
	else
		[ "$DEBUG" == "1" ] && echo "The $1  doesn't exist"
		return 1
	fi
}

#exists=0, don't exist=1 
function check_file_e
{
       for FILE in $*
       do
		check_file $FILE ||  return 1
       done
       return 0
}

#exists=1, don't exist=0 
function check_file_ne
{
       for FILE in $*
       do
		check_file $FILE &&  return 1
       done
       return 0
}

function stop_on_error
{
	#$1 check function which returns status code 0 or 1
	#$2-n argument for check function 
	COM_TMP=$1
	shift 
	if $COM_TMP $* 
	then
		return 0
	else
		error_msg $COM_TMP $*
		exit  1
	fi
}

function set_startup
{
#$1 service name 
	stop_on_error check_bin_e update-rc.d

	if  test -L /etc/rc$(runlevel  |awk '{print $2 }').d/S*$1
	then
		[ "$DEBUG" == "1" ] && echo "$1 is already enabled"
	else
		[ "$DEBUG" == "1" ] && echo "Enabling $1 daemon"
		update-rc.d  $1 defaults
	fi
}

function restart_or_start
{
#$1 service name 
 	Ftmp=/etc/init.d/$1
        if $Ftmp status >/dev/null
        then
                [ "$DEBUG" == "1" ] && echo "Restarting $1"
                $Ftmp restart
        else
                [ "$DEBUG" == "1" ] && echo "$1 is stopped. Starting it"
                $Ftmp start
        fi
}

function check_repo
{
	if apt-cache policy |grep -q $1
	then
		[ "$DEBUG" == "1" ] && echo "The repository $1 exists."
		return 0
	else
		[ "$DEBUG" == "1" ] && echo "The repository $1 doesn't exist." 
		return 1
	fi
}

function repo
{
	stop_on_error check_bin_e wget apt-get grep sudo apt-key apt-cache
	if check_repo http://packages.dotdeb.org 
	then
		echo "The dotdeb repository has been already set." 
	else
		[ "$DEBUG" == "1" ] && echo "Setting dotdeb repository"

		cat >> /etc/apt/sources.list     <<END
deb http://packages.dotdeb.org squeeze-php54 all
deb-src http://packages.dotdeb.org squeeze-php54 all
END
	fi

	if apt-key  list |grep -q 89DF5277 
	then
		[ "$DEBUG" == "1" ] && echo "The GPG key 89DF5277 exists."
	else
		[ "$DEBUG" == "1" ] && echo "Adding GPG key"
		stop_on_error check_file_ne /tmp/dotdep.gpg.$TS
		wget -o /tmp/dotdeb.gpg.wget.$TS.log -O /tmp/dotdeb.gpg.$TS http://www.dotdeb.org/dotdeb.gpg
		sudo apt-key add /tmp/dotdeb.gpg.$TS
		rm -rf /tmp/dotdeb.gpg.$TS
		apt-get_update
	fi
}

function mysql
{
	echo Installing MYSQL 
	stop_on_error check_bin_ne mysqld
	stop_on_error check_bin_e debconf-set-selections tr awk apt-get update-rc.d
	stop_on_error check_file_ne /etc/mysql/my.cnf  /root/.my.cnf

	apt-get_update

	MYPASS=`cat /dev/urandom | tr -cd "[:alnum:]" | head -c 8`
	debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYPASS"
	debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYPASS" 

	apt-get -q=2 -y install mysql-server  
	cat > /root/.my.cnf <<END
[client]
user=root
password=$MYPASS
END
	set_startup mysql
}

function fpm
{
	echo Installing PHP5-FPM
	stop_on_error check_bin_ne php5-fpm php	
	stop_on_error check_bin_e apt-get sed apt-cache

	if check_repo http://packages.dotdeb.org
	then
		FPM_apc=php5-apc
	else
		FPM_apc=php-apc
	fi

	apt-get_update

 	apt-get -q=2  -y install php5-cli $FPM_apc php5-common php5-fpm php5-mysqlnd php5-mcrypt
	stop_on_error check_file_e /etc/php5/fpm/php.ini
	sed -i 's/expose_php = On/expose_php = Off/' /etc/php5/fpm/php.ini
	
	Ftmp="/etc/php5/fpm/pool.d/www.conf"
	check_file $Ftmp && mv $Ftmp $Ftmp.disabled

	set_startup php5-fpm
	#restart_or_start php5-fpm 
}

function apache
{
	echo Installing Apache
	stop_on_error check_bin_ne apache2

	apt-get_update

	apt-get -q=2 -y install apache2  libapache2-mod-fastcgi 

	stop_on_error check_file_ne /etc/apache2/conf.d/php5-fpm.conf
	cat > /etc/apache2/conf.d/php5-fpm.conf <<END
<FilesMatch ".+\.ph(p[345]?|t|tml)$">
    SetHandler application/x-httpd-php
</FilesMatch>

<FilesMatch ".+\.phps$">
    SetHandler application/x-httpd-php-source
    # Deny access to raw php sources by default
    # To re-enable it's recommended to enable access to the files
    # only in specific virtual host or directory
    Order Deny,Allow
    Deny from all
</FilesMatch>
<FilesMatch "^\.ph(p[345]?|t|tml|ps)$">
    Order Deny,Allow
    Deny from all
</FilesMatch>
# Define Action and Alias needed for FastCGI external server.
Action application/x-httpd-php /fcgi-bin/php5-fpm virtual
Alias /fcgi-bin/php5-fpm /fcgi-bin-php5-fpm
<Location /fcgi-bin/php5-fpm>
  # here we prevent direct access to this Location url,
  # env=REDIRECT_STATUS will let us use this fcgi-bin url
  # only after an internal redirect (by Action upper)
  Order Deny,Allow
  Deny from All
  Allow from env=REDIRECT_STATUS
</Location>

END
		Ftmp=/etc/apache2/conf.d/security
	check_file $Ftmp && sed -i -e "s/^ServerSignature On/ServerSignature Off/" -e "s/^ServerTokens.*/ServerTokens Prod/" $Ftmp

		Ftmp=/etc/apache2/apache2.conf	
	stop_on_error check_file_e $Ftpm
	grep -iq '^[[:space:]]*ServerName' $Ftmp || echo ServerName localhost >> $Ftmp

		Ftmp=/etc/apache2/sites-available/default
	check_file $Ftmp && sed -i "s#/var/www#/var/www/default/g" $Ftmp
	Ftmp=/var/www/default
	test -d $Ftmp || mkdir $Ftmp
	Ftmp=/var/www/default/index.html
	check_file $Ftmp || echo -n > $Ftmp

	stop_on_error check_bin_e a2enmod
	for Ftmp in actions rewrite 
	do
	 	a2enmod $Ftmp
	done

	set_startup apache2
	restart_or_start apache2 
}

function other_bin
{
	BINS=`echo $1 |sed 's/,/ /g'`

	apt-get_update

	echo "Installing other packages"
	for Ftmp in $BINS
	do
		[ "$DEBUG" == "1" ] && echo "check and install $Ftmp" 
		check_bin $Ftmp  || apt-get -y -q=2 install $Ftmp
	done
}

function add_group
{
	if grep -q "^$1:"  /etc/group
	then
		[ "$DEBUG" == "1" ] && echo "Group $1 exists"
	else
		[ "$DEBUG" == "1" ] && echo "Group $1 doesn't exist, setting it."
		groupadd -K GID_MIN=200 -K GID_MAX=499 $1
	fi
}

function sshd_config
{	
# $1 primary,secondary
	PRIMARYG=`echo $1 |awk -F , '{print $1}'`
	SECONDARYG=`echo $1|awk -F , '{print $2}'`
	group_sanity_check $PRIMARYG || usage
	group_sanity_check $SECONDARYG || usage

	echo "Blocking $PRIMARYG group for ssh access"
	Ftmp=/etc/ssh/sshd_config
	stop_on_error check_file_e $Ftmp
	
	add_group $PRIMARYG
	add_group $SECONDARYG

	if grep -i '^[[:space:]]*DenyGroups'  $Ftmp |grep -qw $PRIMARYG 
	then
		[ "$DEBUG" == "1" ] && echo "The $PRIMARYG is already set in DenyGroups"
	else
		if grep -qi '^[[:space:]]*DenyGroups'  $Ftmp
		then
			[ "$DEBUG" == "1" ] && echo "Adding $PRIMARYG to existing DenyGroups statement" 
			sed -i "s/^\([[:space:]]*[dD][eE][nN][yY][gG][rR][oO][uU][pP][sS] .\+\)$/\1 $PRIMARYG/"  $Ftmp
			ssh_restart=1
		else
			[ "$DEBUG" == "1" ] && echo "Adding new DenyGroups stateement and adding $PRIMARYG to it"
			echo "DenyGroups $PRIMARYG" >> $Ftmp
			ssh_restart=1
		fi
	fi

	if grep -i '^[[:space:]]*Match[[:space:]]\+Group' $Ftmp |grep -qw $SECONDARYG 
	then
		[ "$DEBUG" == "1" ] && echo "The Match Group $SECONDARYG statment already exists" 
	else

		cat >> $Ftmp <<END
Match Group $SECONDARYG
        ChrootDirectory $CHROOT/%u
        ForceCommand internal-sftp -u 0002 -l info
        AllowTcpForwarding no
        X11Forwarding no
END

		ssh_restart=1
	fi

	[ "$ssh_restart" == "1" ] && echo  "The $Ftmp has been changed. Restart SSH daemon in order to apply changes" 
}

function usage
{
	cat <<END
Usage: $0 [options...]
 -a 		Install all. Same as -m -p -w -o curl,unzip,rsync
 -r 		Set DotDeb repo for php5.4.
 -p 		Install php5-fpm 
 -w 		Install Apache2
 -o [ progs ]	Install extra packages like curl or unzip delimited with "," 
 -m 		Install mysql server
 -s PrimaryGroup,SecondaryGroup
		Needed later for Web Chroot Manager.
		Sets primary and secondary unix groups if not already exist and
		sets OpenSSH daemon in order to deny access to primary and allow
		chrooted sftp access for secondary.
 -d		Enable debug logging.

END
	exit 
}

[ "$(whoami)" != "root" ] && { echo "Has to be ran as root";exit 1;}

REPO=0
MYSQL=0
FPM=0
APACHE=0
SSHD=0
OTHER=0
DEBUG=0
SSH=0
APT_GET_UPDATE=0

while getopts ":awmpdo:hrs:" o
do
        case "${o}" in
                a)
			MYSQL=1
			FPM=1
			APACHE=1
			OTHER=1
			OTHERARG=curl,unzip,curl
                 	;;
                w)
			APACHE=1
                        ;;
                m)
			MYSQL=1
                        ;;
		r)
			REPO=1
			;;
		o)
			OTHER=1
			OTHERARG=${OPTARG}
			;;
		p)
			FPM=1
			;;
		d)
			DEBUG=1
			;;
		s)
			SSH=1
			SSHARG=${OPTARG}

			[ $(echo -n $SSHARG|sed 's/[^,]//g' |wc -c) -eq 1 ] || usage
				
			;;
		h|:)
			usage
			;;
			
	esac
done
shift $((OPTIND-1))

[ $REPO -eq 1  ] && repo $REPOARG
[ $MYSQL -eq 1 ] && mysql 
[ $FPM -eq 1 ] && fpm 
[ $APACHE -eq 1 ] && apache 
[ $OTHER -eq 1 ] && other_bin $OTHERARG
[ $SSH -eq 1 ] && sshd_config $SSHARG

[ $(( REPO + MYSQL + FPM + APACHE + OTHER + SSH )) -eq 0 ] && usage
