import os
from huggingface_hub import InferenceClient
import argparse

api_key = os.environ.get("HF_API_KEY")
if not api_key:
    raise RuntimeError("Missing HF_API_KEY environment variable")

parser = argparse.ArgumentParser()
parser.add_argument("--prompt", required=True)
parser.add_argument("--model", default="black-forest-labs/FLUX.1-schnell")
parser.add_argument("--output", default="out.png")
args = parser.parse_args()

client = InferenceClient(
    provider="nebius",
    api_key=api_key,
)

image = client.text_to_image(
    args.prompt,
    model=args.model,
)

# Optional validation
image.save(args.output)
print(f"Saved {args.output}")