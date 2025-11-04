# set environment variable USER_HAS_BEEN_WELCOMED to avoid multiple welcome messages
#if [ -z "$USER_HAS_BEEN_WELCOMED" ]; then
#  export USER_HAS_BEEN_WELCOMED=true
#  echo "Welcome to Grey.ooo Github Actions Runner Container"
#  if [ -f /etc/build-time ]; then
#      # read the build time from the file and calculate how long ago it was
#      BUILD_TIME=$(cat /etc/build-time)
#      BUILD_TIME_EPOCH=$(date -d "$BUILD_TIME" +%s)
#      CURRENT_TIME_EPOCH=$(date +%s)
#      TIME_DIFF=$((CURRENT_TIME_EPOCH - BUILD_TIME_EPOCH))
#      if [ $TIME_DIFF -lt 60 ]; then
#        echo -e " > Built at $(date -u +"%Y-%m-%dT%H:%M:%SZ") ($TIME_DIFF seconds ago)\n"
#      elif [ $TIME_DIFF -lt 3600 ]; then
#        MINUTES=$((TIME_DIFF / 60))
#        echo "($MINUTES minutes ago)"
#        echo -e " > Built at $(date -u +"%Y-%m-%dT%H:%M:%SZ") ($MINUTES minutes ago)\n"
#      elif [ $TIME_DIFF -lt 86400 ]; then
#        HOURS=$((TIME_DIFF / 3600))
#        echo -e " > Built at $(date -u +"%Y-%m-%dT%H:%M:%SZ") ($HOURS hours ago)\n"
#      else
#        DAYS=$((TIME_DIFF / 86400))
#        echo -e " > Built at $(date -u +"%Y-%m-%dT%H:%M:%SZ") ($DAYS days ago)\n"
#      fi
#  else
#    echo -e " > Build time not available\n";
#  fi
#fi