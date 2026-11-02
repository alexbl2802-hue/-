> **Reading as an AI agent?** This is the Markdown version of https://docs.meshy.ai/api/animation.
>
> - Full docs index: https://docs.meshy.ai/llms.txt
> - Single-fetch full content: https://docs.meshy.ai/llms-full.txt
> - Tool-calling access via MCP server: https://docs.meshy.ai/api/ai

---
# Animation API

Apply animations to rigged characters, and list the animations you can apply.

---

## POST /openapi/v1/animations -- Create an Animation task

Creates an Animation task, which applies an animation to a character you rigged earlier. The animation can be one of the following:
* A preset action from the animation library (`action_id`)
* Several preset actions merged into one file (`action_ids`)
* A motion clip you generated with the [Text to Motion API](/api/text-to-motion) (`motion_task_id`)

You can also post-process the output. The task runs in the background. For how long a task usually takes, see [Processing times](/api/task-lifecycle#processing-times).

### Parameters

  - `rig_task_id` · *string* · **required**

  The ID of the Rigging task whose character to animate, from `POST /openapi/v1/rigging`. The task must have the status `SUCCEEDED`.

Send exactly one of `action_id`, `action_ids`, and `motion_task_id`.

  - `action_id` · *integer* · **required**

  Required unless you send `action_ids` or `motion_task_id`. The ID of the preset animation to apply. For the full list of animations, see the [Animation Library reference](/api/animation-library) or [List animations](#list-animations).

  - `action_ids` · *array of integers* · **required**

  Required unless you send `action_id` or `motion_task_id`. The IDs of 1 to 10 preset animations to apply at once, with no repeats. More than 10 IDs, or a repeated ID, returns `400`. For the IDs, see the [Animation Library reference](/api/animation-library).

  Meshy returns one file with one animation clip per action, which suits a state machine in a game engine. Meshy charges for each action in the list. See [Pricing](/api/pricing).

  A list with one ID works the same as sending that ID as `action_id`.

  - `motion_task_id` · *string* · **required**

  Required unless you send `action_id` or `action_ids`. The ID of a [Text to Motion](/api/text-to-motion) task whose clip to apply instead of a preset action. The task must have the status `SUCCEEDED`, and the rig must be a biped.

  Meshy retargets the clip onto the rigged character. It copies the clip when you create this task, so this task isn't affected if the Text to Motion task later expires or you delete it. Meshy keeps the Text to Motion task's files for 3 days, so apply the clip before then.

  - `post_process` · *object*

  Post-processing for the animation output. Leave it out to get the standard animation files.

  With `motion_task_id`, the retarget can produce a GLB-only animation. If you send `post_process` and no FBX file is available, the task fails with a `task_error`, and Meshy refunds your credits. Without `post_process`, the task succeeds, and `animation_fbx_url` is empty.

**Only when `post_process` is set:**
  - `operation_type` · *string*

  The operation to run. Without it, Meshy makes no extra file. A value not in the following list returns `400`.

  Available values:
  * `change_fps`: changes the frame rate to `fps`
  * `fbx2usdz`: converts the animation to USDZ
  * `extract_armature`: extracts the armature as an FBX file

  - `fps` · *integer* · default: `30`

  The frame rate to change to, one of `24`, `25`, `30`, or `60`. Applies only when `operation_type` is `change_fps`. Any other value returns `400`.

> **Note:** With `action_ids`, the task returns one merged file instead of one file per action. `animation_glb_url` and `animation_fbx_url` each point at one file that holds every requested action as a separate clip. In that file:
>
>       * **Clip order**: the order of the `action_ids` array, not the numeric order of the IDs.
>       * **Clip names**: the animation's name in the library. These match the names you get when you export all of a character's animations as one file from the Meshy web app. If two requested IDs have the same clip name, Meshy adds the `action_id` to the later one to keep names unique.
>       * **Post-processing**: Meshy applies it to the merged file, not to each clip.

### Returns
The `result` field of the response holds the ID of the new Animation task.

### Failure modes

  - `400 - Bad Request`

  The request can't run. The error message says which problem it found. For example:
  * **Missing parameter**: `rig_task_id` is missing, or none of `action_id`, `action_ids`, and `motion_task_id` was sent.
  * **Conflicting parameters**: The request has more than one of `action_id`, `action_ids`, and `motion_task_id`. Send only one.
  * **Invalid rig task**: `rig_task_id` isn't a valid task ID, isn't a Rigging task, or points to a task that hasn't succeeded.
  * **Invalid action ID**: An `action_id`, or an entry in `action_ids`, isn't a valid animation.
  * **Too many actions**: `action_ids` has more than 10 IDs.
  * **Duplicate actions**: `action_ids` has the same ID more than once.
  * **Motion task not ready**: The `motion_task_id` task hasn't reached `SUCCEEDED` yet.
  * **Unsupported rig**: `motion_task_id` needs a biped rig, and Meshy rejects a quadruped rig.

  Fix the request, then send it again. See [Errors](/api/errors#request-errors).

  - `401 - Unauthorized`

  The API key is missing or invalid. Check the `Authorization` header.

  - `402 - Payment Required`

  For example:
  * **Insufficient credits**: The account doesn't have enough credits for this task, or the account reached a credit limit. Check your credit balance, then retry.
  * **Free plan**: Creating a task requires a paid plan. Upgrade your plan in your [subscription settings](https://www.meshy.ai/settings/subscription), then retry.

  - `403 - Forbidden`

  The `rig_task_id` task is a bas-relief model, which this endpoint can't animate. The message is `This model type does not support this operation`. Rig a different model.

  - `404 - Not Found`

  Meshy can't find a task or file the request needs. One of these applies:
  * Meshy can't find the `rig_task_id` task among your tasks. Check the ID.
  * Meshy deleted the `rig_task_id` task's files after its `expires_at`. Rig the character again.
  * Meshy can't find the `motion_task_id` task. Check the ID.
  * The motion clip expired, because Meshy keeps a Text to Motion task's files for 3 days. Create another Text to Motion task.

  - `429 - Too Many Requests`

  You exceeded your rate limit. Wait, then retry. See [Rate limits](/api/rate-limits).

**cURL**

```bash
# Animate a rigged model with required params only
curl https://api.meshy.ai/openapi/v1/animations \
  -X POST \
  -H "Authorization: Bearer ${YOUR_API_KEY}" \
  -H 'Content-Type: application/json' \
  -d '{
    "rig_task_id": "018b314a-a1b5-716d-c222-2f1776f7f579",
    "action_id": 92
  }'

# Apply several preset actions and get one file with one clip per action
curl https://api.meshy.ai/openapi/v1/animations \
  -X POST \
  -H "Authorization: Bearer ${YOUR_API_KEY}" \
  -H 'Content-Type: application/json' \
  -d '{
    "rig_task_id": "018b314a-a1b5-716d-c222-2f1776f7f579",
    "action_ids": [10, 25, 92]
  }'

# Apply a generated Text to Motion clip instead of a preset action
curl https://api.meshy.ai/openapi/v1/animations \
  -X POST \
  -H "Authorization: Bearer ${YOUR_API_KEY}" \
  -H 'Content-Type: application/json' \
  -d '{
    "rig_task_id": "018b314a-a1b5-716d-c222-2f1776f7f579",
    "motion_task_id": "018c425b-b2c6-727e-d333-3c1887i9h791"
  }'

# With post-processing to change FPS
curl https://api.meshy.ai/openapi/v1/animations \
  -X POST \
  -H "Authorization: Bearer ${YOUR_API_KEY}" \
  -H 'Content-Type: application/json' \
  -d '{
    "rig_task_id": "018b314a-a1b5-716d-c222-2f1776f7f579",
    "action_id": 92,
    "post_process": {
      "operation_type": "change_fps",
      "fps": 24
    }
  }'
```

```javascript
import axios from 'axios'

const headers = { Authorization: `Bearer ${YOUR_API_KEY}` };

// Animate a rigged model with required params only
const payload = {
  rig_task_id: "018b314a-a1b5-716d-c222-2f1776f7f579",
  action_id: 92
};

try {
  const response = await axios.post(
    'https://api.meshy.ai/openapi/v1/animations',
    payload,
    { headers }
  );
  console.log(response.data);
} catch (error) {
  console.error(error);
}

// Apply several preset actions and get one file with one clip per action
const multiActionPayload = {
  rig_task_id: "018b314a-a1b5-716d-c222-2f1776f7f579",
  action_ids: [10, 25, 92]
};

try {
  const response = await axios.post(
    'https://api.meshy.ai/openapi/v1/animations',
    multiActionPayload,
    { headers }
  );
  console.log(response.data);
} catch (error) {
  console.error(error);
}

// With post-processing to change FPS
const advancedPayload = {
  rig_task_id: "018b314a-a1b5-716d-c222-2f1776f7f579",
  action_id: 92,
  post_process: {
    operation_type: "change_fps",
    fps: 24
  }
};

try {
  const response = await axios.post(
    'https://api.meshy.ai/openapi/v1/animations',
    advancedPayload,
    { headers }
  );
  console.log(response.data);
} catch (error) {
  console.error(error);
}
```

```python
import requests

headers = {
    "Authorization": f"Bearer {YOUR_API_KEY}"
}

# Animate a rigged model with required params only
payload = {
    "rig_task_id": "018b314a-a1b5-716d-c222-2f1776f7f579",
    "action_id": 92
}

response = requests.post(
    "https://api.meshy.ai/openapi/v1/animations",
    headers=headers,
    json=payload,
)
response.raise_for_status()
print(response.json())

# Apply several preset actions and get one file with one clip per action
multi_action_payload = {
    "rig_task_id": "018b314a-a1b5-716d-c222-2f1776f7f579",
    "action_ids": [10, 25, 92]
}

response = requests.post(
    "https://api.meshy.ai/openapi/v1/animations",
    headers=headers,
    json=multi_action_payload,
)
response.raise_for_status()
print(response.json())

# With post-processing to change FPS
advanced_payload = {
    "rig_task_id": "018b314a-a1b5-716d-c222-2f1776f7f579",
    "action_id": 92,
    "post_process": {
        "operation_type": "change_fps",
        "fps": 24
    }
}

response = requests.post(
    "https://api.meshy.ai/openapi/v1/animations",
    headers=headers,
    json=advanced_payload,
)
response.raise_for_status()
print(response.json())
```

**Response**

```json
{
  "result": "018c425b-b2c6-727e-d333-3c1887i9h791"
}
```

---

## GET /openapi/v1/animations/:id -- Get an Animation task

Returns an Animation task by its ID.

### Parameters

  - `id` · *path*

  The task ID from the create response.

### Returns
The [Animation task object](#the-animation-task-object).

**cURL**

```bash
curl https://api.meshy.ai/openapi/v1/animations/018c425b-b2c6-727e-d333-3c1887i9h791 \
  -H "Authorization: Bearer ${YOUR_API_KEY}"
```

```javascript
import axios from 'axios'

const taskId = '018c425b-b2c6-727e-d333-3c1887i9h791';
const headers = { Authorization: `Bearer ${YOUR_API_KEY}` };

try {
  const response = await axios.get(
    `https://api.meshy.ai/openapi/v1/animations/${taskId}`,
    { headers }
  );
  console.log(response.data);
} catch (error) {
  console.error(error);
}
```

```python
import requests

task_id = "018c425b-b2c6-727e-d333-3c1887i9h791"
headers = {
    "Authorization": f"Bearer {YOUR_API_KEY}"
}

response = requests.get(
    f"https://api.meshy.ai/openapi/v1/animations/{task_id}",
    headers=headers,
)
response.raise_for_status()
print(response.json())
```

**Response**

```json
{
  "id": "018c425b-b2c6-727e-d333-3c1887i9h791",
  "type": "animate",
  "status": "SUCCEEDED",
  "created_at": 1747032440896,
  "progress": 100,
  "started_at": 1747032441210,
  "finished_at": 1747032457530,
  "expires_at": 1747291657530,
  "task_error": {

    "message": ""

  },

  "consumed_credits": 3,
  "result": {
    "animation_glb_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018c425b-b2c6-727e-d333-3c1887i9h791/output/Animation_Reaping_Swing_withSkin.glb?Expires=...",
    "animation_fbx_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018c425b-b2c6-727e-d333-3c1887i9h791/output/Animation_Reaping_Swing_withSkin.fbx?Expires=...",
    "processed_usdz_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018c425b-b2c6-727e-d333-3c1887i9h791/output/processed.usdz?Expires=...",
    "processed_armature_fbx_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018c425b-b2c6-727e-d333-3c1887i9h791/output/processed_armature.fbx?Expires=...",
    "processed_animation_fps_fbx_url": "https://assets.meshy.ai/0630d47c-84b8-4d37-bc02-69e45d9272c1/tasks/018c425b-b2c6-727e-d333-3c1887i9h791/output/processed_60fps.fbx?Expires=..."
  },
  "preceding_tasks": 0
}
```

---

## DELETE /openapi/v1/animations/:id -- Delete an Animation task

Permanently deletes an Animation task, including its models and data. You can't undo a delete.

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
    --url https://api.meshy.ai/openapi/v1/animations/018b314a-a1b5-716d-c222-2f1776f7f579 \
    -H "Authorization: Bearer ${YOUR_API_KEY}"
  ```

  ```javascript
  import axios from 'axios'

  const taskId = '018b314a-a1b5-716d-c222-2f1776f7f579'
  const headers = { Authorization: `Bearer ${YOUR_API_KEY}` }

  try {
    await axios.delete(
      `https://api.meshy.ai/openapi/v1/animations/${taskId}`,
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
      f"https://api.meshy.ai/openapi/v1/animations/{task_id}",
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

## GET /openapi/v1/animations -- List Animation tasks

Returns a paginated list of your Animation tasks, newest first. To page through the list, use `page_num` and `page_size`.

Tasks you create through the API don't appear in **My Assets** in the web app, so you manage them through the API. To find a task whose ID you no longer have, use this endpoint.

  **cURL**

  ```bash
  curl "https://api.meshy.ai/openapi/v1/animations?page_num=1&page_size=20" \
  -H "Authorization: Bearer ${YOUR_API_KEY}"
  ```

---

## GET /openapi/v1/animations/:id/stream -- Stream an Animation task

Streams an Animation task's updates as Server-Sent Events (SSE).

### Parameters

  - `id` · *path*

  The task ID from the create response.

### Returns

A stream of [Animation task objects](#the-animation-task-object) as Server-Sent Events.

Each event holds the full task object, in the same shape the Get endpoint returns. While the task is `PENDING` or `IN_PROGRESS`, its result fields don't have values yet.

  **cURL**

  ```bash
  curl -N https://api.meshy.ai/openapi/v1/animations/018c425b-b2c6-727e-d333-3c1887i9h791/stream \
  -H "Authorization: Bearer ${YOUR_API_KEY}"
  ```

  ```javascript
  const response = await fetch(
    'https://api.meshy.ai/openapi/v1/animations/018c425b-b2c6-727e-d333-3c1887i9h791/stream',
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
  task_id = "018c425b-b2c6-727e-d333-3c1887i9h791"

  response = requests.get(
      f'https://api.meshy.ai/openapi/v1/animations/{task_id}/stream',
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
    "id": "018c425b-b2c6-727e-d333-3c1887i9h791",
    "progress": 0,
    "status": "PENDING"
  }

  event: message
  data: {
    "id": "018c425b-b2c6-727e-d333-3c1887i9h791",
    "progress": 50,
    "status": "IN_PROGRESS"
  }

  event: message
  data: { // Example of a SUCCEEDED task stream item, with the same structure as the Animation task object
    "id": "018c425b-b2c6-727e-d333-3c1887i9h791",
    "type": "animate",
    "status": "SUCCEEDED",
    "created_at": 1747032440896,
    "progress": 100,
    "started_at": 1747032441210,
    "finished_at": 1747032457530,
    "expires_at": 1747291657530,
    "task_error": {

      "message": ""

    },

    "consumed_credits": 3,
    "result": {
      "animation_glb_url": "https://assets.meshy.ai/.../Animation_Reaping_Swing_withSkin.glb?...",
      "animation_fbx_url": "https://assets.meshy.ai/.../Animation_Reaping_Swing_withSkin.fbx?...",
      "processed_usdz_url": "https://assets.meshy.ai/.../processed.usdz?...",
      "processed_armature_fbx_url": "https://assets.meshy.ai/.../processed_armature.fbx?...",
      "processed_animation_fps_fbx_url": "https://assets.meshy.ai/.../processed_60fps.fbx?..."
    },
    "preceding_tasks": 0
  }
```

---

## The Animation task object
An Animation task object describes one animation applied to a rigged character. It holds the status, the progress, and the animation files when the task succeeds.

### Properties

  - `id` · *string*

  The task ID. Treat it as an opaque string, and don't rely on its format.

  - `type` · *string*

  The task type, always `animate`.

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

  Time the task's result files expire, in Unix milliseconds.

  - `task_error` · *object*

  The error details when the task fails. See [Errors](/api/errors#task-errors).

  - `consumed_credits` · *integer*

  The number of credits the task used. Present when the status is `PENDING`, `IN_PROGRESS`, or `SUCCEEDED`. It's `0` for a `FAILED` task, because Meshy refunds the credits when a task fails.

  - `result` · *object*

  Download URLs for the animation files, when the task has the status `SUCCEEDED`.

- `animation_glb_url` · *string*

  The animation as a GLB file. For a task created with `action_ids`, this one file holds every requested action as a separate clip.

- `animation_fbx_url` · *string*

  The animation as an FBX file. For a task created with `action_ids`, this one file holds every requested action as a separate clip.

- `processed_usdz_url` · *string*

  The processed animation as a USDZ file.

- `processed_armature_fbx_url` · *string*

  The processed armature as an FBX file.

- `processed_animation_fps_fbx_url` · *string*

  The animation at the changed frame rate, as an FBX file, for example when you used the `change_fps` operation.

  - `preceding_tasks` · *integer*

  The number of tasks ahead of this one in the queue. The value is meaningful only while the task is `PENDING`.

  <span id="example-animation-task-object" />

  **Example Animation Task Object**

  ```json
  {
    "id": "018c425b-b2c6-727e-d333-3c1887i9h791",
    "type": "animate",
    "status": "SUCCEEDED",
    "created_at": 1747032440896,
    "progress": 100,
    "started_at": 1747032441210,
    "finished_at": 1747032457530,
    "expires_at": 1747291657530,
    "task_error": {

      "message": ""

    },

    "consumed_credits": 3,
    "result": {
      "animation_glb_url": "https://assets.meshy.ai/.../Animation_Reaping_Swing_withSkin.glb?...",
      "animation_fbx_url": "https://assets.meshy.ai/.../Animation_Reaping_Swing_withSkin.fbx?...",
      "processed_usdz_url": "https://assets.meshy.ai/.../processed.usdz?...",
      "processed_armature_fbx_url": "https://assets.meshy.ai/.../processed_armature.fbx?...",
      "processed_animation_fps_fbx_url": "https://assets.meshy.ai/.../processed_60fps.fbx?..."
    },
    "preceding_tasks": 0
  }
  ```

---

## GET /openapi/v1/animations/library -- List animations

Returns every animation in the library, ordered by `action_id`. The response is the complete list, with no pages, so one call can fill an action picker. Filters narrow the result. To get every animation, leave them all out.

To browse the same list with an animated preview of each action, see the [Animation Library reference](/api/animation-library).

This request costs no credits.

### Parameters

  - `search` · *string*

  Text to search for. Meshy returns the animations whose `name` or `key` contains this text, ignoring case. Meshy matches the text literally, so `%` and `_` aren't wildcards.

  - `category` · *string*

  The category to list, as an exact match. An unknown category returns an empty list.

  Available values:
  * `WalkAndRun`
  * `BodyMovements`
  * `DailyActions`
  * `Fighting`
  * `Dancing`

  - `sub_category` · *string*

  The subcategory to list, as an exact match. You can send it without `category`. Subcategory names aren't unique across categories. For example, `Transitioning` is under both `Fighting` and `DailyActions`. So without `category`, the filter matches the subcategory in every category.

  - `action_ids` · *string*

  The animations to return, as up to 200 comma-separated `action_id` values. Use it to look up specific IDs instead of browsing. More than 200 IDs returns `400`.

  The response leaves out an ID that no animation has. So you can also use this filter to check whether IDs you stored are still available.

### Combining filters

Meshy applies the filters together. Each one narrows the result, so Meshy returns an animation only if it matches all of them. Within one filter, any of its values can match. For example, `search` matches `name` or `key`, and `action_ids` matches any ID in the list.

So a combination with no overlap returns an empty array, not an error. Action `92` is "Double Combo Attack", a `Fighting` animation. For example:

* `?action_ids=92&category=Fighting` returns action `92`.
* `?action_ids=92&category=Dancing` returns `[]`, because it isn't a `Dancing` animation.
* `?action_ids=92&search=walk` returns `[]`, because its name doesn't match `walk`.

To get specific animations in any category, send `action_ids` on its own.

### Returns

A list of [animation objects](#the-animation-object).

> **Note:** [Create an Animation task](#create-an-animation-task) accepts every `action_id` this endpoint returns, and this endpoint returns every ID that create accepts. Neither includes retired animations. If you cache the library, refresh it from time to time, so a retired ID doesn't stay in your picker.

  **cURL**

  ```bash
  curl "https://api.meshy.ai/openapi/v1/animations/library?category=Fighting" \
  -H "Authorization: Bearer ${YOUR_API_KEY}"
  ```

  ```javascript
  import axios from 'axios';

  const headers = {Authorization: `Bearer ${YOUR_API_KEY}`};

  try {
    const response = await axios.get(
      'https://api.meshy.ai/openapi/v1/animations/library',
      {
        headers,
        params: {category: 'Fighting'},
      }
    );
    console.log(response.data);
  } catch (error) {
    console.error(error);
  }
  ```

  ```python
  import requests

  headers = {
    "Authorization": f"Bearer {YOUR_API_KEY}"
  }

  response = requests.get(
    "https://api.meshy.ai/openapi/v1/animations/library",
    headers=headers,
    params={"category": "Fighting"},
  )
  response.raise_for_status()
  print(response.json())
  ```

**Response**

```json
[
  {
    "action_id": 4,
    "name": "Attack",
    "key": "Attack",
    "category": "Fighting",
    "sub_category": "AttackingwithWeapon",
    "preview_url": "https://cdn.meshy.ai/webapp-assets/feature-demo/animation/preview/biped/Attack.gif"
  },
  {
    "action_id": 92,
    "name": "Double Combo Attack",
    "key": "Double_Combo_Attack",
    "category": "Fighting",
    "sub_category": "AttackingwithWeapon",
    "preview_url": "https://cdn.meshy.ai/webapp-assets/feature-demo/animation/preview/biped/Double_Combo_Attack.gif"
  }
]
```

---

## The animation object
An animation object describes one animation in the library.

  - `action_id` · *integer*

  The value to send as `action_id` when you create an Animation task. It's unique and stable, but not contiguous. Retired animations leave gaps in the numbering, so don't assume that every ID in a range is valid.

  - `name` · *string*

  The animation's display name. It isn't unique, because some animations share a name with another variant. To identify an animation, use `action_id` or `key`.

  - `key` · *string*

  A unique, stable slug for the animation. Use it when you need a non-numeric ID to key your own storage on.

  - `category` · *string*

  The top-level group, for example `Fighting`.

  - `sub_category` · *string*

  The group within the category, for example `AttackingwithWeapon`.

  - `preview_url` · *string*

  URL of an animated GIF preview of the action. You can show it directly in your own picker.

<span id="example-animation-object" />

**Example Animation Object**

```json
{
  "action_id": 92,
  "name": "Double Combo Attack",
  "key": "Double_Combo_Attack",
  "category": "Fighting",
  "sub_category": "AttackingwithWeapon",
  "preview_url": "https://cdn.meshy.ai/webapp-assets/feature-demo/animation/preview/biped/Double_Combo_Attack.gif"
}
```
