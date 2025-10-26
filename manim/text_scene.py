from manim import *
from manim import config

config.background_color = "#1e1e1e"

class TextScene(Scene):
    def construct(self):
        text = Text("Hello from Manim!", color=YELLOW)  # or "#ffcc00"
        self.play(Write(text))
        self.wait(1)