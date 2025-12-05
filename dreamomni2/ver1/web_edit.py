import torch
from dreamomni2.pipeline_dreamomni2 import DreamOmni2Pipeline
from diffusers.utils import load_image
from transformers import Qwen2_5_VLForConditionalGeneration, AutoProcessor
# from qwen_vl_utils import process_vision_info
from utils.vprocess import process_vision_info, resizeinput
import os
import re
from PIL import Image
import gradio as gr
import uuid
import argparse 

def parse_args():
    """Parses command-line arguments for model paths and server configuration."""
    parser = argparse.ArgumentParser(description="Launch DreamOmni2 Editing Gradio Demo.")
    parser.add_argument(
        "--vlm_path", 
        type=str, 
        default="vlm-model", 
        help="Path to the Qwen2_5_VL VLM model directory."
    )
    parser.add_argument(
        "--edit_lora_path", 
        type=str, 
        default="edit_lora", 
        help="Path to the FLUX.1-Kontext editing LoRA weights directory."
    )
    parser.add_argument(
        "--server_name", 
        type=str, 
        default="0.0.0.0", 
        help="The server name (IP address) to host the Gradio demo."
    )
    parser.add_argument(
        "--server_port", 
        type=int, 
        default=7860, 
        help="The port number to host the Gradio demo."
    )
    args = parser.parse_args()
    return args

ARGS = parse_args()
vlm_path = ARGS.vlm_path
edit_lora_path = ARGS.edit_lora_path
server_name = ARGS.server_name
server_port = ARGS.server_port
device = "cuda"

def extract_gen_content(text):
    text = text[6:-7]
    return text

print(f"Loading models from vlm_path: {vlm_path}, edit_lora_path: {edit_lora_path}")

pipe = DreamOmni2Pipeline.from_pretrained(
    "black-forest-labs/FLUX.1-Kontext-dev",
    torch_dtype=torch.bfloat16
)
pipe.to(device)
pipe.load_lora_weights(edit_lora_path, adapter_name="edit")
pipe.set_adapters(["edit"], adapter_weights=[1])    

vlm_model = Qwen2_5_VLForConditionalGeneration.from_pretrained(
    vlm_path,
    torch_dtype="bfloat16",
    device_map="cuda"
)
processor = AutoProcessor.from_pretrained(vlm_path)


def infer_vlm(input_img_path, input_instruction, prefix):
    if not vlm_model or not processor:
        raise gr.Error("VLM Model not loaded. Cannot process prompt.")
    tp = []
    for path in input_img_path:
        tp.append({"type": "image", "image": path})
    tp.append({"type": "text", "text": input_instruction + prefix})
    messages = [{"role": "user", "content": tp}]

    text = processor.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    image_inputs, video_inputs = process_vision_info(messages)
    inputs = processor(text=[text], images=image_inputs, videos=video_inputs, padding=True, return_tensors="pt")
    inputs = inputs.to("cuda")

    generated_ids = vlm_model.generate(**inputs, do_sample=False, max_new_tokens=4096)
    generated_ids_trimmed = [out_ids[len(in_ids):] for in_ids, out_ids in zip(inputs.input_ids, generated_ids)]
    output_text = processor.batch_decode(generated_ids_trimmed, skip_special_tokens=True, clean_up_tokenization_spaces=False)
    return output_text[0]

PREFERRED_KONTEXT_RESOLUTIONS = [
    (672, 1568),
    (688, 1504),
    (720, 1456),
    (752, 1392),
    (800, 1328),
    (832, 1248),
    (880, 1184),
    (944, 1104),
    (1024, 1024),
    (1104, 944),
    (1184, 880),
    (1248, 832),
    (1328, 800),
    (1392, 752),
    (1456, 720),
    (1504, 688),
    (1568, 672),
]
def find_closest_resolution(width, height, preferred_resolutions):
    input_ratio = width / height
    closest_resolution = min(
        preferred_resolutions,
        key=lambda res: abs((res[0] / res[1]) - input_ratio)
    )
    return closest_resolution

def perform_edit(input_img_paths, input_instruction, output_path):
    prefix = " It is editing task."
    source_imgs = []
    for path in input_img_paths:
        img = load_image(path)
        # source_imgs.append(img)
        source_imgs.append(resizeinput(img))
    prompt = infer_vlm(input_img_paths, input_instruction, prefix)
    prompt = extract_gen_content(prompt)
    print(f"Generated Prompt for VLM: {prompt}")

    image = pipe(
        images=source_imgs,
        height=source_imgs[0].height,
        width=source_imgs[0].width,
        prompt=prompt,
        num_inference_steps=30,
        guidance_scale=3.5,
    ).images[0]
    image.save(output_path)
    print(f"Edit result saved to {output_path}")


def process_request(image_file_1, image_file_2, instruction):
    # debugpy.listen(5678)
    # print("Waiting for debugger attach...")
    # debugpy.wait_for_client()
    if not image_file_1 or not image_file_2:
        raise gr.Error("Please upload both images.")
    if not instruction:
        raise gr.Error("Please provide an instruction.")
    if not pipe or not vlm_model:
        raise gr.Error("Models not loaded. Check the console for errors.")
    
    output_path = f"/tmp/{uuid.uuid4()}.png"
    input_img_paths = [image_file_1, image_file_2]  # List of file paths from the two gr.File inputs

    perform_edit(input_img_paths, instruction, output_path)
    return output_path


css = """
.text-center { text-align: center; }
.result-img img {
    max-height: 60vh !important; 
    min-height: 30vh !important;
    width: auto !important;      
    object-fit: contain;         
}
.input-img img {
    max-height: 30vh !important; 
    width: auto !important;      
    object-fit: contain;         
}
"""


with gr.Blocks(theme=gr.themes.Soft(), title="DreamOmni2", css=css) as demo:
    gr.HTML(
        """
        <h1 style="text-align:center; font-size:48px; font-weight:bold; margin-bottom:20px;">
            DreamOmni2: Omni-purpose Image Generation and Editing
        </h1>
        """
    )
    gr.Markdown(
        "Select a mode, upload two images, provide an instruction, and click 'Run'.",
        elem_classes="text-center"
    )
    with gr.Row():
        with gr.Column(scale=2):
            gr.Markdown("⬆️ Upload images. Click or drag to upload.")
            
            with gr.Row():
                image_uploader_1 = gr.Image(
                    label="Img 1",
                    type="filepath",
                    interactive=True,
                    elem_classes="input-img",
                )
                image_uploader_2 = gr.Image(
                    label="Img 2",
                    type="filepath",
                    interactive=True,
                    elem_classes="input-img",
                )
            
            instruction_text = gr.Textbox(
                label="Instruction",
                lines=2,
                placeholder="Input your instruction for generation or editing here...",
            )
            run_button = gr.Button("Run", variant="primary")

        with gr.Column(scale=2):
            gr.Markdown(
                "✏️ **Editing Mode**: Modify an existing image using instructions and references.\n\n"
                "Tip: If the result is not what you expect, try clicking **Run** again. "
            )
            output_image = gr.Image(
                label="Result",
                type="filepath",
                elem_classes="result-img",
            )

    # --- Examples (不变) ---
    gr.Markdown("## Examples")

    gr.Examples(
        label="Editing Examples",
        examples=[
            ["example_input/edit_tests/4/ref_0.jpg", "example_input/edit_tests/4/ref_1.jpg", "Replace the first image have the same image style as the second image.","example_input/edit_tests/4/res.jpg"],
            ["example_input/edit_tests/5/ref_0.jpg", "example_input/edit_tests/5/ref_1.jpg", "Make the person in the first image have the same hairstyle as the person in the second image.","example_input/edit_tests/5/res.jpg"],
            ["example_input/edit_tests/src.jpg", "example_input/edit_tests/ref.jpg", "Make the woman from the second image stand on the road in the first image.","example_input/edit_tests/edi_res.png"],
            ["example_input/edit_tests/1/ref_0.jpg", "example_input/edit_tests/1/ref_1.jpg", "Replace the lantern in the first image with the dog in the second image.","example_input/edit_tests/1/res.jpg"],
            ["example_input/edit_tests/2/ref_0.jpg", "example_input/edit_tests/2/ref_1.jpg", "Replace the suit in the first image with the clothes in the second image.","example_input/edit_tests/2/res.jpg"],
            ["example_input/edit_tests/3/ref_0.jpg", "example_input/edit_tests/3/ref_1.jpg", "Make the first image has the same light condition as the second image.","example_input/edit_tests/3/res.jpg"],
            ["example_input/edit_tests/6/ref_0.jpg", "example_input/edit_tests/6/ref_1.jpg", "Make the words in the first image have the same font as the words in the second image.","example_input/edit_tests/6/res.jpg"],
            ["example_input/edit_tests/7/ref_0.jpg", "example_input/edit_tests/7/ref_1.jpg", "Make the car in the first image have the same pattern as the mouse in the second image.","example_input/edit_tests/7/res.jpg"],
            ["example_input/edit_tests/8/ref_0.jpg", "example_input/edit_tests/8/ref_1.jpg", "Make the dress in the first image have the same pattern in the second image.","example_input/edit_tests/8/res.jpg"],
        ],
        inputs=[image_uploader_1, image_uploader_2, instruction_text, output_image],
        cache_examples=False,
    )

    run_button.click(
        fn=process_request,
        inputs=[image_uploader_1, image_uploader_2, instruction_text],
        outputs=output_image
    )

if __name__ == "__main__":
    print("Launching Gradio Demo...")
    demo.launch(server_name=server_name, server_port=server_port)
