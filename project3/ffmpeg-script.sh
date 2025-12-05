
#! /bin/bash
set -x 
path1="/mnt/f/ai/Comfy/ComfyUI_windows/ComfyUI/output"
pica=$(ls -1tr $path1 |grep png |tail -2 |head -1 ) 

picb=$(ls -1tr $path1 |grep png |tail -2 |tail -1 ) 

export text="People see the results, but they dont know the story behind how I doubled my followers with one strategic move"
#export text="I was just peeing between classes when a stranger crawled under my stall and turned a normal school day into horror"


echo a
pic_transform(){
  ffmpeg \
  -loop 1 -t 3 -i ComfyUI_00032_.png \
  -loop 1 -t 3 -i ComfyUI_00033_.png \
  -filter_complex "[0:v][1:v]xfade=transition=fade:duration=1:offset=2, \
                   minterpolate=mi_mode=mci:mc_mode=aobmc:vsbmc=1:fps=25" \
  -c:v libx264 -pix_fmt yuv420p /mnt/c/share/output_morph.mp4 -y
}
echo b

func1(){
    local input_mp4="/mnt/c/share/reel2.mp4"
    local pic1="$path1/$pica"
    local pic2="$path1/$picb"
    local output_mp4="/mnt/c/share/out3.mp4"
    
    local font_file="/mnt/c/share/font1.otf"
    local font_color="white"
    local font_size=40
    

    # wrap text into up to 4 lines, about 4-5 words per line, building each line separately
    local words=()
    for w in $text; do
        words+=("$w")
    done

    local max_per_line=5
    local line1=""
    local line2=""
    local line3=""
    local line4=""
    local line5=""
    local line6=""

    local idx=0
    local total=${#words[@]}
    while [ $idx -lt $total ]; do
        local line_index=$(( idx / max_per_line ))
        local word=${words[$idx]}

        case $line_index in
            0)
                if [ -z "$line1" ]; then
                    line1="$word"
                else
                    line1+=" $word"
                fi
                ;;
            1)
                if [ -z "$line2" ]; then
                    line2="$word"
                else
                    line2+=" $word"
                fi
                ;;
            2)
                if [ -z "$line3" ]; then
                    line3="$word"
                else
                    line3+=" $word"
                fi
                ;;
            3)
                if [ -z "$line4" ]; then
                    line4="$word"
                else
                    line4+=" $word"
                fi
                ;;
            4)
                if [ -z "$line5" ]; then
                    line5="$word"
                else
                    line5+=" $word"
                fi
                ;;
            5)
                if [ -z "$line6" ]; then
                    line6="$word"
                else
                    line6+=" $word"
                fi
                ;;
        esac

        idx=$(( idx + 1 ))
    done

    ffmpeg -y \
        -i "$input_mp4" \
        -loop 1 -i "$pic1" \
        -loop 1 -i "$pic2" \
        -filter_complex "[1:v]trim=0:1,setpts=PTS-STARTPTS[p1a]; \
                        [2:v]trim=0:2.5,setpts=PTS-STARTPTS[p2]; \
                        [1:v]trim=0:1.5,setpts=PTS-STARTPTS[p1b]; \
                        [p1a][p2][p1b]concat=n=3:v=1:a=0[pseq]; \
                        [0:v]trim=0:5,setpts=PTS-STARTPTS[basev]; \
                        [basev]drawbox=x=0:y=0:w=iw:h=ih/2:color=black@1:t=fill[baseb]; \
                        [pseq]scale=w=720:h=576[p16]; \
                        [baseb][p16]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2[ovl]; \
                        [ovl]drawtext=fontfile=$font_file:text=${line1@Q}:fontcolor=$font_color:fontsize=$font_size:x=(w-text_w)/2:y=120[g1]; \
                        [g1]drawtext=fontfile=$font_file:text=${line2@Q}:fontcolor=$font_color:fontsize=$font_size:x=(w-text_w)/2:y=120+$font_size+8[g2]; \
                        [g2]drawtext=fontfile=$font_file:text=${line3@Q}:fontcolor=$font_color:fontsize=$font_size:x=(w-text_w)/2:y=120+2*($font_size+8)[g3]; \
                        [g3]drawtext=fontfile=$font_file:text=${line4@Q}:fontcolor=$font_color:fontsize=$font_size:x=(w-text_w)/2:y=120+3*($font_size+8)[g4]; \
                        [g4]drawtext=fontfile=$font_file:text=${line5@Q}:fontcolor=$font_color:fontsize=$font_size:x=(w-text_w)/2:y=120+4*($font_size+8)[g5]; \
                        [g5]drawtext=fontfile=$font_file:text=${line6@Q}:fontcolor=$font_color:fontsize=$font_size:x=(w-text_w)/2:y=120+5*($font_size+8)[vout]; \
                        [0:a]atrim=0:5,asetpts=PTS-STARTPTS[aout]" \
        -map "[vout]" -map "[aout]" \
        -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest "$output_mp4"
 
 mv $path1/$pica $path1/done/
 mv $path1/$picb $path1/done/
}


func1
