"""internal-proxy: placeholder business logic for the networking and security example."""
import functions_framework


@functions_framework.http
def handler(request):
    return "ok"
