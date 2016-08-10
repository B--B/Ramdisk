#!/sbin/bb/busybox sh

(
	BB=/sbin/bb/busybox
	PROFILE=$(cat /data/.alucard/.active.profile);
	. /data/.alucard/${PROFILE}.profile;

	if [ "$reset_battery" == "on" ]; then
		$BB echo "reset" > /sys/bus/i2c/devices/1-0036/fuelrst;
		$BB date +%H:%M-%D > /data/crontab/cron-reset-battery;
		$BB echo "Battery Reset" >> /data/crontab/cron-reset-battery;
	fi;
)&
