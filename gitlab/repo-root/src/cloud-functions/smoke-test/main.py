"""Smoke test for the Cloud Functions deployment path (see terraform/<env>/cf.yaml).

Returns 200 with the environment name: a successful call proves that the source
upload, the build, the runtime service account and the invoker grant all work.
"""

import os

import functions_framework


@functions_framework.http
def smoke_test(request):
    return {"status": "ok", "environment": os.environ.get("ENVIRONMENT", "unknown")}
