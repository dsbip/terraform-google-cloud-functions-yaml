"""Status endpoint deployed without YAML."""
import functions_framework


@functions_framework.http
def status(request):
    return {"status": "ok"}
