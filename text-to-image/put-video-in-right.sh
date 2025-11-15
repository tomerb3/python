#!/bin/bash -x

# ./rundockerlaptop /mnt/c/ffmpeg/c/ 5

folder=${folder:-none} 
cd $folder
check1=${PWD##*/}

mkdir -p out
cd out
mkdir -p out
cd out 

cp -a /home/node/tts/background/back-shrink1.mp4 .
cp -a /home/node/tts/background/back-shrink2.mp4 .
cp -a /home/node/tts/background/back-shrink3.mp4 .
cp -a /home/node/tts/background/back-shrink4.mp4 .
cp -a /home/node/tts/background/back-shrink5.mp4 .

number=$(echo $check1 |cut -d "-" -f1 |cut -d "#" -f1 )
path=${folder}/out

case "$number" in
  0) number_word="zero" ;;
  1) number_word="one" ;;
  2) number_word="two" ;;
  3) number_word="three" ;;
  4) number_word="four" ;;
  5) number_word="five" ;;
  6) number_word="six" ;;
  7) number_word="seven" ;;
  8) number_word="eight" ;;
  9) number_word="nine" ;;
  10) number_word="ten" ;;
  *) number_word="$number" ;;
esac

places=("museum" "church" "pool" "sea" "garden" "forest" "mountain" "desert" "city" "village")
colors=("blue" "red" "green" "yellow" "purple" "orange" "pink" "black" "white" "gold")
backpics=("back-shrink1.mp4" "back-shrink2.mp4" "back-shrink3.mp4" "back-shrink4.mp4" "back-shrink5.mp4")

place="${places[$RANDOM % ${#places[@]}]}"
color="${colors[$RANDOM % ${#colors[@]}]}"
backpic="${backpics[$RANDOM % ${#backpics[@]}]}"

 # ./rundockerlaptop "two" /mnt/c/ffmpeg/c/ yellow church

docker run --rm \
  -e HF_API_KEY \
  -v "$path/out:/out" \
  text2image:3.10.14 \
  3.py --prompt "$color laptop near a $place , the laptop screen is with green  #00FF00 background . with bold white font with black outline border text on it of: \"${number_word}\"" \
  --output-image /out/out.png \
  --output-video /out/out.mp4 \
  --duration 20 --fps 30 --zoom 0.25 --smooth \
  --background-video /out/$backpic


#ffmpeg -y -i out/out.mp4 -vf scale=512:512 -c:v libx264 -crf 18 -preset veryfast out/out_small.mp4
