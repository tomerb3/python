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
        text = Text(text_content, color=color_value)  # or "#ffcc00"
        self.play(Write(text))
        self.wait(1)