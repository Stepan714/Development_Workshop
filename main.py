from flask import Flask, request, jsonify
import os
import time
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

log_file_path = "/app/logs/app.log"
port = os.getenv("APP_PORT", "8080")
welcome_msg = os.getenv("WELCOME_MESSAGE", "Welcome to the custom app")
log_level = os.getenv("LOG_LEVEL", "INFO")

# Метрики
log_requests_total = Counter('log_requests_total', 'Total number of /log requests')
log_succeeded_total = Counter('log_succeeded_total', 'Successfully processed /log')
log_failed_total = Counter('log_failed_total', 'Failed processed /log')
log_request_duration = Histogram('log_request_duration_seconds', 'Duration of /log processing')

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/')
def welcome():
    return welcome_msg

@app.route('/status', methods=['GET'])
def status():
    return jsonify({"status": "ok"}), 200

@app.route('/log', methods=['POST'])
def log_message():
    log_requests_total.inc()
    start = time.time()
    if request.method != 'POST':
        log_failed_total.inc()
        return 'Method not allowed', 405
    log_data = request.json
    try:
        with open(log_file_path, 'a') as log_file:
            log_file.write(log_data.get("message", "") + "\n")
        log_succeeded_total.inc()
        return jsonify({"status": "log created"}), 201
    except Exception as e:
        log_failed_total.inc()
        return str(e), 500
    finally:
        log_request_duration.observe(time.time() - start)

@app.route('/logs', methods=['GET'])
def get_logs():
    try:
        with open(log_file_path, 'r') as log_file:
            log_contents = log_file.read()
        return log_contents, 200
    except FileNotFoundError:
        return "", 200
    except Exception as e:
        return str(e), 500

if __name__ == '__main__':
    if not os.path.exists('/app/logs'):
        os.makedirs('/app/logs')
    app.run(host='0.0.0.0', port=int(port))
