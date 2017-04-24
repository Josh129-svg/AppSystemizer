##########################################################################################
#
# Magisk
# by topjohnwu
#
# This is a template zip for developers
#
##########################################################################################
##########################################################################################
#
# Instructions:
#
# 1. Place your files into system folder (delete the placeholder file)
# 2. Fill in your module's info into module.prop
# 3. Configure the settings in this file (common/config.sh)
# 4. For advanced features, add shell commands into the script files under common:
#    post-fs-data.sh, service.sh
# 5. For changing props, add your additional/modified props into common/system.prop
#
##########################################################################################

##########################################################################################
# Defines
##########################################################################################

# NOTE: This part has to be adjusted to fit your own needs

# This will be the folder name under /magisk
# This should also be the same as the id in your module.prop to prevent confusion
MODID=AppSystemizer

# Set to true if you need to enable Magic Mount
# Most mods would like it to be enabled
AUTOMOUNT=true

# Set to true if you need to load system.prop
PROPFILE=false

# Set to true if you need post-fs-data script
POSTFSDATA=true

# Set to true if you need late_start service script
LATESTARTSERVICE=false

##########################################################################################
# Installation Message
##########################################################################################

# Set what you want to show when installing your mod

print_modname() {
  ui_print "*******************************"
  ui_print "         App Systemizer        "
  ui_print "*******************************"
}

##########################################################################################
# Replace list
##########################################################################################

# List all directories you want to directly replace in the system
# By default Magisk will merge your files with the original system
# Directories listed here however, will be directly mounted to the correspond directory in the system

# You don't need to remove the example below, these values will be overwritten by your own list
# This is an example
REPLACE="
/system/app/Youtube
/system/priv-app/SystemUI
/system/priv-app/Settings
/system/framework
"

# Construct your own list here, it will overwrite the example
# !DO NOT! remove this if you don't need to replace anything, leave it empty as it is now
REPLACE="
"

##########################################################################################
# Permissions
##########################################################################################

# NOTE: This part has to be adjusted to fit your own needs

set_permissions() {
  # Default permissions, don't remove them
  set_perm_recursive  $MODPATH  0  0  0755  0644

  # Only some special files require specific permissions
  # The default permissions should be good enough for most cases

  # Some templates if you have no idea what to do:

  # set_perm_recursive  <dirname>                <owner> <group> <dirpermission> <filepermission> <contexts> (default: u:object_r:system_file:s0)
  # set_perm_recursive  $MODPATH/system/lib       0       0       0755            0644

  # set_perm  <filename>                         <owner> <group> <permission> <contexts> (default: u:object_r:system_file:s0)
  # set_perm  $MODPATH/system/bin/app_process32   0       2000    0755         u:object_r:zygote_exec:s0
  # set_perm  $MODPATH/system/bin/dex2oat         0       2000    0755         u:object_r:dex2oat_exec:s0
  # set_perm  $MODPATH/system/lib/libart.so       0       0       0644
}

# Retrieve current module.prop ver and versionCode
currentVer="$(sed -n 's/version=//p' /magisk/$MODID/module.prop)";
currentVersionCode="$(sed -n 's/versionCode=//p' /magisk/$MODID/module.prop)";

log_print() {
  local LOGFILE=/cache/magisk.log
  echo "AppSystemizer${ver}: $*" >> $LOGFILE
  log -p i -t "AppSystemizer${ver}" "$*"
}

request_size_check() {
  [ -e "$1" ] && reqSizeM=$(unzip -l "$1" 2>/dev/null | tail -n 1 | awk '{ print $1 }') || reqSizeM=0
  local i apps apk_size line pkg_name pkg_label STOREDLIST=/data/data/com.loserskater.appsystemizer/files/appslist.conf
  [ -s "$STOREDLIST" ] && eval apps="($(<${STOREDLIST}))" || reqSizeM=$((reqSizeM + 1048576))
  for line in "${apps[@]}"; do
    IFS=',' read pkg_name pkg_label <<< $line
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
