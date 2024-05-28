import pytest
import subprocess
import time
import os
import requests
from dotenv import load_dotenv

load_dotenv("config_default.txt")

def run_make_directive(directive):
    process = subprocess.run(["make", directive], capture_output=True, text=True)
    print(f"Running make directive {directive}:\nSTDOUT: {process.stdout}\nSTDERR: {process.stderr}")
    if process.returncode != 0:
        raise RuntimeError(f"Failed to run make directive {directive}: {process.stderr}")
    return process


def db_isready(host, port, dbname):
    process = subprocess.run(
        ["3rdparty/postgresql/bin/pg_isready", "-h", host, "-p", port, "-d", dbname],
        capture_output=True,
        text=True,
    )
    print(f"Checking if database is ready:\nSTDOUT: {process.stdout}\nSTDERR: {process.stderr}")
    return process.returncode == 0


def start_database():
    db_host = os.getenv("DBHOST")
    db_port = os.getenv("DBPORT")
    db_name = os.getenv("DBNAME")
    pgdata = os.getenv("PGDATA")
    print(f"Starting database with host={db_host}, port={db_port}, dbname={db_name}, pgdata={pgdata}")

    if db_isready(db_host, db_port, db_name):
        print("Database is already ready.")
        return

    process = subprocess.run(["make", "dbstart"], capture_output=True, text=True)
    print(f"Starting database:\nSTDOUT: {process.stdout}\nSTDERR: {process.stderr}")
    if process.returncode != 0:
        raise RuntimeError(f"Failed to start the database: {process.stderr}")

    for _ in range(30):
        result = db_isready(db_host, db_port, db_name)
        if result:
            print("Database started successfully.")
            return
        time.sleep(1)

    stop_database()
    raise RuntimeError("Database did not start in time")


def import_data():
    process = subprocess.run(["make", "run_dbimport"], capture_output=True, text=True)
    print(f"Importing data:\nSTDOUT: {process.stdout}\nSTDERR: {process.stderr}")
    if process.returncode != 0:
        raise RuntimeError(f"Failed to import data: {process.stderr}")
    return process

def stop_database():
    process = subprocess.run(["make", "dbstop"], capture_output=True, text=True)
    print(f"Stooping database:\nSTDOUT: {process.stdout}\nSTDERR: {process.stderr}")
    if process.returncode != 0:
        raise RuntimeError(f"Failed to stop the database: {process.stderr}")

def clean_database():
    process = subprocess.run(["make", "dberase"], capture_output=True, text=True)
    print(f"Cleaning database:\nSTDOUT: {process.stdout}\nSTDERR: {process.stderr}")
    if process.returncode != 0:
        raise RuntimeError(f"Failed to clean the database: {process.stderr}")

@pytest.fixture(scope="module", autouse=True)
def setup_database():
    clean_database()
    start_database()
    yield
    clean_database()

@pytest.fixture(scope="module", autouse=True)
def run_dbimport(setup_database):
    output = run_make_directive("run_dbimport")
    return output

@pytest.fixture(scope="module", autouse=True)
def start_webui():
    webui_process = subprocess.Popen(
        ["make", "run_webui"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    time.sleep(10)  # Increase sleep time if necessary

    try:
        response = requests.get("http://127.0.0.1:3880/php/projects.php")
        if response.status_code != 200:
            raise RuntimeError("Web UI did not start correctly")
    except Exception as e:
        webui_process.terminate()
        webui_process.wait()
        raise RuntimeError("Web UI did not start correctly: " + str(e))

    yield webui_process

    webui_process.terminate()
    webui_process.wait()
