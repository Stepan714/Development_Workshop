FROM python:3.9-slim

WORKDIR /app

COPY main.py .
RUN mkdir -p /app/logs

RUN pip install flask

ENV APP_PORT=8080
ENV WELCOME_MESSAGE="Welcome to the custom app"
ENV LOG_LEVEL=INFO

EXPOSE 8080
CMD ["python", "main.py"]
