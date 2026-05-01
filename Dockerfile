FROM python:3.12-slim

WORKDIR /app
COPY src/cics_web_sessions.py .

EXPOSE 8088

ENTRYPOINT ["python3", "cics_web_sessions.py"]
CMD ["--host", "0.0.0.0", "--port", "8088", "--backend", "host.docker.internal:4321"]
