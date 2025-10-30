from manim import *
import manim as m
import os

class TextScene(Scene):
    def construct(self):
        s = os.getenv("TEXT", "Hello (Manim) Demo!")
        color_input = os.getenv("COLOR", "red")
        base_color = getattr(m, str(color_input).upper(), color_input)

        text = Text(
            s,
            t2c={"Hello": base_color, "Manim": m.RED, "Demo": "#00FFFF", "(": m.RED, ")": m.RED}
        ).scale(1.2)
        text.set_stroke(color="#000000", width=4, opacity=0.5)
        text.set_color_by_gradient("#ff6b6b", "#ffd36e", "#5ec8ff")

        self.play(LaggedStartMap(Write, text, lag_ratio=0.05))
        self.play(ApplyWave(text, amplitude=0.2, run_time=1.2))
        self.play(Indicate(text, color=m.GOLD, scale_factor=1.05))
        self.wait(0.5)
        self.play(FadeOut(text, shift=DOWN ))
