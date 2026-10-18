"""webhooks function of the complete example."""
import functions_framework


@functions_framework.http
def handler(request):
    return "webhooks"
