FROM registry.os.wiz.io/python:3.12

ARG GIT_SHA
LABEL org.opencontainers.image.source="https://github.com/wiz-demo/summit-agent-workshop-backend"
LABEL org.opencontainers.image.revision="${GIT_SHA}"

WORKDIR /app

COPY ../../app /app/
RUN pip install -r /app/requirements.txt --upgrade --no-cache-dir && apk del wizos-keys wizos-apk-auth apk-tools busybox

ENTRYPOINT ["fastapi", "run", "main.py", "--port", "8000"]