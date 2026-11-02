> **Reading as an AI agent?** This is the Markdown version of https://docs.meshy.ai/api/animation-library.
>
> - Full docs index: https://docs.meshy.ai/llms.txt
> - Single-fetch full content: https://docs.meshy.ai/llms-full.txt
> - Tool-calling access via MCP server: https://docs.meshy.ai/api/ai

---
# Animation Library reference

Browse every preset action you can retarget onto a rigged character, with a preview of each. To apply one, send its `action_id` when you create a task with the [Animation API](/api/animation). To get the same list as JSON, for example to build your own picker, call [`GET /openapi/v1/animations/library`](/api/animation#list-animations).

---

## Available animations
To apply several of these animations to one character in one request, send their IDs as [`action_ids`](/api/animation#create-an-animation-task) instead of one `action_id`. Meshy returns them as one file, with one clip per animation.

The following table lists each animation with its ID, name, category, subcategory, and preview.

> The full list of available animations (with `action_id`, name, category, preview URL) is served as JSON at https://api.meshy.ai/web/public/animations/resources — fetch it directly to retrieve the current catalog.

---

## Usage example
To apply an animation to your rigged character, send its `action_id` in your API request:

```javascript
const payload = {
  rig_task_id: "YOUR_RIGGING_TASK_ID",
  action_id: 92,  // Double Combo Attack animation
};

// Send this payload to the POST /openapi/v1/animations endpoint
```

To apply several animations at once, send `action_ids` instead. Meshy returns
one file with each animation as a separate clip, in the order of the list:

```javascript
const payload = {
  rig_task_id: "YOUR_RIGGING_TASK_ID",
  action_ids: [10, 25, 92], // ForwardRight Run Fight, Agree Gesture, then Double Combo Attack
};

// Send this payload to the POST /openapi/v1/animations endpoint
```

For more information about creating Animation tasks, see [Animation API](/api/animation#create-an-animation-task).
