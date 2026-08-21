# Newman collection runner

**Business first:** API flow checks are a **Newman image that runs the collection at build**, not a second Java service image. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Combined Java sibling that sat next to this file: [`../java-gradle/`](../java-gradle/).

I used this four-line Dockerfile next to the combined Gradle image. `newman` is installed globally, then `newman run` executes `flow.postman_collection.json` with `test.postman_environment.json`. The collections are not in git.

```text
newman/
  Dockerfile    # mirror.gcr.io/node, newman -g, run collection + env
```

```bash
# from this directory, after the Postman JSON files are the context:
docker build -t example.registry/shop-app/newman:local .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Test as `RUN` | Green build means the collection passed |
| Global `newman` | No app `package.json` required for the runner |
| Named JSON | Collection and env filenames are the contract |

## Honest gap

Postman collections, environment JSON, and any app source are not in this folder. `COPY . .` plus `newman run` expect those two JSON files. A rebuild from this directory alone fails. The base `FROM mirror.gcr.io/node` is unpinned (that is the source line).

**Keywords:** Newman, Postman, API e2e, node
