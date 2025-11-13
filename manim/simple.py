from manim import *
from manim import config
import os
import manim as m

config.background_color = "#1e1e1e"

class TextScene(Scene):
    def construct(self):
        text_content = os.getenv("TEXT", "Hello from1 Manim!")
        color_input = os.getenv("COLOR", "red")
        color_value = getattr(m, str(color_input).upper(), color_input)
        try:
            font_size = int(float(os.getenv("FONT_SIZE", "50")))
        except Exception:
            font_size = 40
        try:
            shift_x = float(os.getenv("SHIFT_X", "1.0"))
        except Exception:
            shift_x = 1.0
        try:
            shift_y = float(os.getenv("SHIFT_Y", "0.0"))
        except Exception:
            shift_y = 0.0

        text = Text(text_content, color=color_value, font_size=font_size)  # or "#ffcc00"
        text.shift(RIGHT * shift_x + UP * shift_y)
        self.play(Write(text))
        self.wait(1)