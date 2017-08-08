#!/system/bin/sh
# Please don't hardcode /magisk/modname/... ; instead, please use $MODDIR/...
# This will make your scripts compatible even if Magisk change its mount point in the future
MODDIR=${0%/*}

# This script will be executed in post-fs-data mode
# More info in the main Magisk thread

# copied from update-binary
ps | grep zygote | grep -v grep >/dev/null && BOOTMODE=true || BOOTMODE=false
$BOOTMODE || ps -A 2>/dev/null | grep zygote | grep -v grep >/dev/null && BOOTMODE=true

is_mounted() {
  if [ ! -z "$2" ]; then
    cat /proc/mounts | grep $1 | grep $2, >/dev/null
  else
    cat /proc/mounts | grep $1 >/dev/null
  fi
  return $?
}

# Mount /data and /cache to access MAGISKBIN
mount /data 2>/dev/null
mount /cache 2>/dev/null

# This path should work in any cases
TMPDIR=/dev/tmp
MOUNTPATH=/magisk
INSTALLER=$TMPDIR/install
if is_mounted /data; then
  IMG=/data/magisk.img
  MAGISKBIN=/data/magisk
  if $BOOTMODE; then
    MOUNTPATH=/dev/magisk_merge
    IMG=/data/magisk_merge.img
  fi
else
  IMG=/cache/magisk.img
  MAGISKBIN=/cache/data_bin
  ui_print "- Data unavailable, using cache workaround"
fi

# Default permissions
umask 022

# Mount /data to access MAGISKBIN
mount /data 2>/dev/null

# Load utility fuctions
. $MAGISKBIN/util_functions.sh
get_outfd

log_print() {
  if $BOOTMODE; then
    echo "$1"
  else
    echo -n -e "ui_print AppSystemizer${ver}: $*\n" >> /proc/self/fd/$OUTFD
    echo -n -e "ui_print\n" >> /proc/self/fd/$OUTFD
  fi
  log -p i -t "AppSystemizer${ver}" "$*"
}

# set +f
STOREDLIST='/data/data/com.loserskater.appsystemizer/files/appslist.conf'
[ -s "${MODDIR}/module.prop" ] && { ver="$(sed -n 's/version=//p' ${MODDIR}/module.prop)"; ver=${ver:+ $ver}; }
apps=("com.google.android.apps.nexuslauncher,NexusLauncherPrebuilt" "com.google.android.apps.pixelclauncher,PixelCLauncherPrebuilt" "com.actionlauncher.playstore,ActionLauncher")

appsys_request_size_check() {
  local i apps line pkg_name pkg_label appsys_reqSizeM=$((reqSizeM + 2))
  [ -s "$STOREDLIST" ] && eval apps="($(<${STOREDLIST}))"
  for line in "${apps[@]}"; do
    IFS=',' read pkg_name pkg_label <<< $line
    [[ "$pkg_name" = "android" || "$pkg_label" = "AndroidSystem" ]] && continue
    [[ -z "$pkg_name" || -z "$pkg_label" ]] && continue
      for i in /data/app/${pkg_name}-*/base.apk; do
        if [ "$i" != "/data/app/${pkg_name}-*/base.apk" ]; then
          request_size_check $i
          appsys_reqSizeM=$((appsys_reqSizeM + reqSizeM))
        fi
      done
   done
  reqSizeM=$appsys_reqSizeM
}

update() {
  log_print "Updating systemized apps"
  MODID=AppSystemizer
  TMPDIR=/dev/tmp
  INSTALLER=$TMPDIR/$MODID
  MODPATH=$MOUNTPATH/$MODID
  FCI='/magisk(/.*)? u:object_r:system_file:s0'

  appsys_request_size_check
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
  run
}

upgrade() {
  log_print "Installing/Upgrading AppSystemizer"
  OLDSYSPRIVAPPDIR="/magisk/AppSystemizer/system/priv-app"
  local oldVer="${1:-0}" oldVersionCode="${2:-0}"
  if [ -d "${OLDSYSPRIVAPPDIR}" ]; then
    log_print "Existing AppSystemizer $oldVer module found."
    if [ $((oldVersionCode)) -ge 50 ]; then
    	cp -rf "${OLDSYSPRIVAPPDIR}" "${MODDIR}/system/" && log_print "Migrated systemized apps from AppSystemizer $oldVer."
    else
      for line in "${apps[@]}"; do
        IFS=',' read pkg_name pkg_label <<< $line
        if [ -e "${OLDSYSPRIVAPPDIR}/${pkg_label}" ]; then
          mkdir -p "${MODDIR}/system/priv-app/${pkg_label}" 2>/dev/null
          cp -rf "${OLDSYSPRIVAPPDIR}/${pkg_label}/${pkg_label}.apk" "${MODDIR}/system/priv-app/${pkg_label}/${pkg_name}.apk" && \
            log_print "Migrated ${pkg_label} from AppSystemizer $oldVer."
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

run() {
  log_print "Running AppSystemizer"
  [ -s "$STOREDLIST" ] && { eval apps="($(<${STOREDLIST}))"; log_print "Loaded apps list from ${STOREDLIST}."; } || { unset STOREDLIST; }
  list="${apps[*]}";
  for i in ${MODDIR}/system/priv-app/*/*.apk; do
    if [ "$i" != "${MODDIR}/system/priv-app/*/*.apk" ]; then
      pkg_name="${i##*/}"; pkg_name="${pkg_name%.*}"; pkg_label="${i%/*}";  pkg_label="${pkg_label##*/}";
      if [ "$list" = "${list//${pkg_name}/}" ]; then
        rm -rf ${MODDIR}/system/priv-app/${pkg_label} && log_print "Unsystemized ${pkg_name}: change will take effect after reboot."
      fi
    fi
  done

  for line in "${apps[@]}"; do
    IFS=',' read pkg_name pkg_label <<< $line
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
        elif [ -n "$STOREDLIST" ]; then
          log_print "Ignoring ${pkg_name}: app is not installed."
        fi
      done
  done
}

[ -d /system/priv-app ] || log_print "No access to /system/priv-app!"
[ -d /data/app ] || log_print "No access to /data/app!"

case $1 in
  upgrade)  shift; upgrade "$1" "$2";;
  update)   update;;
  *)        run;;
esac
