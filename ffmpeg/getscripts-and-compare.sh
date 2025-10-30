#!/bin/bash 

rm -rf /tmp/scripts1
mkdir /tmp/scripts1

scp baum@192.168.0.155:/home/node/tts/scripts/ffmpeg/runit.sh /tmp/scripts1/
scp baum@192.168.0.155:/home/node/tts/scripts/ffmpeg/ffmpeg-run.sh /tmp/scripts1/

echo runit.sh left-master right-sshn8n
sleep 1
diff runit.sh /tmp/scripts1/runit.sh
echo =========
sleep 3



echo ffmpeg-run.sh left-master right-sshn8n
sleep 1
diff ffmpeg-run.sh /tmp/scripts1/ffmpeg-run.sh
echo =========
sleep 3

# Prompt to update files
read -r -p "Do you want to update files? [y/N]: " ans
case "$ans" in
  y|Y|yes|Yes)
    ;;
  *)
    echo "No update selected. Exiting."
    exit 0
    ;;
esac

# Ask which target to update
echo "Choose target to update:"
select target in "sshn8n" "wsl2" "cancel"; do
  case "$target" in
    sshn8n)
      echo sshn8n
      scp runit.sh baum@192.168.0.155:/home/node/tts/scripts/ffmpeg/
      scp ffmpeg-run.sh baum@192.168.0.155:/home/node/tts/scripts/ffmpeg/
      break
      ;;
    wsl2)
      echo wsl2
      cp -a /tmp/scripts1/* /home/baum/src/python/ffmpeg/
      break
      ;;
    cancel)
      echo "Cancelled."
      exit 0
      ;;
    *)
      echo "Invalid selection. Try again."
      ;;
  esac
done
