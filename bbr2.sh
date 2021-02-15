#!/bin/bash

set -e

: <<EOF
/etc/debian_version
/etc/issue
/proc/version
3.10.0-957.21.2.
3 – This is the main kernel version
.10 – This is the major release version
.0 – This is the minor revision level
-957 – This is the level of patches and bug fixes
EOF

project_url="https://github.com/yiguihai/bbr2.sh/raw/master/"
header_file_dir="${project_url}/ubuntu-16.04/linux-headers-5.10.0_5.10.0-1_amd64.deb"
image_file_dir="${project_url}/ubuntu-16.04/linux-image-5.10.0_5.10.0-1_amd64.deb"
libc_file_dir="${project_url}/ubuntu-16.04/linux-libc-dev_5.10.0-1_amd64.deb"
source /etc/os-release || exit
kernel_ver=$(uname -r)

wget_get_files() {
	if ! wget --no-check-certificate -q -c -t2 -T8 -O $1 $2; then
		echo "Failed to download $1 file!"
		rm -f $1
		exit 1
	fi
}

press_any_key_to_continue() {
	read -n 1 -r -s -p $'Please press any key to continue or Ctrl + C to exit\n'
}

system_check() {
	#https://www.cyberciti.biz/faq/how-do-i-know-if-my-linux-is-32-bit-or-64-bit/
	BIT=$(getconf LONG_BIT)
	if [ "$(grep -o -w 'lm' /proc/cpuinfo | sort -u)" = "lm" ]; then
		CPU=64
	else
		CPU=32
	fi
	#if [ -d /proc/xen ]; then
	#echo "Xen virtualization is not supported"
	#exit 1
	#fi
	if [ -d /proc/vz ]; then
		echo "OpenVZ virtualization is not supported"
		exit 1
	fi
	if [ ${BIT:-32} -ne 64 -a ${CPU:-32} -ne 64 ]; then
		echo "Only 64-bit is supported"
		exit 1
	fi
	#https://stackoverflow.com/questions/21157435/bash-string-compare-to-multiple-correct-values
	if [[ $ID != @(debian|ubuntu) ]]; then
		echo "Unsupported systems"
		exit 1
	fi
	#https://github.com/netblue30/firejail/issues/2232
	#https://my.oschina.net/u/3888259/blog/4414015
	iptables -vxn -t nat -L OUTPUT --line-number 1>/dev/null || update-alternatives --set iptables /usr/sbin/iptables-legacy
	ip6tables -vxn -t nat -L OUTPUT --line-number 1>/dev/null || update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
}

enable_bbr() {
	if [[ $(sysctl -nb net.ipv4.tcp_available_congestion_control) == *bbr2* ]]; then
		if [[ $(sysctl -nb net.core.default_qdisc) != 'fq' ]]; then
			sysctl -w net.core.default_qdisc=cake
			tc qdisc replace dev $(ip -4 -o route get to 8.8.8.8 | cut -d" " -f5) root cake rtt 50ms ethernet besteffort
			tc -s qdisc show
		fi
		if [[ $(sysctl -nb net.ipv4.tcp_congestion_control) == 'bbr2' ]]; then
			echo "BBRv2 support has been turned on"
		else
			sysctl -w net.ipv4.tcp_congestion_control=bbr2
		fi
	else
		echo "There is no linux kernel installed that supports BBRv2"
	fi
}

enable_ecn() {
	# enable BBRv2 ECN response:
	echo 1 >/sys/module/tcp_bbr2/parameters/ecn_enable
	# enable BBRv2 ECN response at any RTT:
	echo 0 >/sys/module/tcp_bbr2/parameters/ecn_max_rtt_us
	case $(sysctl -nb net.ipv4.tcp_ecn) in
	0)
		# negotiate TCP ECN for active and passive connections:
		sysctl -w net.ipv4.tcp_ecn=1
		sysctl -w net.ipv4.tcp_ecn_fallback=1
		;;
	1 | 2)
		echo "ECN support has been turned on"
		;;
	*)
		echo "Unknown error"
		;;
	esac
}

kernel_install() {
	if [ ${kernel_ver%%.*} -gt 4 ]; then
		echo "Linux kernel version > 4"
		exit 1
	fi
	wget_get_files /tmp/linux-header.deb $header_file_dir
	wget_get_files /tmp/linux-image.deb $image_file_dir
	wget_get_files /tmp/linux-libc.deb $libc_file_dir
	dpkg --install /tmp/linux-header.deb
	dpkg --install /tmp/linux-image.deb
	dpkg --install /tmp/linux-libc.deb
	dpkg --list | egrep --ignore-case --color 'linux-image|linux-headers|linux-libc' #|awk '{print $2}'
	echo "You need to reboot after installing the new linux kernel! Rebooting now?"
	read -p "(Y/N)" -n1 restart
	if [[ $restart =~ ^[Yy]$ ]]; then
		#https://juejin.cn/post/6844904034072018952
		update-grub && reboot
	fi
}

kernel_uninstall() {
	#https://www.cyberciti.biz/faq/ubuntu-18-04-remove-all-unused-old-kernels/
	apt -qq autoremove --purge
	apt -qq remove $(dpkg --list | egrep --ignore-case 'linux-image|linux-headers|linux-libc' | egrep -v "$kernel_ver" | awk '/ii/{ print $2}') --purge
}

while true; do
	system_check
	clear
	cat <<EOF
==================================================
* OS - $PRETTY_NAME
* Version - $VERSION_ID
* Kernel - $(uname -mrs)
==================================================
  1. Install a linux kernel that supports BBRv2
  2. Enable BBRv2
  3. Enable ECN
  4. Remove old kernels
EOF
	read -p $'Please select \e[95m1-4\e[0m: ' action
	echo
	case $action in
	1)
		kernel_install
		;;
	2)
		enable_bbr
		;;
	3)
		enable_ecn
		;;
	4)
		kernel_uninstall
		;;
	*)
		break
		;;
	esac
	press_any_key_to_continue
done
