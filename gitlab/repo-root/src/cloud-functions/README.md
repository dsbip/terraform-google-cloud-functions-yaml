# Cloud Functions source code

One folder per function. Terraform (`modules/cloud-functions`) zips a folder and deploys it; which environments get a function, and with which settings, is decided in `terraform/<env>/cf.yaml`.

```text
src/cloud-functions/
└── smoke-test/            source: { dir: smoke-test } in cf.yaml
    ├── main.py            entry_point: smoke_test
    ├── requirements.txt
    └── tests/             not deployed (excludes in cf.yaml)
        └── test_main.py
```

## Adding a function

1. Create `src/cloud-functions/<name>/` with the code: `main.py` + `requirements.txt` for Python, `index.js` + `package.json` for Node.js, and so on.
2. Add an entry to `terraform/<env>/cf.yaml` with `source: { dir: <name> }` and its `entry_point`.
3. Open a merge request. The plan shows the new function, its source object and its grants.

Name the folder like the function's key in `cf.yaml`. Nothing enforces it, but it keeps code and configuration easy to match.

## What gets deployed

Everything in the folder except the `excludes` in `cf.yaml` (`tests/`, `__pycache__/`, `.pytest_cache/`, `.venv/`). Keep build output out of the folder, or exclude it. A function that sets its own `excludes` replaces the default list, so repeat the defaults there.

The archive's MD5 is part of the uploaded object's name. Changing any deployed file rebuilds the function on the next apply of every environment that deploys it; an unchanged folder plans no changes. Line endings are part of the content, which is why `.gitattributes` keeps this folder in LF on Windows too.

## Running locally

```bash
cd src/cloud-functions/smoke-test
python -m venv .venv
. .venv/bin/activate                              # Windows: .venv\Scripts\activate
pip install -r requirements.txt pytest
python -m pytest tests                            # unit tests
functions-framework --target=smoke_test --debug   # serves http://localhost:8080
```
