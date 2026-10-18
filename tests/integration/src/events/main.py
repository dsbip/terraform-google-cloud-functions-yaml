"""Live-test Pub/Sub function."""
import functions_framework


@functions_framework.cloud_event
def on_event(cloud_event):
    print(cloud_event["id"])
