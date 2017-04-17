#!/system/bin/sh
# Please don't hardcode /magisk/modname/... ; instead, please use $MODDIR/...
# This will make your scripts compatible even if Magisk change its mount point in the future
MODDIR=${0%/*}

# This script will be executed in post-fs-data mode
# More info in the main Magisk thread

# set +f
OLDSYSPRIVAPPDIR="/magisk/AppSystemizer/system/priv-app"
STOREDLIST=/data/data/com.loserskater.appsystemizer/files/appslist.conf
ver="$(sed -n 's/version=//p' ${MODDIR}/module.prop)"; ver=${ver:+ $ver};

apps=(
"com.google.android.apps.nexuslauncher,NexusLauncherPrebuilt"
"com.google.android.apps.pixelclauncher,PixelCLauncherPrebuilt"
"com.actionlauncher.playstore,ActionLauncher"
)

upgrade_appsystemizer() {
  local oldVer="$1" oldVersionCode="$2"
  log_print "Existing AppSystemizer $oldVer ($oldVersionCode) module found."
  if [ $((oldVersionCode)) -ge 50 ]; then
  	cp -rf "${OLDSYSPRIVAPPDIR}" "${MODDIR}/system/" && log_print "Migrated systemized apps from existing module."
  else
    for line in "${apps[@]}"; do
      IFS=',' read pkg_name pkg_label <<< $line
      if [ -e "${OLDSYSPRIVAPPDIR}/${pkg_label}" ]; then
        mkdir -p "${MODDIR}/system/priv-app/${pkg_label}" 2>/dev/null
        cp -rf "${OLDSYSPRIVAPPDIR}/${pkg_label}/${pkg_label}.apk" "${MODDIR}/system/priv-app/${pkg_label}/${pkg_name}.apk" && \
          log_print "Migrated ${pkg_label} from existing module."
        chown 0:0 "${MODDIR}/system/priv-app/${pkg_label}"
        chmod 0755 "${MODDIR}/system/priv-app/${pkg_label}"
        chown 0:0 "${MODDIR}/system/priv-app/${pkg_label}/${pkg_name}.apk"
        chmod 0644 "${MODDIR}/system/priv-app/${pkg_label}/${pkg_name}.apk"
      fi
    done
  fi
  exit
}

log_print() {
  local LOGFILE=/cache/magisk.log
  echo "AppSystemizer${ver}: $*" >> $LOGFILE
  log -p i -t "AppSystemizer${ver}" "$*"
}

[ -d /system/priv-app ] || log_print "No access to /system/priv-app!"
[ -d /data/app ] || log_print "No access to /data/app!"
[[ "$1" = "upgrade" && -d "${OLDSYSPRIVAPPDIR}" ]] && shift && upgrade_appsystemizer "$1" "$2"
[ -s "$STOREDLIST" ] && { eval apps="($(<${STOREDLIST}))"; log_print "Loaded apps list from ${STOREDLIST}."; }  || { log_print "Failed to load apps list from ${STOREDLIST}."; unset STOREDLIST; }
list="${apps[*]}";
for i in ${MODDIR}/system/priv-app/*/*.apk; do
  if [ "$i" != "${MODDIR}/system/priv-app/*/*.apk" ]; then
    pkg_name="${i##*/}"; pkg_name="${pkg_name%.*}"; pkg_label="${i%/*}";  pkg_label="${pkg_label##*/}";
    if [ "$list" = "${list//${pkg_name}/}" ]; then
      rm -rf ${MODDIR}/system/priv-app/${pkg_label} && log_print "Unsystemized system/priv-app/${pkg_label}/${pkg_name}."
    fi
  fi
done

for line in "${apps[@]}"; do
  IFS=',' read pkg_name pkg_label <<< $line
  [[ "$pkg_name" = "android" || "$pkg_label" = "AndroidSystem" ]] && continue     # workaround for Companion App
  [[ -z "$pkg_name" || -z "$pkg_label" ]] && { log_print "Package name or package label empty: ${pkg_name}/${pkg_label}."; continue; }
    for i in /data/app/${pkg_name}-*/base.apk; do
      if [ "$i" != "/data/app/${pkg_name}-*/base.apk" ]; then
        [ -e "${MODDIR}/system/priv-app/${pkg_label}" ] && { log_print "Ignoring /data/app/${pkg_name}: already a systemized app."; continue; }
        [ -e "/system/priv-app/${pkg_label}" ] && { log_print "Ignoring /data/app/${pkg_name}: already a system app."; continue; }
      	mkdir -p "${MODDIR}/system/priv-app/${pkg_label}" 2>/dev/null
	      cp -f "$i" "${MODDIR}/system/priv-app/${pkg_label}/${pkg_name}.apk" && log_print "Created priv-app/${pkg_label}/${pkg_name}.apk" || \
          log_print "Copy Failed: $i ${MODDIR}/system/priv-app/${pkg_label}/${pkg_name}.apk"
	     	chown 0:0 "${MODDIR}/system/priv-app/${pkg_label}"
	     	chmod 0755 "${MODDIR}/system/priv-app/${pkg_label}"
	     	chown 0:0 "${MODDIR}/system/priv-app/${pkg_label}/${pkg_name}.apk"
	     	chmod 0644 "${MODDIR}/system/priv-app/${pkg_label}/${pkg_name}.apk"
      elif [ -n "$STOREDLIST" ]; then
        log_print "Ignoring ${pkg_name}: app is not installed."
      fi
    done
done
