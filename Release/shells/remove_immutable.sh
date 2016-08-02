export PATH=/data/local/tmp:$PATH

busybox mount -o remount,rw /system

set_immutable 0

mv /system/set_immutable.list /system/set_immutable.list.bak
