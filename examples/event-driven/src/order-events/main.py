"""Handles order events published to Pub/Sub (CloudEvents)."""
import base64
import json

import functions_framework


@functions_framework.cloud_event
def on_order(cloud_event):
    order = json.loads(base64.b64decode(cloud_event.data["message"]["data"]))
    print(f"order {order.get('id')} received")
