#!/usr/bin/env python3
"""
DNS Performance Daemon FastCGI API
Serves DNS performance results via FastCGI for nginx
"""

import os
import sys
import json
import datetime
import socket
from flup.server.fcgi import WSGIServer
import logging

# Configuration
DAEMON_WORKDIR = os.environ.get('DAEMON_WORKDIR', '/var/lib/dnsperf_daemon')
LATEST_RESULT_FILE = os.path.join(DAEMON_WORKDIR, 'latest_result.txt')
API_LOGFILE = "/var/log/dnsperf_api.log"
SOCKET_PATH = "/var/run/dnsperf_api.sock"

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [API] %(message)s',
    handlers=[
        logging.FileHandler(API_LOGFILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def get_file_timestamp(filepath):
    """Get file modification timestamp in ISO format"""
    try:
        stat = os.stat(filepath)
        return datetime.datetime.fromtimestamp(stat.st_mtime).isoformat()
    except:
        return datetime.datetime.now().isoformat()

def read_result_file():
    """Read and return the latest result"""
    try:
        with open(LATEST_RESULT_FILE, 'r') as f:
            content = f.read().strip()
            return content if content else None
    except FileNotFoundError:
        return None
    except Exception as e:
        logger.error(f"Error reading result file: {e}")
        return None

def json_response(data, status='200 OK'):
    """Create JSON response"""
    response_data = json.dumps(data, indent=2)
    return [
        ('Content-Type', 'application/json'),
        ('Access-Control-Allow-Origin', '*'),
        ('Content-Length', str(len(response_data)))
    ], response_data

def text_response(data, status='200 OK'):
    """Create plain text response"""
    return [
        ('Content-Type', 'text/plain'),
        ('Access-Control-Allow-Origin', '*'),
        ('Content-Length', str(len(data)))
    ], data

def cors_response():
    """Handle CORS preflight"""
    return [
        ('Access-Control-Allow-Origin', '*'),
        ('Access-Control-Allow-Methods', 'GET, OPTIONS'),
        ('Access-Control-Allow-Headers', 'Content-Type'),
        ('Content-Length', '0')
    ], ''

def application(environ, start_response):
    """WSGI application for FastCGI"""
    method = environ.get('REQUEST_METHOD', '')
    path = environ.get('PATH_INFO', '')

    logger.info(f"Request: {method} {path}")

    try:
        if method == 'OPTIONS':
            # CORS preflight
            headers, body = cors_response()
            start_response('200 OK', headers)
            return [body.encode('utf-8')]

        elif method == 'GET':
            if path in ['/', '/health']:
                # Health check endpoint
                data = {
                    "status": "ok",
                    "timestamp": datetime.datetime.now().isoformat(),
                    "service": "dnsperf-api"
                }
                headers, body = json_response(data)
                start_response('200 OK', headers)
                return [body.encode('utf-8')]

            elif path in ['/result', '/latest']:
                # Get latest DNS performance result
                result = read_result_file()

                if result is not None:
                    if result:
                        try:
                            latency = float(result)
                            data = {
                                "latency": latency,
                                "unit": "ms",
                                "timestamp": get_file_timestamp(LATEST_RESULT_FILE),
                                "status": "ok"
                            }
                            headers, body = json_response(data)
                            start_response('200 OK', headers)
                            return [body.encode('utf-8')]
                        except ValueError:
                            data = {"error": "Invalid result format", "status": "error"}
                            headers, body = json_response(data)
                            start_response('500 Internal Server Error', headers)
                            return [body.encode('utf-8')]
                    else:
                        data = {"error": "Result file is empty", "status": "error"}
                        headers, body = json_response(data)
                        start_response('500 Internal Server Error', headers)
                        return [body.encode('utf-8')]
                else:
                    data = {"error": "No result available yet", "status": "error"}
                    headers, body = json_response(data)
                    start_response('404 Not Found', headers)
                    return [body.encode('utf-8')]

            elif path == '/result/raw':
                # Get raw result (just the number)
                result = read_result_file()

                if result is not None:
                    if result:
                        headers, body = text_response(result)
                        start_response('200 OK', headers)
                        return [body.encode('utf-8')]
                    else:
                        headers, body = text_response("Result file is empty")
                        start_response('500 Internal Server Error', headers)
                        return [body.encode('utf-8')]
                else:
                    headers, body = text_response("No result available yet")
                    start_response('404 Not Found', headers)
                    return [body.encode('utf-8')]

            else:
                # 404 Not Found
                data = {
                    "error": "Endpoint not found",
                    "available_endpoints": ["/health", "/result", "/result/raw"],
                    "status": "error"
                }
                headers, body = json_response(data)
                start_response('404 Not Found', headers)
                return [body.encode('utf-8')]

        else:
            # Method not allowed
            data = {
                "error": "Method not allowed",
                "allowed_methods": ["GET", "OPTIONS"],
                "status": "error"
            }
            headers, body = json_response(data)
            start_response('405 Method Not Allowed', headers)
            return [body.encode('utf-8')]

    except Exception as e:
        logger.error(f"Application error: {e}")
        data = {"error": "Internal server error", "status": "error"}
        headers, body = json_response(data)
        start_response('500 Internal Server Error', headers)
        return [body.encode('utf-8')]

if __name__ == '__main__':
    logger.info("Starting DNS Performance FastCGI API server")
    logger.info(f"Using socket: {SOCKET_PATH}")

    # Clean up existing socket
    try:
        os.unlink(SOCKET_PATH)
    except OSError:
        pass

    # Start FastCGI server with Unix socket
    WSGIServer(application, bindAddress=SOCKET_PATH).run()
