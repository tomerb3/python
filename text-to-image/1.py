import os
from huggingface_hub import InferenceClient

api_key = os.environ.get("HF_API_KEY")
if not api_key:
    raise RuntimeError("Missing HF_API_KEY environment variable")

client = InferenceClient(
    provider="nebius",
    api_key=api_key,
)

image = client.text_to_image(
    "Astronaut riding a horse holding a sign with the text 'Hello World' ",
    model="black-forest-labs/FLUX.1-schnell",
)

# Optional validation
image.save("out.png")
print("Saved out.png")