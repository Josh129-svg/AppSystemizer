#!/system/bin/sh
# Please don't hardcode /magisk/modname/... ; instead, please use $MODDIR/...
# This will make your scripts compatible even if Magisk change its mount point in the future
MODDIR=${0%/*}

# This script will be executed in post-fs-data mode
# More info in the main Magisk thread

OwnList=${MODDIR}/extras/appslist.conf
AppList='/data/data/com.loserskater.appsystemizer/files/appslist.conf'
[ -s "${MODDIR}/module.prop" ] && { ver="$(sed -n 's/version=//p' ${MODDIR}/module.prop)"; ver=${ver:+ $ver}; }
apps=("com.google.android.apps.nexuslauncher,NexusLauncherPrebuilt" "com.google.android.apps.pixelclauncher,PixelCLauncherPrebuilt" "com.actionlauncher.playstore,ActionLauncher")
#if [[ -s "$OwnList" && -s "$AppList" ]]; then
#  eval ol="($(<${OwnList}))"; eval al="($(<${AppList}))"; apps=("${ol[@]}" "${al[@]}");
#  log_print "Loaded apps list from ${OwnList}."; log_print "Loaded apps list from ${AppList}.";
#else
  if [ -s "$OwnList" ]; then eval apps="($(<${OwnList}))"; log_print "Loaded apps list from ${OwnList}."; else unset OwnList; fi
  if [ -s "$AppList" ]; then eval apps="($(<${AppList}))"; log_print "Loaded apps list from ${AppList}."; else unset AppList; fi
#fi

log_print() {
  local LOGFILE=/cache/magisk.log
  echo "AppSystemizer${ver}: $*" >> $LOGFILE
  log -p i -t "AppSystemizer${ver}" "$*"
}

# Copied from update-binary
is_mounted() {
  if [ ! -z "$2" ]; then
    cat /proc/mounts | grep $1 | grep $2, >/dev/null
  else
    cat /proc/mounts | grep $1 >/dev/null
  fi
  return $?
}
mount_image() {
  if [ ! -d "$2" ]; then
    mount -o rw,remount rootfs /
    mkdir -p $2 2>/dev/null
    ($BOOTMODE) && mount -o ro,remount rootfs /
    [ ! -d "$2" ] && return 1
  fi
  if (! is_mounted $2); then
    LOOPDEVICE=
    for LOOP in 0 1 2 3 4 5 6 7; do
      if (! is_mounted $2); then
        LOOPDEVICE=/dev/block/loop$LOOP
        if [ ! -f "$LOOPDEVICE" ]; then
          mknod $LOOPDEVICE b 7 $LOOP 2>/dev/null
        fi
        losetup $LOOPDEVICE $1
        if [ "$?" -eq "0" ]; then
          mount -t ext4 -o loop $LOOPDEVICE $2
          if (! is_mounted $2); then
            /system/bin/toolbox mount -t ext4 -o loop $LOOPDEVICE $2
          fi
          if (! is_mounted $2); then
            /system/bin/toybox mount -t ext4 -o loop $LOOPDEVICE $2
          fi
        fi
        if (is_mounted $2); then
          log_print "- Mounting $1 to $2"
          break;
        fi
      fi
    done
  fi
}
request_size_check() {
  [ -e "$1" ] && reqSizeM=$(unzip -l "$1" 2>/dev/null | tail -n 1 | awk '{ print $1 }') || reqSizeM=0
  local i apk_size line pkg_name pkg_label
  IFS=$' \t\n'; for line in "${apps[@]}"; do
    IFS=',' read pkg_name pkg_label <<< "$line"
    [[ "$pkg_name" = "android" || "$pkg_label" = "AndroidSystem" ]] && continue
    [[ -z "$pkg_name" || -z "$pkg_label" ]] && continue
      for i in /data/app/${pkg_name}-*/base.apk; do
        if [ "$i" != "/data/app/${pkg_name}-*/base.apk" ]; then
          apk_size=$(wc -c <"$i" 2>/dev/null)
          reqSizeM=$((reqSizeM + apk_size))
        fi
      done
   done
  reqSizeM=$((reqSizeM / 1048576 + 1))
}

create_merge_image() {
  BOOTMODE=true
  MODID=AppSystemizer
  TMPDIR=/dev/tmp
  INSTALLER=$TMPDIR/$MODID
  MOUNTPATH=/dev/magisk_merge
  IMGNAME=magisk_merge.img
  MODPATH=$MOUNTPATH/$MODID
  IMG=/data/$IMGNAME
  FCI='/magisk(/.*)? u:object_r:system_file:s0'

  request_size_check ""
  SIZE=$((reqSizeM / 32 * 32 + 64));
  mkdir -p $INSTALLER
  echo "$FCI" > ${INSTALLER}/file_contexts_image
  if [ -e "$IMG" ]; then
    log_print "Existing $IMG found, resizing to ${SIZE}M"
    resize2fs "$IMG" ${SIZE}M
  else
    log_print "Creating $IMG with size ${SIZE}M"
    make_ext4fs -l ${SIZE}M -a /magisk -S $INSTALLER/file_contexts_image $IMG
  fi

  mount_image $IMG $MOUNTPATH
  if ! is_mounted $MOUNTPATH; then
    log_print "! $IMG mount failed... abort"
    exit 1
  fi

  cp -af $MODDIR/. $MODPATH
  MODDIR=$MODPATH
}

upgrade() {
  OLDSYSPRIVAPPDIR="${OLDMODDIR}/system/priv-app"
  local oldVer="${1:-0}" oldVersionCode="${2:-0}"
  if [ -d "${OLDSYSPRIVAPPDIR}" ]; then
    log_print "Existing AppSystemizer $oldVer module found."
    if [ $((oldVersionCode)) -ge 56 ]; then
    	cp -rf "${OLDSYSPRIVAPPDIR}" "${MODDIR}/system/" && log_print "Migrated systemized apps from AppSystemizer $oldVer: change will take effect after reboot."
    else
      for line in "${apps[@]}"; do
        IFS=',' read pkg_name pkg_label <<< "$line"
        if [ -e "${OLDSYSPRIVAPPDIR}/${pkg_label}" ]; then
          mkdir -p "${MODDIR}/system/priv-app/${pkg_label}" 2>/dev/null
          cp -rf "${OLDSYSPRIVAPPDIR}/${pkg_label}/${pkg_label}.apk" "${MODDIR}/system/priv-app/${pkg_label}/${pkg_name}.apk" && \
            log_print "Migrated ${pkg_label} from AppSystemizer $oldVer: change will take effect after reboot."
          chown 0:0 "${MODDIR}/system/priv-app/${pkg_label}"
          chmod 0755 "${MODDIR}/system/priv-app/${pkg_label}"
          chown 0:0 "${MODDIR}/system/priv-app/${pkg_label}/${pkg_name}.apk"
          chmod 0644 "${MODDIR}/system/priv-app/${pkg_label}/${pkg_name}.apk"
        fi
      done
    fi
  else
    run
  fi
}

update() {
  OLDMODDIR="/magisk/AppSystemizer"
  if [ -d "${OLDMODDIR}" ]; then
    cp -rf "${OLDMODDIR}/auto_mount" "${MODDIR}/auto_mount"
    cp -rf "${OLDMODDIR}/module.prop" "${MODDIR}/module.prop"
    cp -rf "${OLDMODDIR}/post-fs-data.sh" "${MODDIR}/post-fs-data.sh"
  fi
  run
}

run() {
  local i apk_size line pkg_name pkg_label
  list="${apps[*]}";
  for i in ${MODDIR}/system/priv-app/*/*.apk; do
    if [ "$i" != "${MODDIR}/system/priv-app/*/*.apk" ]; then
      pkg_name="${i##*/}"; pkg_name="${pkg_name%.*}"; pkg_label="${i%/*}";  pkg_label="${pkg_label##*/}";
      if [ "$list" = "${list//${pkg_name}/}" ]; then
        rm -rf ${MODDIR}/system/priv-app/${pkg_label} && log_print "Unsystemized ${pkg_name}: change will take effect after reboot."
      fi
    fi
  done

  IFS=$' \t\n'; for line in "${apps[@]}"; do
    IFS=',' read pkg_name pkg_label <<< "$line"
    [[ "$pkg_name" = "android" || "$pkg_label" = "AndroidSystem" ]] && continue     # workaround for Companion App
    [[ -z "$pkg_name" || -z "$pkg_label" ]] && { log_print "Package name or package label empty: ${pkg_name}/${pkg_label}."; continue; }
      for i in /data/app/${pkg_name}-*/base.apk; do
        if [ "$i" != "/data/app/${pkg_name}-*/base.apk" ]; then
          [ -e "${MODDIR}/system/priv-app/${pkg_label}" ] && { log_print "Ignoring ${pkg_name}: already a systemized app."; continue; }
          [ -e "/system/priv-app/${pkg_label}" ] && { log_print "Ignoring ${pkg_name}: already a system app."; continue; }
        	mkdir -p "${MODDIR}/system/priv-app/${pkg_label}" 2>/dev/null
  	      if cp "$i" "${MODDIR}/system/priv-app/${pkg_label}/${pkg_name}.apk"; then
            log_print "Systemized ${pkg_name}: change will take effect after reboot."
          else
            log_print "Copy Failed: cp $i ${MODDIR}/system/priv-app/${pkg_label}/${pkg_name}.apk"
            [ -e ${MODDIR}/system/priv-app/${pkg_label} ] && rm -rf ${MODDIR}/system/priv-app/${pkg_label}
          fi
  	     	chown 0:0 "${MODDIR}/system/priv-app/${pkg_label}"
  	     	chmod 0755 "${MODDIR}/system/priv-app/${pkg_label}"
  	     	chown 0:0 "${MODDIR}/system/priv-app/${pkg_label}/${pkg_name}.apk"
  	     	chmod 0644 "${MODDIR}/system/priv-app/${pkg_label}/${pkg_name}.apk"
        elif [ -n "$AppList" ]; then
          log_print "Ignoring ${pkg_name}: app is not installed."
        fi
      done
  done
}

[ -d /system/priv-app ] || log_print "No access to /system/priv-app!"
[ -d /data/app ] || log_print "No access to /data/app!"

case $1 in
  upgrade)
    log_print "Installing/Upgrading AppSystemizer"
    create_merge_image
    shift; upgrade "$1" "$2"
    exit 0;;
  update)
    log_print "Updating systemized apps"
    create_merge_image
    update
    exit 0;;
  *)
    log_print "Running AppSystemizer"
    create_merge_image
    run
    exit 0;;
esac
