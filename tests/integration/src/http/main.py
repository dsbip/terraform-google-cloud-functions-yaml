"""Live-test HTTP function."""
import functions_framework


@functions_framework.http
def hello(request):
    return "ok"
