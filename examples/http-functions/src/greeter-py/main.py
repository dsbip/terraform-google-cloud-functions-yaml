"""Greets the caller in the language given by GREETING_LANGUAGE."""
import os

import functions_framework

GREETINGS = {"en": "Hello", "de": "Hallo", "fr": "Bonjour"}


@functions_framework.http
def greet(request):
    word = GREETINGS.get(os.environ.get("GREETING_LANGUAGE", "en"), "Hello")
    return f"{word}, {request.args.get('name', 'World')}!"
