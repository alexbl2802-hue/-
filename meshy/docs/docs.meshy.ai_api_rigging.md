> **Reading as an AI agent?** This is the Markdown version of https://docs.meshy.ai/api/rigging.
>
> - Full docs index: https://docs.meshy.ai/llms.txt
> - Single-fetch full content: https://docs.meshy.ai/llms-full.txt
> - Tool-calling access via MCP server: https://docs.meshy.ai/api/ai

---
# Rigging API

Add a skeleton (armature) to a humanoid 3D model and bind the mesh to it, so the character is ready to animate. To apply animations to a rigged character, see the [Animation API](/api/animation).

Rigging works well only with standard humanoid (bipedal) characters that have a clearly defined limb and body structure.

---

## POST /openapi/v1/rigging -- Create a Rigging task

Creates a Rigging task for a 3D model. When the task succeeds, it returns a rigged character in standard formats and, optionally, basic walking and running animations.

The task runs in the background. For how long a task usually takes, see [Processing times](/api/task-lifecycle#processing-times).

Rigging isn't suitable for these models:
- Untextured meshes
- Non-humanoid assets
- Humanoid assets with an unclear limb and body structure

### Parameters

  - `input_task_id` · *string* · **required**

  Required unless you send `model_url`. The ID of the task whose model you want to rig. Meshy supports textured humanoid models.

  The model can have at most 380,000 triangles (a quad counts as 2), and a model with more returns `400`. To stay under the limit, run the [Remesh API](/api/remesh) on it first with a `target_polycount` of `300000` or less, or `150000` or less with `topology: quad`.

  - `model_url` · *string* · **required**

  Required unless you send `input_task_id`. The model to rig, as a public URL or a data URI. If you send both, Meshy uses `input_task_id`.

  The model must be a GLB (`.glb`) file of at most 400 MB from an `http` or `https` URL, or 100 MB as a data URI. Rigging supports textured humanoid models.

  The model can have at most 380,000 triangles (a quad counts as 2), and a model with more returns `400`. To stay under the limit, run the [Remesh API](/api/remesh) on it first with a `target_polycount` of `300000` or less, or `150000` or less with `topology: quad`.

  The character's face must point toward the +Z axis, the standard glTF forward direction. Pose estimation fails for a model that faces another axis.

  A file over 100 MB must also follow these rules:
  * It can have at most 10,000,000 faces. A file with more returns `400`. Meshy counts faces as triangles, and a mesh drawn more than once counts once per copy.
  * It must not use Draco compression.

  - `height_meters` · *number* · default: `1.7`

  The character's approximate height, in meters. Meshy uses it to scale and rig the model more accurately. A negative value returns `400`.

  - `texture_image_url` · *string* · **deprecated**

  Leave it out when the model has its own textures. Without it, Meshy uses the textures embedded in the `model_url` file, or the input task's textures. If you send it, this image becomes the rigged model's only texture, and the model loses its PBR maps.

  The model's UV-unwrapped base color texture, as a public URL or a data URI. The image must be a PNG file of at most 20 MB. Another image format returns `400`.

### Returns
The `result` field of the response holds the ID of the new Rigging task.

### Failure modes

  - `400 - Bad Request`

  The request can't run. The error message says which problem it found. For example:
  * **Missing parameter**: Neither `model_url` nor `input_task_id` was sent.
  * **Invalid model format**: The `model_url` file has an unsupported extension. Only `.glb` is supported.
  * **Unreachable URL**: Meshy can't download the `model_url` file.
  * **Model file too large**: The `model_url` file is over 400 MB from an `http` or `https` URL, or over 100 MB as a data URI.
  * **Too many faces**: The `model_url` file is over 100 MB and has more than 10,000,000 faces. Reduce the face count, then send the file again.
  * **Unreadable model file**: The `model_url` file is over 100 MB, and Meshy can't read its header. For example, it's a Draco-compressed GLB.
  * **Model header too complex**: The `model_url` file is over 100 MB, and its header has too many meshes, nodes, or records to check. Reduce the number of objects in the file, then send it again.
  * **Image too large**: The `texture_image_url` image is over 20 MB.
  * **Invalid texture format**: The `texture_image_url` image isn't a PNG file.
  * **Invalid height**: `height_meters` is negative.
  * **Invalid input task**: `input_task_id` doesn't refer to a valid API task.
  * **Face count exceeded**: The input model has more than 380,000 triangles (a quad counts as 2). Run the [Remesh API](/api/remesh) on it with a `target_polycount` of `300000` or less, or `150000` or less with `topology: quad`, before you rig the model.

  Fix the request, then send it again. See [Errors](/api/errors#request-errors).

  - `401 - Unauthorized`

  The API key is missing or invalid. Check the `Authorization` header.

  - `402 - Payment Required`

  For example:
  * **Insufficient credits**: The account doesn't have enough credits for this task, or the account reached a credit limit. Check your credit balance, then retry.
  * **Free plan**: Creating a task requires a paid plan. Upgrade your plan in your [subscription settings](https://www.meshy.ai/settings/subscription), then retry.

  - `403 - Forbidden`

  `input_task_id` is a bas-relief model, which this endpoint can't rig. The message is `This model type does not support this operation`. Send a different model.

  - `422 - Unprocessable Entity`

  Pose estimation failed. The model might not be a valid humanoid character. Send a model of a humanoid character. For `model_url`, also check that the character faces the +Z axis.

  - `429 - Too Many Requests`

  You exceeded your rate limit. Wait, then retry. See [Rate limits](/api/rate-limits).

**cURL**

```bash
# Rig a model from a URL
curl https://api.meshy.ai/openapi/v1/rigging \
  -X POST \
  -H "Authorization: Bearer ${YOUR_API_KEY}" \
  -H 'Content-Type: application/json' \
  -d '{
    "model_url": "YOUR_MODEL_URL_OR_DATA_URI",
    "height_meters": 1.8
  }'
```

```javascript
import axios from 'axios'

// Rig a model from a URL
const headers = { Authorization: `Bearer ${YOUR_API_KEY}` };
const payload = {
  model_url: "YOUR_MODEL_URL_OR_DATA_URI",
  height_meters: 1.8
};

try {
  const response = await axios.post(
    'https://api.meshy.ai/openapi/v1/rigging',
    payload,
    { headers }
  );
  console.log(response.data);
} catch (error) {
  console.error(error);
}
```

```python
import requests

# Rig a model from a URL
payload = {
    "model_url": "YOUR_MODEL_URL_OR_DATA_URI",
    "height_meters": 1.8
}
headers = {
    "Authorization": f"Bearer {YOUR_API_KEY}"
}

response = requests.post(
    "https://api.meshy.ai/openapi/v1/rigging",
    headers=headers,
    json=payload,
)
response.raise_for_status()
print(response.json())
```

**Response**

```json
{
  "result": "018b314a-a1b5-716d-c222-2f1776f7f579"
}
```

---

## GET /openapi/v1/rigging/:id -- Get a Rigging task

Returns a Rigging task by its ID.

### Parameters

  - `id` · *path*

  The task ID from the create response.

### Returns
The [Rigging task object](#the-rigging-task-object).

**cURL**

```bash
curl https://api.meshy.ai/openapi/v1/rigging/018b314a-a1b5-716d-c222-2f1776f7f579 \
  -H "Authorization: Bearer ${YOUR_API_KEY}"
```

```javascript
import axios from 'axios'

const taskId = '018b314a-a1b5-716d-c222-2f1776f7f579';
const headers = { Authorization: `Bearer ${YOUR_API_KEY}` };

try {
  const response = await axios.get(
    `https://api.meshy.ai/openapi/v1/rigging/${taskId}`,
    { headers }
  );
  console.log(response.data);
} catch (error) {
  console.error(error);
}
```

```python
import requests

task_id = "018b314a-a1b5-716d-c222-2f1776f7f579"
headers = {
    "Authorization": f"Bearer {YOUR_API_KEY}"
}

response = requests.get(
    f"https://api.meshy.ai/openapi/v1/rigging/{task_id}",
    headers=headers,
)
response.raise_for_status()
print(response.json())
```

**Response**

```json
{
  "id": "018b314a-a1b5-716d-c222-2f1776f7f579",
  "type": "rig",
  "status": "SUCCEEDED",
  "created_at": 1747032400453,
  "progress": 100,
  "started_at": 1747032401314,
  "finished_at": 1747032418417,
  "expires_at": 1747291618417,
  "task_error": {

    "message": ""

  },

  "consumed_credits": 5,
  "result": {
    "rigged_character_fbx_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018b314a-a1b5-716d-c222-2f1776f7f579/output/Character_output.fbx?Expires=...",
    "rigged_character_glb_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018b314a-a1b5-716d-c222-2f1776f7f579/output/Character_output.glb?Expires=...",
    "basic_animations": {
      "walking_glb_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018b314a-a1b5-716d-c222-2f1776f7f579/output/Animation_Walking_withSkin.glb?Expires=...",
      "walking_fbx_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018b314a-a1b5-716d-c222-2f1776f7f579/output/Animation_Walking_withSkin.fbx?Expires=...",
      "walking_armature_glb_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018b314a-a1b5-716d-c222-2f1776f7f579/output/Animation_Walking_withSkin_armature.glb?Expires=...",
      "running_glb_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018b314a-a1b5-716d-c222-2f1776f7f579/output/Animation_Running_withSkin.glb?Expires=...",
      "running_fbx_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018b314a-a1b5-716d-c222-2f1776f7f579/output/Animation_Running_withSkin.fbx?Expires=...",
      "running_armature_glb_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018b314a-a1b5-716d-c222-2f1776f7f579/output/Animation_Running_withSkin_armature.glb?Expires=..."
    }
  },
  "preceding_tasks": 0
}
```

---

## DELETE /openapi/v1/rigging/:id -- Delete a Rigging task

Permanently deletes a Rigging task, including its models and data. You can't undo a delete.

### Path parameters

  - `id` · *path*

  The ID of the task to delete.

### Task status
Deleting a `PENDING` task refunds the credits it used when you created it.

An `IN_PROGRESS` task can't be deleted. The request returns `409 Conflict`,
and the task keeps running. Meshy doesn't refund a task that has started,
so deleting it would cost you both the credits and the result. Wait for it
to reach `SUCCEEDED`, `FAILED`, or `CANCELED`, then delete it.

Deleting a task in a final status (`SUCCEEDED`, `FAILED`, or `CANCELED`)
doesn't refund its credits.

### Returns
`200 OK` when the task is deleted, or `409 Conflict` when the task is
`IN_PROGRESS`.

  **cURL**

  ```bash
  curl --request DELETE \
    --url https://api.meshy.ai/openapi/v1/rigging/018b314a-a1b5-716d-c222-2f1776f7f579 \
    -H "Authorization: Bearer ${YOUR_API_KEY}"
  ```

  ```javascript
  import axios from 'axios'

  const taskId = '018b314a-a1b5-716d-c222-2f1776f7f579'
  const headers = { Authorization: `Bearer ${YOUR_API_KEY}` }

  try {
    await axios.delete(
      `https://api.meshy.ai/openapi/v1/rigging/${taskId}`,
      { headers }
    )
  } catch (error) {
    console.error(error)
  }
  ```

  ```python
  import requests

  task_id = "018b314a-a1b5-716d-c222-2f1776f7f579"
  headers = {
      "Authorization": f"Bearer {YOUR_API_KEY}"
  }

  response = requests.delete(
      f"https://api.meshy.ai/openapi/v1/rigging/{task_id}",
      headers=headers,
  )
  response.raise_for_status()
  ```

**Response**

```json
// 200 OK on success, with an empty body.
//
// 409 Conflict when the task is IN_PROGRESS. The task keeps running:
{
  "message": "Task is IN_PROGRESS and cannot be deleted. Credits for a task the worker has already started are not refundable; wait for it to reach SUCCEEDED, FAILED or CANCELED, then delete it."
}
```

---

## GET /openapi/v1/rigging -- List Rigging tasks

Returns a paginated list of your Rigging tasks, newest first. To page through the list, use `page_num` and `page_size`.

Tasks you create with the API stay in the API and don't appear in **My Assets** in the web app. To find a task whose ID you no longer have, use this endpoint.

  **cURL**

  ```bash
  curl "https://api.meshy.ai/openapi/v1/rigging?page_num=1&page_size=20" \
  -H "Authorization: Bearer ${YOUR_API_KEY}"
  ```

---

## GET /openapi/v1/rigging/:id/stream -- Stream a Rigging task

Streams a Rigging task's updates as Server-Sent Events (SSE).

### Parameters

  - `id` · *path*

  The task ID from the create response.

### Returns

A stream of [Rigging task objects](#the-rigging-task-object) as Server-Sent Events.

Each event holds the full task object, in the same shape the Get endpoint returns. While the task is `PENDING` or `IN_PROGRESS`, its result fields don't have values yet.

  **cURL**

  ```bash
  curl -N https://api.meshy.ai/openapi/v1/rigging/018b314a-a1b5-716d-c222-2f1776f7f579/stream \
  -H "Authorization: Bearer ${YOUR_API_KEY}"
  ```

  ```javascript
  const response = await fetch(
    'https://api.meshy.ai/openapi/v1/rigging/018b314a-a1b5-716d-c222-2f1776f7f579/stream',
    {
      headers: { Authorization: `Bearer ${YOUR_API_KEY}` }
    }
  );

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop();

    for (const line of lines) {
      if (line.startsWith('data:')) {
        const data = JSON.parse(line.slice(5));
        console.log(data);

        if (['SUCCEEDED', 'FAILED', 'CANCELED'].includes(data.status)) {
          reader.cancel();
        }
      }
    }
  }
  ```

  ```python
  import requests
  import json

  headers = {
      "Authorization": f"Bearer {YOUR_API_KEY}",
      "Accept": "text/event-stream"
  }
  task_id = "018b314a-a1b5-716d-c222-2f1776f7f579"

  response = requests.get(
      f'https://api.meshy.ai/openapi/v1/rigging/{task_id}/stream',
      headers=headers,
      stream=True
  )

  for line in response.iter_lines():
      if line:
          if line.startswith(b'data:'):
              data_str = line.decode('utf-8')[5:]
              try:
                  data = json.loads(data_str)
                  print(data)

                  if data.get('status') in ['SUCCEEDED', 'FAILED', 'CANCELED']:
                      break
              except json.JSONDecodeError:
                  print(f"Failed to decode JSON: {data_str}")

  response.close()
  ```

  **Response Stream**

  ```javascript
  // Error event example
  event: error
  data: {
    "status_code": 404,
    "message": "Task not found"
  }

  // Message event examples illustrate task progress.
  // These examples are shortened. Each event holds the full task object.
  event: message
  data: {
    "id": "018b314a-a1b5-716d-c222-2f1776f7f579",
    "progress": 0,
    "status": "PENDING"
  }

  event: message
  data: {
    "id": "018b314a-a1b5-716d-c222-2f1776f7f579",
    "progress": 50,
    "status": "IN_PROGRESS"
  }

  event: message
  data: { // Example of a SUCCEEDED task event, with the same fields as the Rigging task object
    "id": "018b314a-a1b5-716d-c222-2f1776f7f579",
    "type": "rig",
    "status": "SUCCEEDED",
    "created_at": 1747032400453,
    "progress": 100,
    "started_at": 1747032401314,
    "finished_at": 1747032418417,
    "expires_at": 1747291618417,
    "task_error": {

      "message": ""

    },

    "consumed_credits": 5,
    "result": {
      "rigged_character_fbx_url": "https://assets.meshy.ai/.../Character_output.fbx?...",
      "rigged_character_glb_url": "https://assets.meshy.ai/.../Character_output.glb?...",
      "basic_animations": {
        "walking_glb_url": "https://assets.meshy.ai/.../Animation_Walking_withSkin.glb?...",
        "walking_fbx_url": "https://assets.meshy.ai/.../Animation_Walking_withSkin.fbx?...",
        "walking_armature_glb_url": "https://assets.meshy.ai/.../Animation_Walking_withSkin_armature.glb?...",
        "running_glb_url": "https://assets.meshy.ai/.../Animation_Running_withSkin.glb?...",
        "running_fbx_url": "https://assets.meshy.ai/.../Animation_Running_withSkin.fbx?...",
        "running_armature_glb_url": "https://assets.meshy.ai/.../Animation_Running_withSkin_armature.glb?..."
      }
    },
    "preceding_tasks": 0
  }
```

---

## The Rigging task object
A Rigging task object describes the rigging of one character. It holds the status, the progress, and the output files when the task succeeds.

### Properties

  - `id` · *string*

  The task ID. Treat it as an opaque string, and don't rely on its format.

  - `type` · *string*

  The task type, always `rig`.

  - `status` · *string*

  The task status, one of `PENDING`, `IN_PROGRESS`, `SUCCEEDED`, `FAILED`, or `CANCELED`.

  - `progress` · *integer*

  How much of the task is done, as a percentage. It's `0` until the task starts and `100` when it succeeds.

  - `created_at` · *timestamp*

  Time the task was created, in Unix milliseconds.

  - `started_at` · *timestamp*

  Time the task started, in Unix milliseconds. It's `0` until the task starts.

  - `finished_at` · *timestamp*

  Time the task finished, in Unix milliseconds. It's `0` until the task finishes.

  - `expires_at` · *timestamp*

  Time the task's result files expire, in Unix milliseconds. After this time, Meshy can delete the files.

  - `task_error` · *object*

  The error details when the task fails. See [Errors](/api/errors#task-errors).

  - `consumed_credits` · *integer*

  The number of credits the task used. Present when the status is `PENDING`, `IN_PROGRESS`, or `SUCCEEDED`. It's `0` for a `FAILED` task, because Meshy refunds the credits when a task fails.

  - `result` · *object*

  The output file URLs. Until the task succeeds, each URL is an empty string, and `basic_animations` is `null`.

- `rigged_character_fbx_url` · *string*

  Download URL for the rigged character as an FBX file.

- `rigged_character_glb_url` · *string*

  Download URL for the rigged character as a GLB file.

- `basic_animations` · *object (optional)*

  Download URLs for the default walking and running animations.

  - `walking_glb_url` · *string*

  The walking animation with skin, as a GLB file.

  - `walking_fbx_url` · *string*

  The walking animation with skin, as an FBX file.

  - `walking_armature_glb_url` · *string*

  The walking animation's armature, as a GLB file.

  - `running_glb_url` · *string*

  The running animation with skin, as a GLB file.

  - `running_fbx_url` · *string*

  The running animation with skin, as an FBX file.

  - `running_armature_glb_url` · *string*

  The running animation's armature, as a GLB file.

  - `preceding_tasks` · *integer*

  The number of tasks ahead of this one in the queue. The value is meaningful only while the task is `PENDING`.

  <span id="example-rigging-task-object" />

  **Example Rigging Task Object**

  ```json
  {
    "id": "018b314a-a1b5-716d-c222-2f1776f7f579",
    "type": "rig",
    "status": "SUCCEEDED",
    "created_at": 1747032400453,
    "progress": 100,
    "started_at": 1747032401314,
    "finished_at": 1747032418417,
    "expires_at": 1747291618417,
    "task_error": {

      "message": ""

    },

    "consumed_credits": 5,
    "result": {
      "rigged_character_fbx_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018b314a-a1b5-716d-c222-2f1776f7f579/output/Character_output.fbx?Expires=...",
      "rigged_character_glb_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018b314a-a1b5-716d-c222-2f1776f7f579/output/Character_output.glb?Expires=...",
      "basic_animations": {
        "walking_glb_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018b314a-a1b5-716d-c222-2f1776f7f579/output/Animation_Walking_withSkin.glb?Expires=...",
        "walking_fbx_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018b314a-a1b5-716d-c222-2f1776f7f579/output/Animation_Walking_withSkin.fbx?Expires=...",
        "walking_armature_glb_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018b314a-a1b5-716d-c222-2f1776f7f579/output/Animation_Walking_withSkin_armature.glb?Expires=...",
        "running_glb_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018b314a-a1b5-716d-c222-2f1776f7f579/output/Animation_Running_withSkin.glb?Expires=...",
        "running_fbx_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018b314a-a1b5-716d-c222-2f1776f7f579/output/Animation_Running_withSkin.fbx?Expires=...",
        "running_armature_glb_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018b314a-a1b5-716d-c222-2f1776f7f579/output/Animation_Running_withSkin_armature.glb?Expires=..."
      }
    },
    "preceding_tasks": 0
  }
  ```
