import os
from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/")
def home():
    return jsonify({
        "application": "multi-cloud-devsecops-platform",
        "environment": os.getenv("APP_ENV", "development"),
        "cloud": os.getenv("CLOUD_PROVIDER", "unknown"),
        "version": os.getenv("APP_VERSION", "dev"),
        "status": "healthy"
    })

@app.route("/health")
def health():
    return jsonify({
        "status": "healthy"
    }), 200
