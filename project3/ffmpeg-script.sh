
#! /bin/bash
set -x 



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
    local input_mp4="/mnt/c/share/reel1.mp4"
    local pic1="/mnt/c/share/pic1.png"
    local pic2="/mnt/c/share/pic2.png"
    local output_mp4="/mnt/c/share/out.mp4"
    local text="tomer baum kuku Sample Text tomer baum aviv ariel hana lola sarah tomer baum hana haim doda lala mamani nonori"
    local font_file="/mnt/c/share/font.ttf"
    local font_color="white"
    

    # wrap text into up to 4 lines, about 4-5 words per line
    local words=()
    for w in $text; do
        words+=("$w")
    done

    local wrapped_text=""
    local count=0
    local line=1
    local max_lines=4
    local max_per_line=5


     for w in "${words[@]}"; do
        if [ -z "$wrapped_text" ]; then
        wrapped_text="$w"
        count=1
        else
        if [ $count -ge $max_per_line ] && [ $line -lt $max_lines ]; then
            wrapped_text="${wrapped_text}\\n$w"
            count=1
            ((line++))
        else
            wrapped_text+=" $w"
            ((count++))
        fi
        fi
    done
    # after building wrapped_text
    wrapped_text_escaped=${wrapped_text//\'/\\\'}

    ffmpeg -y \
        -i "$input_mp4" \
        -loop 1 -i "$pic1" \
        -loop 1 -i "$pic2" \
        -filter_complex "[1:v]trim=0:1,setpts=PTS-STARTPTS[p1a]; \
                        [2:v]trim=0:2.5,setpts=PTS-STARTPTS[p2]; \
                        [1:v]trim=0:1.5,setpts=PTS-STARTPTS[p1b]; \
                        [p1a][p2][p1b]concat=n=3:v=1:a=0[pseq]; \
                        [0:v]trim=0:5,setpts=PTS-STARTPTS[basev]; \
                        [pseq]scale=iw:iw*9/16[p16]; \
                        [basev][p16]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2[ovl]; \
                        [ovl]drawtext=fontfile=$font_file:text='$wrapped_text_escaped':fontcolor=$font_color:fontsize=48:x=(w-text_w)/2:y=50[vout]; \
                        [0:a]atrim=0:5,asetpts=PTS-STARTPTS[aout]" \
        -map "[vout]" -map "[aout]" \
        -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest "$output_mp4"
 
}


func1
