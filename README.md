# bbr2.sh
![build](https://github.com/yiguihai/bbr2.sh/workflows/build/badge.svg)  
Warning: Replacing the kernel is risky and will not be responsible for any loss caused by the use of this script.  
警告：更换内核有风险，若使用本脚本后无法开机造成损失，概不负责。

First install the kernel and reboot, then run this script to delete the remaining kernel files after the reboot.  
首先安装好内核然后重启，重启后再运行这个脚本删除残留的内核文件

General usage:  
一般用法:  
```
wget --no-check-certificate -q -O bbr2.sh \
"https://github.com/yiguihai/bbr2.sh/raw/master/bbr2.sh"
chmod +x bbr2.sh 
./bbr2.sh
```
