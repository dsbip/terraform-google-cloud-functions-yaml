"""A minimal HTTP function: GET /?name=Ada returns "Hello, Ada!"."""
import functions_framework


@functions_framework.http
def hello(request):
    name = request.args.get("name", "World")
    return f"Hello, {name}!"
