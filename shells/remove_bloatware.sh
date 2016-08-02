export PATH=/data/local/tmp:$PATH

busybox mount -o remount,rw /cust
busybox mount -o remount,rw /system

for i in `cat /data/local/tmp/bloatware.lst`; do
    rm -r $i
done
