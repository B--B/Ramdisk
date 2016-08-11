#!/sbin/bb/busybox sh

# Kernel Tuning by Alucard. Thanks to Dorimanx.

BB=/sbin/bb/busybox

# protect init from oom
if [ -f /system/xbin/su ]; then
	su -c echo "-1000" > /proc/1/oom_score_adj;
fi;

# clean dalvik after selinux change.
if [ -e /data/.alucard/selinux_mode ]; then
	$BB rm /data/dalvik-cache/arm/*;
	$BB rm /data/dalvik-cache/profiles/*;
	$BB rm /data/.alucard/selinux_mode;
	stop;
	$BB sync;
	reboot;
fi;

OPEN_RW()
{
	if [ "$($BB mount | $BB grep rootfs | $BB cut -c 26-27 | $BB grep -c ro)" -eq "1" ]; then
		$BB mount -o remount,rw /;
	fi;
	if [ "$($BB mount | $BB grep system | $BB grep -c ro)" -eq "1" ]; then
		$BB mount -o remount,rw /system;
	fi;
}
OPEN_RW;

selinux_status=$($BB grep -c "enforcing=1" /proc/cmdline);
if [ "$selinux_status" -eq "1" ]; then
	$BB umount /firmware;
	$BB mount -t vfat -o ro,context=u:object_r:firmware_file:s0,shortname=lower,uid=1000,gid=1000,dmask=227,fmask=337 /dev/block/platform/msm_sdcc.1/by-name/apnhlos /firmware
	restorecon -RF /system
	if [ -e /system/bin/app_process32_xposed ]; then
		chcon u:object_r:zygote_exec:s0 /system/bin/app_process32_xposed
		chcon u:object_r:dex2oat_exec:s0 /system/bin/dex2oat
		chcon u:object_r:dex2oat_exec:s0 /system/bin/patchoat
		chcon u:object_r:system_file:s0 /system/bin/oatdump
		chcon u:object_r:system_file:s0 /system/framework/XposedBridge.jar
		chcon u:object_r:system_file:s0 /system/lib/libart.so
		chcon u:object_r:system_file:s0 /system/lib/libart-compiler.so
		chcon u:object_r:system_file:s0 /system/lib/libart-disassembler.so
		chcon u:object_r:system_file:s0 /system/lib/libsigchain.so
		chcon u:object_r:system_file:s0 /system/lib/libxposed_art.so
	fi;
fi;

# run ROM scripts
if [ -f /system/etc/init.qcom.post_boot.sh ]; then
	$BB chmod 755 /system/etc/init.qcom.post_boot.sh;
	$BB sh /system/etc/init.qcom.post_boot.sh;
fi;

# clean old modules from /system and add new from ramdisk

# create init.d folder if missing
if [ ! -d /system/etc/init.d ]; then
	$BB mkdir -p /system/etc/init.d/
	$BB chmod -R 755 /system/etc/init.d/;
fi;

OPEN_RW;

# Tune entropy parameters.
$BB echo "512" > /proc/sys/kernel/random/read_wakeup_threshold;
$BB echo "256" > /proc/sys/kernel/random/write_wakeup_threshold;

# start CROND by tree root, so it's will not be terminated.
$BB sh /res/crontab_service/service.sh;

# some nice thing for dev
if [ ! -e /cpufreq ]; then
	$BB ln -s /sys/devices/system/cpu/cpu0/cpufreq/ /cpufreq;
	$BB ln -s /sys/devices/system/cpu/cpufreq/ /cpugov;
	$BB ln -s /sys/module/msm_thermal/parameters/ /cputemp;
	$BB ln -s /sys/kernel/alucard_hotplug/ /hotplugs/alucard;
	$BB ln -s /sys/kernel/intelli_plug/ /hotplugs/intelli;
	$BB ln -s /sys/module/msm_hotplug/ /hotplugs/msm_hotplug;
	$BB ln -s /sys/devices/system/cpu/cpufreq/all_cpus/ /all_cpus;
fi;

CRITICAL_PERM_FIX()
{
	# critical Permissions fix
	$BB chown -R root:root /tmp;
	$BB chown -R root:root /res;
	$BB chown -R root:root /sbin;
	$BB chown -R root:root /lib;
	$BB chmod -R 777 /tmp/;
	$BB chmod -R 775 /res/;
	$BB chmod -R 06755 /sbin/ext/;
	$BB chmod 06755 /sbin/bb/busybox;
}
CRITICAL_PERM_FIX;

# oom and mem perm fix
$BB chmod 666 /sys/module/lowmemorykiller/parameters/cost;
$BB chmod 666 /sys/module/lowmemorykiller/parameters/adj;
$BB chmod 666 /sys/module/lowmemorykiller/parameters/minfree

# make sure we own the device nodes
# $BB chown system /sys/devices/system/cpu/cpufreq/alucard/*
$BB chown system /sys/devices/system/cpu/cpu0/cpufreq/*
$BB chown system /sys/devices/system/cpu/cpu1/online
$BB chown system /sys/devices/system/cpu/cpu2/online
$BB chown system /sys/devices/system/cpu/cpu3/online
$BB chmod 666 /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
$BB chmod 666 /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
$BB chmod 666 /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
$BB chmod 444 /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq
$BB chmod 444 /sys/devices/system/cpu/cpu0/cpufreq/stats/*
$BB chmod 666 /sys/devices/system/cpu/cpufreq/all_cpus/*
$BB chmod 666 /sys/devices/system/cpu/cpu1/online
$BB chmod 666 /sys/devices/system/cpu/cpu2/online
$BB chmod 666 /sys/devices/system/cpu/cpu3/online
$BB chmod 666 /sys/module/msm_thermal/parameters/*
$BB chmod 666 /sys/kernel/intelli_plug/*
$BB chmod 666 /sys/class/kgsl/kgsl-3d0/max_gpuclk
$BB chmod 666 /sys/devices/platform/kgsl-3d0/kgsl/kgsl-3d0/pwrscale/trustzone/governor

if [ ! -d /data/.alucard ]; then
	$BB mkdir -p /data/.alucard;
fi;

# reset profiles auto trigger to be used by kernel ADMIN, in case of need, if new value added in default profiles
# just set numer $RESET_MAGIC + 1 and profiles will be reset one time on next boot with new kernel.
# incase that ADMIN feel that something wrong with global STweaks config and profiles, then ADMIN can add +1 to CLEAN_ALU_DIR
# to clean all files on first boot from /data/.alucard/ folder.
RESET_MAGIC=6;
CLEAN_ALU_DIR=2;

if [ ! -e /data/.alucard/reset_profiles ]; then
	$BB echo "$RESET_MAGIC" > /data/.alucard/reset_profiles;
fi;
if [ ! -e /data/reset_alu_dir ]; then
	$BB echo "$CLEAN_ALU_DIR" > /data/reset_alu_dir;
fi;
if [ -e /data/.alucard/.active.profile ]; then
	PROFILE=$($BB cat /data/.alucard/.active.profile);
else
	echo "default" > /data/.alucard/.active.profile;
	PROFILE=$($BB cat /data/.alucard/.active.profile);
fi;
if [ "$(cat /data/reset_alu_dir)" -eq "$CLEAN_ALU_DIR" ]; then
	if [ "$($BB cat /data/.alucard/reset_profiles)" != "$RESET_MAGIC" ]; then
		if [ ! -e /data/.alucard_old ]; then
			$BB mkdir /data/.alucard_old;
		fi;
		$BB cp -a /data/.alucard/*.profile /data/.alucard_old/;
		$BB rm -f /data/.alucard/*.profile;
		if [ -e /data/data/com.af.synapse/databases ]; then
			$BB rm -R /data/data/com.af.synapse/databases;
		fi;
		$BB echo "$RESET_MAGIC" > /data/.alucard/reset_profiles;
	else
		$BB echo "no need to reset profiles or delete .alucard folder";
	fi;
else
	# Clean /data/.alucard/ folder from all files to fix any mess but do it in smart way.
	if [ -e /data/.alucard/"$PROFILE".profile ]; then
		$BB cp /data/.alucard/"$PROFILE".profile /sdcard/"$PROFILE".profile_backup;
	fi;
	if [ ! -e /data/.alucard_old ]; then
		$BB mkdir /data/.alucard_old;
	fi;
	$BB cp -a /data/.alucard/* /data/.alucard_old/;
	$BB rm -f /data/.alucard/*
	if [ -e /data/data/com.af.synapse/databases ]; then
		$BB rm -R /data/data/com.af.synapse/databases;
	fi;
	$BB echo "$CLEAN_ALU_DIR" > /data/reset_alu_dir;
	$BB echo "$RESET_MAGIC" > /data/.alucard/reset_profiles;
	$BB echo "$PROFILE" > /data/.alucard/.active.profile;
fi;

[ ! -f /data/.alucard/default.profile ] && $BB cp -a /res/customconfig/default.profile /data/.alucard/default.profile;
[ ! -f /data/.alucard/battery.profile ] && $BB cp -a /res/customconfig/battery.profile /data/.alucard/battery.profile;
[ ! -f /data/.alucard/performance.profile ] && $BB cp -a /res/customconfig/performance.profile /data/.alucard/performance.profile;
[ ! -f /data/.alucard/extreme_performance.profile ] && $BB cp -a /res/customconfig/extreme_performance.profile /data/.alucard/extreme_performance.profile;
[ ! -f /data/.alucard/extreme_battery.profile ] && $BB cp -a /res/customconfig/extreme_battery.profile /data/.alucard/extreme_battery.profile;

$BB chmod -R 0777 /data/.alucard/;

. /res/customconfig/customconfig-helper;
read_defaults;
read_config;

# Load parameters for Synapse
DEBUG=/data/.alucard/;
BUSYBOX_VER=$($BB busybox | $BB grep "BusyBox v" | $BB cut -c0-15);
$BB echo "$BUSYBOX_VER" > $DEBUG/busybox_ver;

# start CORTEX by tree root, so it's will not be terminated.
$BB sed -i "s/cortexbrain_background_process=[0-1]*/cortexbrain_background_process=1/g" /sbin/ext/cortexbrain-tune.sh;
if [ "$($BB pgrep -f "cortexbrain-tune.sh" | $BB wc -l)" -eq "0" ]; then
	$BB nohup $BB sh /sbin/ext/cortexbrain-tune.sh > /data/.alucard/cortex.txt &
fi;

OPEN_RW;

if [ "$stweaks_boot_control" == "yes" ]; then
	# apply Synapse monitor
	$BB sh /res/synapse/uci reset;
	# apply STweaks settings
	$BB sh /res/uci_boot.sh apply;
	$BB mv /res/uci_boot.sh /res/uci.sh;
else
	$BB mv /res/uci_boot.sh /res/uci.sh;
fi;

######################################
# Loading Modules
######################################
MODULES_LOAD()
{
	# order of modules load is important

	if [ "$cifs_module" == "on" ]; then
		if [ -e /system/lib/modules/cifs.ko ]; then
			$BB insmod /system/lib/modules/cifs.ko;
		else
			$BB insmod /lib/modules/cifs.ko;
		fi;
	else
		$BB echo "no user modules loaded";
	fi;
}

# disable debugging on some modules
$BB echo "N" > /sys/module/kernel/parameters/initcall_debug;
#$BB echo "0" > /sys/module/smd/parameters/debug_mask
#$BB echo "0" > /sys/module/rpm_regulator_smd/parameters/debug_mask
#$BB echo "0" > /sys/module/ipc_router/parameters/debug_mask
#$BB echo "0" > /sys/module/event_timer/parameters/debug_mask
#$BB echo "0" > /sys/module/msm_serial_hs/parameters/debug_mask
#$BB echo "0" > /sys/module/powersuspend/parameters/debug_mask
#$BB echo "0" > /sys/module/msm_hotplug/parameters/debug_mask
#$BB echo "0" > /sys/module/cpufreq_limit/parameters/debug_mask
#$BB echo "0" > /sys/module/rpm_smd/parameters/debug_mask
#$BB echo "0" > /sys/module/smd_pkt/parameters/debug_mask
$BB echo "0" > /sys/module/xt_qtaguid/parameters/debug_mask
#$BB echo "0" > /sys/module/binder/parameters/debug_mask
#$BB echo "0" > /sys/module/msm_show_resume_irq/parameters/debug_mask
#$BB echo "0" > /sys/module/alarm_dev/parameters/debug_mask
#$BB echo "0" > /sys/module/pm_8x60/parameters/debug_mask;
#$BB echo "0" > /sys/module/spm_v2/parameters/debug_mask
#$BB echo "0" > /sys/module/alu_t_boost/parameters/debug_mask
#$BB echo "0" > /sys/module/ipc_router_smd_xprt/parameters/debug_mask
#$BB echo "0" > /sys/module/x_tables/parameters/debug_mask

OPEN_RW;

# Start any init.d scripts that may be present in the rom or added by the user
$BB chmod -R 755 /system/etc/init.d/;
if [ "$init_d" == "on" ]; then
	(
		$BB nohup $BB run-parts /system/etc/init.d/ > /data/.alucard/init.d.txt &
	)&
else
	if [ -e /system/etc/init.d/99SuperSUDaemon ]; then
		$BB nohup $BB sh /system/etc/init.d/99SuperSUDaemon > /data/.alucard/root.txt &
	else
		$BB echo "no root script in init.d";
	fi;
fi;

OPEN_RW;

# Fix critical perms again after init.d mess
CRITICAL_PERM_FIX;

if [ "$stweaks_boot_control" == "yes" ]; then
	$BB sh /sbin/ext/cortexbrain-tune.sh apply_cpu update > /dev/null;
	# Load Custom Modules
	MODULES_LOAD;
fi;

$BB echo "0" > /cputemp/freq_limit_debug;

# tune I/O controls to boost I/O performance

#This enables the user to disable the lookup logic involved with IO
#merging requests in the block layer. By default (0) all merges are
#enabled. When set to 1 only simple one-hit merges will be tried. When
#set to 2 no merge algorithms will be tried (including one-hit or more
#complex tree/hash lookups).
if [ "$($BB cat /sys/devices/msm_sdcc.1/mmc_host/mmc0/mmc0:0001/block/mmcblk0/queue/nomerges)" != "2" ]; then
	$BB echo "2" > /sys/devices/msm_sdcc.1/mmc_host/mmc0/mmc0:0001/block/mmcblk0/queue/nomerges;
	$BB echo "2" > /sys/devices/msm_sdcc.1/mmc_host/mmc0/mmc0:0001/block/mmcblk0/mmcblk0rpmb/queue/nomerges;
fi;

#If this option is '1', the block layer will migrate request completions to the
#cpu "group" that originally submitted the request. For some workloads this
#provides a significant reduction in CPU cycles due to caching effects.
#For storage configurations that need to maximize distribution of completion
#processing setting this option to '2' forces the completion to run on the
#requesting cpu (bypassing the "group" aggregation logic).
if [ "$($BB cat /sys/devices/msm_sdcc.1/mmc_host/mmc0/mmc0:0001/block/mmcblk0/queue/rq_affinity)" != "1" ]; then
	$BB echo "1" > /sys/devices/msm_sdcc.1/mmc_host/mmc0/mmc0:0001/block/mmcblk0/queue/rq_affinity;
	$BB echo "1" > /sys/devices/msm_sdcc.1/mmc_host/mmc0/mmc0:0001/block/mmcblk0/mmcblk0rpmb/queue/rq_affinity;
fi;

(
	$BB sleep 30;

	# get values from profile
	PROFILE=$($BB cat /data/.alucard/.active.profile);
	. /data/.alucard/"$PROFILE".profile;

	# Reload usb driver to open MTP and fix fast charge.
	#CHARGER_STATE=$(cat /sys/class/power_supply/battery/batt_charging_source);
	#if [ "$CHARGER_STATE" -gt "1" ]; then
	#		stop adbd
	#		sleep 1;
	#		start adbd
	#fi;

	# Update UKSM in case ROM changed to other setting.
	if [ "$run" == "on" ]; then
		$BB echo "1" > /sys/kernel/mm/uksm/run;
	else
		$BB echo "0" > /sys/kernel/mm/uksm/run;
	fi;
	$BB echo "$sleep_millisecs" > /sys/kernel/mm/uksm/sleep_millisecs;
	$BB echo "10" > /sys/kernel/mm/uksm/max_cpu_percentage;

	# stop core control if need to
	$BB echo "$core_control" > /sys/module/msm_thermal/core_control/core_control;

	# script finish here, so let me know when
	TIME_NOW=$(date)
	$BB echo "$TIME_NOW" > /data/boot_log_dm

	$BB mount -o remount,ro /system;
)&

# Stop LG logging to /data/logger/$FILE we dont need that. draning power.
setprop persist.service.events.enable 0
setprop persist.service.main.enable 0
setprop persist.service.power.enable 0
setprop persist.service.radio.enable 0
setprop persist.service.system.enable 0
