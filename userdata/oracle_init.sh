#!/bin/sh
PASSWORD=$1
ECS_COUNT=$2
TEMPLATE_NAME=$3
ORACLE_VERSION=$4
ORACLE_01_PUB_IP=$5 
ORACLE_01_PRI_IP=$6  
ORACLE_01_VIP=$7
ORACLE_02_PUB_IP=$8
ORACLE_02_PRI_IP=$9  
ORACLE_02_VIP=$10
SCAN_VIP=$11
# hosts
if  [ ${ECS_COUNT} = 1  ]
then
cat > /etc/hosts <<- EOF
#public ip 
${ORACLE_01_PUB_IP}  ${TEMPLATE_NAME}-1
 
#private ip 
${ORACLE_01_PRI_IP}  ${TEMPLATE_NAME}-1-priv
 
#virtual ip 
${ORACLE_01_VIP}   ${TEMPLATE_NAME}-1-vip

EOF
elif [ ${ECS_COUNT} = 2  ]
then
cat > /etc/hosts <<- EOF
#public ip 
${ORACLE_01_PUB_IP}  ${TEMPLATE_NAME}-1
${ORACLE_02_PUB_IP}  ${TEMPLATE_NAME}-2

#private ip 
${ORACLE_01_PRI_IP}  ${TEMPLATE_NAME}-1-priv
${ORACLE_02_PRI_IP} ${TEMPLATE_NAME}-2-priv

#virtual ip 
${ORACLE_01_VIP}   ${TEMPLATE_NAME}-1-vip
${ORACLE_02_VIP}  ${TEMPLATE_NAME}-2-vip

EOF
elif [ ${ECS_COUNT} = 3  ]
then
cat > /etc/hosts <<- EOF
#public ip 
${ORACLE_01_PUB_IP}  ${TEMPLATE_NAME}-1
${ORACLE_02_PUB_IP}  ${TEMPLATE_NAME}-2
${ORACLE_03_PUB_IP}  ${TEMPLATE_NAME}-3

#private ip 
${ORACLE_01_PRI_IP}  ${TEMPLATE_NAME}-1-priv
${ORACLE_02_PRI_IP} ${TEMPLATE_NAME}-2-priv
${ORACLE_03_PRI_IP}  ${TEMPLATE_NAME}-3-priv

#virtual ip 
${ORACLE_01_VIP}   ${TEMPLATE_NAME}-1-vip
${ORACLE_02_VIP}  ${TEMPLATE_NAME}-2-vip
${ORACLE_03_VIP}  ${TEMPLATE_NAME}-3-vip

EOF

fi

cat >> /etc/hosts << EOF
#scan ip 
${SCAN_VIP}   ${TEMPLATE_NAME}-scan 
EOF

cp /etc/hosts /etc/hosts_oracle 

#
systemctl disable firewalld.service
systemctl stop firewalld.service
sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

#
dd if=/dev/zero of=/home/swap bs=1G count=32
mkswap  /home/swap
swapon  /home/swap
cat >> /etc/fstab << EOF
/home/swap             swap          swap    defaults        0 0 
EOF

#
cat > /etc/sysctl.conf  << EOF
fs.file-max = 6815744
kernel.sem = 250 32000 100 128
kernel.shmmni = 4096
kernel.shmall = `expr $(free -b|awk 'NR==2{print $2}') \* 90 / 100 / 4096`
kernel.shmmax = `expr $(free -b|awk 'NR==2{print $2}') \* 90 / 100`
kernel.panic_on_oops = 1
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
fs.aio-max-nr = 1048576
net.ipv4.ip_local_port_range = 9000 65500
EOF
sysctl -p
#
cat >> /etc/security/limits.conf  << EOF
grid     soft    nproc   2047 
grid     hard    nproc   16384 
grid     soft    nofile  1024 
grid     hard    nofile  65536 
grid     soft    stack  10240 
grid     hard    stack  32768
oracle   soft    nproc   2047 
oracle   hard    nproc   16384 
oracle   soft    nofile  1024 
oracle   hard    nofile  65536 
oracle   soft    stack   10240
oracle   hard    stack   32768
oracle   soft    memlock `expr $(free -b|awk 'NR==2{print $2}') \* 90 / 100`
oracle   hard    memlock `expr $(free -b|awk 'NR==2{print $2}') \* 90 / 100`
EOF
#
cat >> /etc/pam.d/login  << EOF
session    required     pam_limits.so
EOF

#
if  [ ${ORACLE_VERSION} = "11g"  ]
then
groupadd -g 501 oinstall
groupadd -g 502 asmadmin  
groupadd -g 503 dba  
groupadd -g 504 oper 
groupadd -g 505 asmdba  
groupadd -g 506 asmoper  
useradd -u 501 -g oinstall -G asmadmin,asmdba,asmoper,oper,dba grid
useradd -u 502 -g oinstall -G dba,asmdba,oper oracle 
mkdir -p /u01/app/11.2.0/grid   
mkdir -p /u01/app/grid                             
chown -R grid:oinstall /u01 
mkdir -p /u01/app/oracle     
chown -R oracle:oinstall /u01/app/oracle 
chmod -R 775 /u01/
mkdir -p /u01/app/grid/oraInventory
chmod -R 775 /u01/app/grid/oraInventory
chown -R grid:oinstall /u01/app/grid/oraInventory 
cat >> /home/grid/.bash_profile << 'EOF'
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/11.2.0/grid
export PATH=$ORACLE_HOME/bin:/usr/sbin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/bin:/bin:/usr/bin/:/usr/local/bin:/usr/X11R6/bin/
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
umask 022
EOF
cat >> /home/oracle/.bash_profile << 'EOF'
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/11.2.0/dbhome_1
export ORACLE_UNQNAME=rac
export PATH=$ORACLE_HOME/bin:/usr/sbin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/bin:/bin:/usr/bin/:/usr/local/bin:/usr/X11R6/bin/
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export TNS_ADMIN=$ORACLE_HOME/network/admin
umask 022
EOF
elif  [ ${ORACLE_VERSION} = "19c"  ]
then
groupadd -g 11001 oinstall
groupadd -g 11002 dba  
groupadd -g 11003 oper  
groupadd -g 11004 backupdba  
groupadd -g 11005 dgdba  
groupadd -g 11006 kmdba  
groupadd -g 11007 asmdba  
groupadd -g 11008 asmoper  
groupadd -g 11009 asmadmin  
groupadd -g 11010 racdba  
useradd -u 11011 -g oinstall -G dba,asmdba,backupdba,dgdba,kmdba,racdba,oper oracle  
useradd -u 11012 -g oinstall -G asmadmin,asmdba,asmoper,dba grid
mkdir -p /u01/app/oracle                                
chown -R oracle:oinstall /u01/app/oracle                
chmod -R 775 /u01/app/oracle
mkdir -p /u01/app/oracle/product/19.3.0/dbhome              
chown -R oracle:oinstall /u01/app/oracle/product/19.3.0/dbhome
chmod -R 775 /u01/app/oracle/product/19.3.0/dbhome
mkdir -p /u01/app/grid                                
chown -R oracle:oinstall /u01/app/grid               
chmod -R 775 /u01/app/grid
mkdir -p /u01/app/19.3.0/grid              
chown -R grid:oinstall /u01/app/19.3.0/grid
chmod -R 775 /u01/app/19.3.0/grid
mkdir -p /u01/app/oraInventory
chmod -R 775 /u01/app/oraInventory
chown -R grid:oinstall /u01/app/oraInventory
cat >> /home/grid/.bash_profile << 'EOF'
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/19.3.0/grid
export NLS_DATE_FORMAT="yyyy-mm-dd HH24:MI:SS"
export PATH=.:$PATH:$HOME/bin:$ORACLE_HOME/bin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
EOF
cat >> /home/oracle/.bash_profile << 'EOF'
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/19.3.0/dbhome
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/bin:/bin:/usr/bin:/usr/local/bin
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
EOF
elif  [ ${ORACLE_VERSION} = "12c"  ]
then 
groupadd -g 502 oinstall
groupadd -g 503 dba  
groupadd -g 504 oper 
groupadd -g 505 asmadmin  
groupadd -g 506 asmoper 
groupadd -g 507 asmdba  
useradd -g oinstall -G dba,asmdba,oper oracle 
useradd -g oinstall -G asmadmin,asmdba,asmoper,oper,dba grid
mkdir -p /u01/app/oracle/app   
chown -R oracle:oinstall /u01/app/oracle/app 
chmod -R 775 /u01/app/oracle/app 
mkdir -p /u01/app/oracle/product/12.2/db
chmod -R 775 /u01/app/oracle/product/12.2/db
mkdir -p /u01/app/grid/app                             
chown -R oracle:oinstall /u01/app/grid/app
chmod -R 775  /u01/app/grid/app
mkdir -p /u01/app/grid/12.2.0
chmod -R 775  /u01/app/grid/12.2.0

mkdir -p /u01/app/grid/oraInventory
chmod -R 775 /u01/app/grid/oraInventory
chown -R grid:oinstall /u01/app/grid/oraInventory 
cat >> /home/grid/.bash_profile << 'EOF'
export ORACLE_BASE=/u01/app/grid/app
export ORACLE_HOME=/u01/app/grid/12.2.0/
export PATH=$ORACLE_HOME/bin:/usr/sbin:/bin:/usr/bin/X11:/usr/local/bin:/sbin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$ORACLE_HOME/oracm/lib:/lib:/usr/lib:/usr/local/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib:$ORACLE_HOME/network/jlib
export THREADS_FLAG=native
EOF
cat >> /home/oracle/.bash_profile << 'EOF'
export DISPLAY=1.0
export ORACLE_BASE=/u01/app/oracle/app
export ORACLE_HOME=/u01/app/oracle/product/12.2/db
export TNS_ADMIN=$ORACLE_HOME/network/admin
export NLS_LANG="SIMPLIFIED CHINESE_CHINA.ZHS16GBK"
export PATH=$ORACLE_HOME/bin:/usr/sbin:/bin:/usr/bin/X11:/usr/local/bin:/u01/app/common/oracle/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$ORACLE_HOME/oracm/lib:/lib:/usr/lib:/usr/local/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib:$ORACLE_HOME/network/jlib
export THREADS_FLAG=native
EOF
fi

#
echo ${PASSWORD} | passwd grid --stdin > /dev/null 2>&1
echo ${PASSWORD} | passwd oracle --stdin > /dev/null 2>&1

#
if  [ `hostname -I|awk '{print $1}'` = "${ORACLE_01_PUB_IP}"  ]
then
   echo "HOSTNAME=${TEMPLATE_NAME}-1"   >> /etc/sysconfig/network
   echo "export ORACLE_SID=+ASM1"   >> /home/grid/.bash_profile
   echo "export ORACLE_SID=${TEMPLATE_NAME}1"  >> /home/oracle/.bash_profile
elif [ `hostname -I|awk '{print $1}'` = "${ORACLE_02_PUB_IP}"  ]
then
   echo "HOSTNAME=${TEMPLATE_NAME}-2"   >> /etc/sysconfig/network
   echo "export ORACLE_SID=+ASM2"   >> /home/grid/.bash_profile
   echo "export ORACLE_SID=${TEMPLATE_NAME}2"  >> /home/oracle/.bash_profile
elif [ `hostname -I|awk '{print $1}'` = "${ORACLE_03_PUB_IP}"  ]
then
   echo "HOSTNAME=${TEMPLATE_NAME}-3"   >> /etc/sysconfig/network
   echo "export ORACLE_SID=+ASM3"   >> /home/grid/.bash_profile
   echo "export ORACLE_SID=${TEMPLATE_NAME}3"  >> /home/oracle/.bash_profile
fi

#4.11
cat >> /etc/systemd/logind.conf  << EOF
RemoveIPC=no
EOF


#4.17
cat >> /tmp/vncinstall.sh << 'EOFF'
#!/bin/sh
#cp -a /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
#wget -O /etc/yum.repos.d/CentOS-Base.repo https://repo.huaweicloud.com/repository/conf/CentOS-7-reg.repo
#yum clean all
#yum makecache
if  [ ${ORACLE_VERSION} = "11g"  ]
then
yum -y install binutils compat-libstdc++ compat-libcap1 gcc gcc-c++ elfutils-libelf-devel \
               glibc glibc*.i686 glibc-devel glibc-devel*.i686 ksh libaio*.i686 libaio \
               libaio-devel*.i686 libaio-devel libgcc*.i686 libgcc libstdc++*.i686 libstdc++ \
               libstdc++-devel*.i686 libstdc++-devel libXi*.i686 libXi libXtst*.i686 libXtst \
               make sysstat unixODBC*.i686 unixODBC unixODBC-devel unzip  compat-libstdc++-33
elif  [ ${ORACLE_VERSION} = "19c"  ]
then
yum -y install bc gcc gcc-c++  binutils  make gdb cmake \
       glibc ksh elfutils-libelf elfutils-libelf-devel \
       fontconfig-devel glibc-devel libaio libaio-devel \
       libXrender libXrender-devel libX11 libXau sysstat \
       libXi libXtst libgcc librdmacm-devel libstdc++ \
       libstdc++-devel libxcb net-tools nfs-utils compat-libcap1 \
       compat-libstdc++  smartmontools  targetcli python python-configshell \
       python-rtslib python-six  unixODBC unixODBC-devel
elif  [ ${ORACLE_VERSION} = "12c"  ]
then 
yum -y install gcc gcc-c++ make binutils compat-libstdc++ compat-libcap1 elfutils-libelf elfutils-libelf-devel \
               glibc glibc-devel glibc-common  libaio libaio-devel libgcc libstdc++ \
               libstdc++-devel compat-libcap1 ksh  sysstat uunixODBC unixODBC-devel ibXp 
fi
yum groupinstall -y "X Window System"
yum groupinstall -y "GNOME Desktop"
yum groupinstall -y "GNOME Desktop"
yum install -y tigervnc-server expect
#vnc
cp /usr/lib/systemd/system/vncserver@.service /usr/lib/systemd/system/vncserver@:1.service
sed -i 's/<USER>/root/g' /usr/lib/systemd/system/vncserver@:1.service
/usr/bin/expect << EOF
spawn /usr/bin/vncpasswd
expect "Password:"
send "${PASSWORD}\r"
expect "Verify:"
send "${PASSWORD}\r"
expect "Would you like to enter a view-only password (y/n)?"
send "n\r"
expect eof
exit
EOF
systemctl daemon-reload
systemctl start vncserver@:1.service
systemctl enable vncserver@:1.service
EOFF
chmod a+x  /tmp/vncinstall.sh
#
cat >> /tmp/udev.sh  << 'EOF'
#!/bin/sh
lsblk -o name | \
grep -v `lsblk -o PKNAME|awk 'NR>1 && /./ && !a[$1]++  {print $1}'|awk 'NR==1 {print $1}'` | \
grep sd | \
awk ' {cmd="/usr/lib/udev/scsi_id -g -u /dev/"$1 ;  printf("%s ",$1) ;system(cmd);}'| \
awk '{a[$1]=$2}END{ len=asorti(a,b);asort(a,c); for(i=1;i<=len;i++) print b[i],c[i] }' | \
sed 's/sd//' | \
awk '{var="KERNEL==\"sd*\", SUBSYSTEM==\"block\", PROGRAM==\"/usr/lib/udev/scsi_id --whitelisted --replace-whitespace --device=/dev/$name\", RESULT==\""$2"\", SYMLINK+=\"asm-disk"$1"\", OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\"";print var}'| \
awk '{udev="echo '\''"$0"'\'' >> /etc/udev/rules.d/99-oracle-asmdevices.rules";system(udev)}'
udevadm control --reload-rules
udevadm trigger --type=devices --action=change
EOF
chmod a+x /tmp/udev.sh 
#

cat >> /etc/profile  << 'EOF'
if [ $USER = "oracle" ]; then 
   if [ $SHELL = "/bin/ksh" ]; then 
         ulimit -p 16384 
      ulimit -n 65536 
   else 
      ulimit -u 16384 -n 65536 
   fi 
fi
EOF
/tmp/vncinstall.sh
/tmp/udev.sh
#systemctl disable ntpd.service
#systemctl stop ntpd.service
#systemctl disable avahi-daemon.service
#systemctl stop avahi-daemon.service 



