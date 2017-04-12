#!/system/bin/sh
# Please don't hardcode /magisk/modname/... ; instead, please use $MODDIR/...
# This will make your scripts compatible even if Magisk change its mount point in the future
MODDIR=${0%/*}

# This script will be executed in post-fs-data mode
# More info in the main Magisk thread

set +f
STOREDLIST=/data/data/com.loserskater.appsystemizer/files/appslist.conf
ver="$(sed -n 's/version=//p' ${MODDIR}/module.prop)"; ver=${ver:+ $ver};

apps=(
"com.google.android.apps.nexuslauncher,NexusLauncherPrebuilt"
"com.google.android.apps.pixelclauncher,PixelCLauncherPrebuilt"
"com.actionlauncher.playstore,ActionLauncher"
)

log_print() {
  local LOGFILE=/cache/magisk.log
  echo "AppSystemizer${ver}: $*" >> $LOGFILE
  log -p i -t "AppSystemizer${ver}" "$*"
}

[ -d /system/priv-app ] || log_print "No access to /system/priv-app!"
[ -d /data/app ] || log_print "No access to /data/app!"

[ -s "$STOREDLIST" ] && { eval apps="($(<${STOREDLIST}))"; log_print "Loaded apps list from ${STOREDLIST}."; }  || { log_print "Failed to load apps list from ${STOREDLIST}."; unset STOREDLIST; }
path="${path:=priv-app}"; list="${apps[*]}";

for i in ${MODDIR}/system/${path}/*/*.apk; do
  if [ "$i" != "${MODDIR}/system/${path}/*/*.apk" ]; then
    pkg_name="${i##*/}"; pkg_name="${pkg_name%.*}"; pkg_label="${i%/*}";  pkg_label="${pkg_label##*/}";
    if [ "$list" = "${list//${pkg_name}/}" ]; then
      log_print "Unsystemizing ./system/${path}/${pkg_label}/${pkg_name}. Effective after reboot."
      rm -rf ${MODDIR}/system/${path}/${pkg_label}
    fi
  fi
done

for line in "${apps[@]}"; do
  IFS=',' read pkg_name pkg_label <<< $line
  [[ "$pkg_name" = "android" || "$pkg_label" = "AndroidSystem" ]] && continue
  [[ -z "$pkg_name" || -z "$pkg_label" ]] && { log_print "Package name or package label empty: ${pkg_name}/${pkg_label}."; continue; }
    for i in /data/app/${pkg_name}-*/base.apk; do
      if [ "$i" != "/data/app/${pkg_name}-*/base.apk" ]; then
        [ -e "${MODDIR}/system/${path}/${pkg_label}" ] && { log_print "Ignoring /data/app/${pkg_name}: already a systemized app."; continue; }
        [ -e "/system/${path}/${pkg_label}" ] && { log_print "Ignoring /data/app/${pkg_name}: already a system app."; continue; }
      	mkdir -p "${MODDIR}/system/${path}/${pkg_label}" 2>/dev/null
	      cp -f "$i" "${MODDIR}/system/${path}/${pkg_label}/${pkg_name}.apk" && log_print "Created ${path}/${pkg_label}/${pkg_name}.apk" || \
          log_print "Copy Failed: $i ${MODDIR}/system/${path}/${pkg_label}/${pkg_name}.apk"
	     	chown 0:0 "${MODDIR}/system/${path}/${pkg_label}"
	     	chmod 0755 "${MODDIR}/system/${path}/${pkg_label}"
	     	chown 0:0 "${MODDIR}/system/${path}/${pkg_label}/${pkg_name}.apk"
	     	chmod 0644 "${MODDIR}/system/${path}/${pkg_label}/${pkg_name}.apk"
      elif [ -n "$STOREDLIST" ]; then
        log_print "Ignoring ${pkg_name}: app is not installed."
      fi
    done
done
