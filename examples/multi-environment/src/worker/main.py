"""worker function of the multi-environment example."""
import os

import functions_framework


@functions_framework.http
def handler(request):
    return f"worker in {os.environ.get('ENVIRONMENT')}"
