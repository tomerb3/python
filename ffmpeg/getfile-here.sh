
folder="1#1-mgaraqb7_nn5d7va_32"
rm -rf /tmp/a/
mkdir /tmp/a
scp baum@192.168.0.155:/home/node/tts/background/back-45.mp4 /tmp/a/

scp baum@192.168.0.155:/home/node/tts/$folder/before.mp3 /tmp/a/
scp baum@192.168.0.155:/home/node/tts/$folder/after.mp3 /tmp/a/

