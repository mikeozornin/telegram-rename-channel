#!/bin/sh
# Counts solid black areas in the four screen corners per frame of a recording: the seam that shows behind a sliding
# screen's rounded corners during a push/pop. Corner boxes: 300 x 260 device px. Pixels with Y <= 20 (black in
# limited-range video), eroded 21x21 so text, status-bar glyphs and icon strokes vanish and only solid wedges stay.
# Prints "<pts> <corner> <px>" for every corner with more than 200 px (the Contacts tab icon's head alone leaves 60). Usage: Tools/seam-scan.sh video.mp4
V="$1"
W=$(ffprobe -v error -select_streams v -show_entries stream=width -of csv=p=0 "$V")
H=$(ffprobe -v error -select_streams v -show_entries stream=height -of csv=p=0 "$V")
E="erosion,erosion,erosion,erosion,erosion,erosion,erosion,erosion,erosion,erosion"
scan() { # x y tag
  ffmpeg -v error -i "$V" -fps_mode passthrough -vf "crop=300:260:$1:$2,format=gray,lut=y='if(lte(val,20),255,0)',$E,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=-" -f null - 2>/dev/null \
  | awk -v n=78000 -v tag=$3 '/pts_time/ {split($0,a,"pts_time:"); t=a[2]} /YAVG/ {split($0,b,"="); c=int(b[2]/255*n+0.5); print t, tag, c}'
}
{ scan 0 0 TL; scan $((W-300)) 0 TR; scan 0 $((H-260)) BL; scan $((W-300)) $((H-260)) BR; } | awk '$3>200' | sort -n
