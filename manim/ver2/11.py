from collections import deque
import numpy as np
import cv2

image_width = 1080
image_height = 720
tail = 70
pts = deque(maxlen=tail)
clr = (32,123,100)

img = np.zeros((image_height, image_width, 3), np.uint8)
vid_rec = cv2.VideoWriter('Comet_pointer_tail3.mp4', cv2.VideoWriter_fourcc(*'mp4v'), 60, (image_width, image_height))

def process_mouse_event(event,x,y,flags, cntr):
	clone = np.zeros((image_height, image_width, 3), np.uint8)
	if event == cv2.EVENT_MOUSEMOVE:
		center = (x,y)
		cv2.circle(clone, center, 5, clr, -1)
		pts.appendleft(center)
		for i in range(1, len(pts)):
			thickness = int(np.sqrt(tail/float(i + 1)) * 2)
			cv2.line(clone, pts[i - 1], pts[i], clr, thickness, lineType=cv2.LINE_AA)
	vid_rec.write(clone)
	cv2.imshow('Comet_pointer_tail', clone) 


cv2.imshow('Comet_pointer_tail', img)
vid_rec.write(img)

cv2.setMouseCallback('Comet_pointer_tail', process_mouse_event)
cv2.waitKey(0)
vid_rec.release()
cv2.destroyAllWindows()