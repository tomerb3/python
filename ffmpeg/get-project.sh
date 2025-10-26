
folder="1#1-mgaraqb7_nn5d7va_32"


f(){
rm -rf /tmp/a/
mkdir /tmp/a
mkdir /tmp/a/files
mkdir /tmp/a/fonts
scp baum@192.168.0.155:/home/node/tts/background/back-45.mp4 /tmp/a/
scp baum@192.168.0.155:/home/node/tts/background/key-long1.mp3 /tmp/a/

scp baum@192.168.0.155:/home/node/tts/$folder/before.mp3 /tmp/a/
scp baum@192.168.0.155:/home/node/tts/$folder/after.mp3 /tmp/a/
scp baum@192.168.0.155:/home/node/tts/fonts/BebasNeue-Regular.ttf /tmp/a/fonts/

scp baum@192.168.0.155:/home/node/tts/$folder/files/1.tar.gz /tmp/a/files/

tar -xvzf /tmp/a/files/1.tar.gz -C /tmp/a/files
}
f
scp baum@192.168.0.155:/home/node/tts/$folder/coderun.mp3 /tmp/a/
scp baum@192.168.0.155:/home/node/tts/$folder/code.mp3 /tmp/a/
scp baum@192.168.0.155:/home/node/tts/$folder/after.mp3 /tmp/a/

# Create a backup first (optional)
cp /tmp/a/files/filters.txt /tmp/a/files/filters.txt.bak

# Do the replacements in-place
sed -i -E 's|/home/node/tts/|/tmp/a/|g; s|/app/data/[[:space:]]*|/tmp/a/|g' /tmp/a/files/filters.txt