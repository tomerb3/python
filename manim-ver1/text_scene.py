from manim import *

class TextScene(Scene):
    def construct(self):
        text = Text("Hello from Manim!")
        self.play(Write(text))
        self.wait(1)

