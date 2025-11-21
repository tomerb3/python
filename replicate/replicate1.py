import argparse
import sys

import requests
import replicate
from replicate.exceptions import ModelError


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("prompt", help="Text prompt for the image")
    args = parser.parse_args()

    try:
        output = replicate.run(
            "google/imagen-4-fast",
            input={
                "prompt": args.prompt,
                "aspect_ratio": "4:3",
                "output_format": "png",
                "output_quality": 80,
                "safety_tolerance": 2,
                "prompt_upsampling": True,
            },
        )
    except ModelError as e:
        print(f"Model error: {e}", file=sys.stderr)
        sys.exit(1)

    # In this client version, output is a URL string
    print(output)

    resp = requests.get(output)
    resp.raise_for_status()
    with open("my-image.png", "wb") as file:
        file.write(resp.content)


if __name__ == "__main__":
    main()

