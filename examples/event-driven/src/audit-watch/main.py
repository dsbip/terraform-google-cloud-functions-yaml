"""Alerts when a service account key is created (Cloud Audit Logs event)."""
import functions_framework


@functions_framework.cloud_event
def on_key_created(cloud_event):
    payload = cloud_event.data.get("protoPayload", {})
    print(f"service account key created by {payload.get('authenticationInfo', {}).get('principalEmail')}")
