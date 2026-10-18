"""Runs when a document under users/{userId} is written in Firestore."""
import functions_framework


@functions_framework.cloud_event
def on_user_written(cloud_event):
    print(f"user document changed: {cloud_event['document']}")
