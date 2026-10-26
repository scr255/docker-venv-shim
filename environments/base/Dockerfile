# Python base image
FROM python:3.13.17-slim

# uv package manager (single static binary)
COPY --from=ghcr.io/astral-sh/uv:0.13.5 /uv /usr/local/bin/uv

# Build the environment virtualenv at /opt/venv:
#   - install requirements.txt with uv
#   - build_kernel.sh adds ipykernel on top (the Jupyter kernel; enough for Zed,
#     which talks the kernel protocol itself and needs no notebook server)
RUN --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
    uv venv /opt/venv \
    && uv pip install --no-cache --python /opt/venv/bin/python \
    -r /tmp/requirements.txt

ENV VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /workspace
