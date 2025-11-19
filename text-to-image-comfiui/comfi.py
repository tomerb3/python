#This is an example that uses the websockets api to know when a prompt execution is done
#Once the prompt execution is done it downloads the images using the /history endpoint

from websocket import create_connection  # websocket-client (https://github.com/websocket-client/websocket-client)
import uuid
import json
import urllib.request
import urllib.parse
import requests
import argparse
server_address = "192.168.0.128:8188"
client_id = str(uuid.uuid4())

def queue_prompt(prompt):
    p = {"prompt": prompt, "client_id": client_id}
    data = json.dumps(p).encode('utf-8')
    req =  urllib.request.Request("http://{}/prompt".format(server_address), data=data)
    return json.loads(urllib.request.urlopen(req).read())

def get_image(filename, subfolder, folder_type):
    data = {"filename": filename, "subfolder": subfolder, "type": folder_type}
    url_values = urllib.parse.urlencode(data)
    with urllib.request.urlopen("http://{}/view?{}".format(server_address, url_values)) as response:
        return response.read()

def get_history(prompt_id):
    with urllib.request.urlopen("http://{}/history/{}".format(server_address, prompt_id)) as response:
        return json.loads(response.read())

def get_images(ws, prompt):
    prompt_id = queue_prompt(prompt)['prompt_id']
    output_images = {}
    while True:
        out = ws.recv()
        if isinstance(out, str):
            message = json.loads(out)
            if message['type'] == 'executing':
                data = message['data']
                if data['node'] is None and data['prompt_id'] == prompt_id:
                    break #Execution is done
        else:
            continue #previews are binary data

    history = get_history(prompt_id)[prompt_id]
    for o in history['outputs']:
        for node_id in history['outputs']:
            node_output = history['outputs'][node_id]
            if 'images' in node_output:
                images_output = []
                for image in node_output['images']:
                    image_data = get_image(image['filename'], image['subfolder'], image['type'])
                    images_output.append(image_data)
            output_images[node_id] = images_output

    return output_images


def upload_file(file, subfolder="", overwrite=False):
    try:
        # Wrap file in formdata so it includes filename
        body = {"image": file}
        data = {}
        
        if overwrite:
            data["overwrite"] = "true"
  
        if subfolder:
            data["subfolder"] = subfolder

        resp = requests.post(f"http://{server_address}/upload/image", files=body,data=data)
        
        if resp.status_code == 200:
            data = resp.json()
            # Add the file to the dropdown list and update the widget value
            path = data["name"]
            if "subfolder" in data:
                if data["subfolder"] != "":
                    path = data["subfolder"] + "/" + path
            

        else:
            print(f"{resp.status_code} - {resp.reason}")
    except Exception as error:
        print(error)
    return path


def build_workflow(prompt_text: str):
    #load workflow from file (text-only workflow, no input image upload)
    with open("workflow_api.json", "r", encoding="utf-8") as f:
        workflow_data = f.read()

    workflow = json.loads(workflow_data)

    #set the text prompt for our positive CLIPTextEncode
    workflow["6"]["inputs"]["text"] = prompt_text

    #random seed
    import random

    seed = random.randint(1, 1000000000)
    return workflow, seed
#set the seed for our KSampler node
#workflow["3"]["inputs"]["seed"] = seed

"""Note: This script assumes a text-only workflow graph defined in
workflow_api.json. If your workflow contains a LoadImage node or expects
an uploaded image, either remove that node from the JSON or adapt this
script to upload and reference an image as needed.
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--prompt",
        type=str,
        default=(
            "masterpiece, best quality, a wide angle shot from the front of a girl "
            "posing on a bench in a beautiful meadow,:o face, short and rose hair,"
            "perfect legs, perfect arms, perfect eyes,perfect body, perfect feet,"
            "blue day sky,shorts, beautiful eyes,sharp focus, full body shot"
        ),
        help="Text prompt to send to ComfyUI",
    )
    args = parser.parse_args()

    workflow, seed = build_workflow(args.prompt)

    #set model (adjust to your desired checkpoint present in ComfyUI)
    #workflow["14"]["inputs"]["ckpt_name"] = "meinamix_meinaV11.safetensors"

    # Connect to ComfyUI using websocket-client helper
    ws = create_connection("ws://{}/ws?clientId={}".format(server_address, client_id))
    images = get_images(ws, workflow)
    ws.close()

    #Commented out code to display the output images:

    for node_id in images:
        for image_data in images[node_id]:
            from PIL import Image
            import io
            image = Image.open(io.BytesIO(image_data))
            #image.show()
            # save image
            image.save(f"{node_id}-{seed}.png")


if __name__ == "__main__":
    main()
