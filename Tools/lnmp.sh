#!/bin/bash
echo "*****************************************************************************"
echo "		********************************************                       "
echo "	        *  欢迎使用LNMP一键部署  *                       "
echo "		********************************************                       "
echo "                                                                             "
echo "	 注意事项：                                                                "
echo "	                                                                           "
echo "	       1.本程序仅适用于安装LNMP环境。					   "
echo "	       2.本程序会将本服务器上原来存在的涉及PHP和Mysql的包全部移除。        "
echo "										   "
echo "                                                                             "
echo "                                                                             "
echo "*****************************************************************************"
TIP="input LNMP web dir(such as your lnmp dir is /data/www/lnmp ,just input lnmp!): "
read -p "$TIP" LNMPDEMO

if [ -z "$LNMPDEMO" ];then
	echo "you do not input LNMP web dir name"
	exit 0
fi

echo $LNMPDEMO
SERVICES='nginx mysqld redis php-fpm56'
PAKNAME='php-fpm56 ngx_openresty mysql Zend56 php-memcached56 php-memcache56 memcached php-redis56 redis'
#Disable SeLinux
setenforce 0
if [ -s /etc/selinux/config ]; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    echo -e "\033[31m selinux is disabled,if you need,you must reboot.\033[0m"
fi


#Synchronization time
rm -rf /etc/localtime
ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

#iptables config
cat > /etc/sysconfig/iptables << 'EOF'
# Firewall configuration written by system-config-securitylevel
# Manual customization of this file is not recommended.
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:RH-Firewall-1-INPUT - [0:0]
-A INPUT -j RH-Firewall-1-INPUT
-A FORWARD -j RH-Firewall-1-INPUT
-A RH-Firewall-1-INPUT -i lo -j ACCEPT
-A RH-Firewall-1-INPUT -p icmp --icmp-type any -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 21 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 3306 -j ACCEPT
-A RH-Firewall-1-INPUT -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF
iptables-restore < /etc/sysconfig/iptables
service iptables save
service iptables restart

# modprobe config
modprobe ip_conntrack_ftp
if [ $? -eq 0 ]; then
    sed -i "/modprobe ip_conntrack_ftp/d" /etc/rc.d/rc.local
    echo "modprobe ip_conntrack_ftp" >> /etc/rc.d/rc.local
fi
modprobe ip_nat_ftp
if [ $? -eq 0 ]; then
    sed -i "/modprobe ip_nat_ftp/d" /etc/rc.d/rc.local
    echo "modprobe ip_nat_ftp" >> /etc/rc.d/rc.local
fi
modprobe bridge
if [ $? -eq 0 ]; then
    sed -i "/modprobe bridge/d" /etc/rc.d/rc.local
    echo "modprobe bridge" >> /etc/rc.d/rc.local
fi
# limit config
cat > /etc/security/limits.conf <<'EOF'
*               soft    nofile          65532
*               hard    nofile          65532
EOF

cat >/etc/security/limits.d/90-nproc.conf <<'EOF'
*          soft    nproc     65532
root       soft    nproc     unlimited
EOF

#dns  config
cp /etc/resolv.conf /etc/resolv.conf.bak
cat >/etc/resolv.conf <<'EOF'
nameserver 223.5.5.5
nameserver 223.6.6.6
EOF

killall yum
echo -e "\033[31m cleanning old rpm pkg ... \033[0m"
# clean old php pkg
echo 
yum remove php* Zend56 php-fpm56 ngx_openresty mysql Zend56 php-memcached56 php-memcache56 memcached php-redis56 redis -y > /dev/null 2>&1 || true
yum remove mysql mysql-server -y > /dev/null 2>&1 || true
yum install wget -y > /dev/null 2>&1 || true

cd /etc/yum.repos.d/
if [ -z /etc/yum.repos.d/shopex-lnmp.repo ];then
	wget http://mirrors.shopex.cn/shopex/shopex-lnmp/shopex-lnmp.repo
else
	mv shopex-lnmp.repo shopex-lnmp.repo.bak
	wget http://mirrors.shopex.cn/shopex/shopex-lnmp/shopex-lnmp.repo
fi > /dev/null 2>&1


cd - > /dev/null 2>&1
yum install epel-release yum-plugin-fastestmirror -y > /dev/null 2>&1 || true

for e in $PAKNAME
do 
	rpm -q $e &> /dev/null 
	[ $? -ne 0 ] && UNPKG="$UNPKG $e"  
done 
[ -n "$UNPKG" ] && yum install $UNPKG -y  
echo "Dependent Packages install OK...." 

yum install jdk1.8.0_40 -y   > /dev/null 2>&1
# java config 
if [ -z /usr/local/java ];then
	ln -s /usr/java/jdk1.8.0_40/ /usr/local/java
else
	ln -s /usr/java/jdk1.8.0_40/ /usr/local/java
fi

grep "JAVA_HOME" /etc/profile
if [ $? -ne 0 ]; then
	echo "export JAVA_HOME=/usr/local/java" >> /etc/profile
	echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /etc/profile
	source /etc/profile
fi

# php config
PHPINI='/usr/local/php56/etc/php.ini'
if [ -f $PHPINI ];then
	sed -i 's#;date.timezone =#date.timezone = Asia/Shanghai#g' $PHPINI
	sed -i 's#display_errors = Off#display_errors = On#g' $PHPINI
fi
PHPFPMINI='/usr/local/php56/etc/php-fpm.conf'
if [ -f $PHPFPMINI ];then
	sed -i 's#pm.max_children = 20#pm.max_children = 128#g' $PHPFPMINI
	sed -i 's#pm.start_servers = 40#pm.start_servers = 15#g' $PHPFPMINI
	sed -i 's#pm.min_spare_servers = 20#pm.min_spare_servers = 15#g' $PHPFPMINI
	sed -i 's#pm = dynamic#pm = static#g' $PHPFPMINI
fi

# config httpd path
if [ -d /data/www/$LNMPDEMO ]; then
	mv /data/www/$LNMPDEMO /data/www/$LNMPDEMO.bak
	mkdir -p /data/www/
	# install java_app
	cd /data/www/$LNMPDEMO/java/
	javafile='middleware.tar.gz'
	install -m755 -d /data/java_app
        tar xf $javafile -C /data/java_app
        chmod u+x /data/java_app/initShopexCRM.sh
        cd /data/java_app && nohup  /data/java_app/initShopexCRM.sh  &
else
	mkdir -p /data/www/
	# install java_app
	cd /data/www/$LNMPDEMO/java/
	javafile='middleware.tar.gz'
	install -m755 -d /data/java_app
        tar xf  $javafile -C /data/java_app
        chmod u+x /data/java_app/initShopexCRM.sh
	cd /data/java_app &&  nohup  /data/java_app/initShopexCRM.sh  &
fi

# config php zend
ZENDINI='/usr/local/php56/etc/php.d/Zend.ini'
if [ -f $ZENDINI ];then
        grep ";zend_loader.license_path=" $ZENDINI >>/dev/null
        if [ 0 = $? ];then
                echo 'zend_loader.license_path ='/data/www/$LNMPDEMO/config/developer.zl'' >> $ZENDINI
                sed -i '/;zend_loader.license_path/d' $ZENDINI
        fi
fi

# install crm-demo config file
cat > /usr/local/nginx/conf/vhosts/default.conf <<EOF
server
{
    listen       80 default;
    server_name  _;
    index index.html index.htm index.php;
    root /data/www/$LNMPDEMO/;


    location ~ (public\/*|themes\/*|demo\/*)
    {
       access_log off;
    }
    location ~ .*\.php.*
    {
        include php_fcgi.conf;
        include pathinfo.conf;
    }

    location ~ .*\.(gif|jpg|jpeg|png|bmp|swf)$
    {
        expires      30d;
    }

    location ~ .*\.(js|css)?$
    {
        expires      1h;
    }
    access_log /var/log/nginx/access.log;
}

EOF

for i in $SERVICES
do
        service $i restart
        chkconfig $i on
done


sleep 1

declare -a closelist
closelist=(
avahi-daemon
bluetooth
cups
firstboot
ip6tables
isdn
pcscd
rhnsd
yum-updatesd
pcscd
)

for((count=0,i=0;count<${#closelist[@]};i++))
do
    /sbin/chkconfig --list | grep ${closelist[i]}
    if [ $? -eq 0 ]; then
        cmd="/sbin/chkconfig ${closelist[i]} --level 3 off"
        echo $cmd
        `$cmd`
        /sbin/service ${closelist[i]} stop
    fi
    let count+=1
done > /dev/null 2>&1

grep "unset MAILCHECK" /etc/profile
if [ $? -ne 0 ]; then
    sed -i "/unset MAILCHECK/d" /etc/profile
    echo "unset MAILCHECK"  >> /etc/profile
fi
