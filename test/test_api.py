import pytest
import requests
import json
import pandas as pd
from test_fixtures import run_dbimport, start_webui, setup_database

def test_webui_landing(setup_database, run_dbimport, start_webui):
    response = requests.get("http://127.0.0.1:3880/php/projects.php")
    assert response.status_code == 200

    expected_response = {
        "status_ok": True,
        "status_msg": "ok",
        "type": "dbmeta",
        "data": ["Proj1", "Proj2"],
    }
    assert response.json() == expected_response

def test_api_list_vars(setup_database, run_dbimport, start_webui):
    response = requests.get("http://127.0.0.1:3880/php/dbmeta.php?prj=all")
    assert response.status_code == 200

    r = response.json()
    assert len(r["data"]["tables"]) > 1
    assert len(r["data"]["tables"]) < 100
    assert r["data"]["tables"][0]["id"] == "core"

def test_api_doublesession_bug(setup_database, run_dbimport, start_webui):
    url = "http://127.0.0.1:3880/php/query_json.php"
    payload = {
        "columns": [
            {"table_id": "core", "column_id": "subject_id"},
            {"table_id": "core", "column_id": "project_id"},
            {"table_id": "core", "column_id": "wave_code"},
            {"table_id": "core", "column_id": "subject_sex"},
            {"table_id": "core", "column_id": "visit_number"},
            {"table_id": "mri_aseg", "column_id": "volume_rh_hippocampus"},
            {"table_id": "mri_aparc", "column_id": "area_lh_bankssts"},
        ],
        "set_op": "all",
        "date": "2024-05-22T12:52:00.708Z",
        "version": "undefined (Wed May 22 12:42:59 2024)",
        "project": "Proj1",
    }
    headers = {"Content-Type": "application/json"}

    response = requests.post(url, data=json.dumps(payload), headers=headers)
    assert response.status_code == 200

    r = response.json()
    column_def = r["data"]["column_def"]
    rows = r["data"]["rows"]
    headers = [col["id"] for col in column_def]
    df = pd.DataFrame(rows, columns=headers)

    assert len(df[df["subject_id"] == 9900070]) == 3, "Expected 3 rows for subject 9900070"


def test_api_doublesession_bug_union(setup_database, run_dbimport, start_webui):
    url = "http://127.0.0.1:3880/php/query_json.php"
    payload = {
        "columns": [
            {"table_id": "core", "column_id": "subject_id"},
            {"table_id": "core", "column_id": "project_id"},
            {"table_id": "core", "column_id": "wave_code"},
            {"table_id": "core", "column_id": "subject_sex"},
            {"table_id": "core", "column_id": "visit_number"},
            {"table_id": "mri_aseg", "column_id": "volume_rh_hippocampus"},
            {"table_id": "mri_aparc", "column_id": "area_lh_bankssts"},
        ],
        "set_op": "union",
        "date": "2024-05-22T12:52:00.708Z",
        "version": "undefined (Wed May 22 12:42:59 2024)",
        "project": "Proj1",
    }
    headers = {"Content-Type": "application/json"}

    response = requests.post(url, data=json.dumps(payload), headers=headers)
    assert response.status_code == 200

    r = response.json()
    column_def = r["data"]["column_def"]
    rows = r["data"]["rows"]
    headers = [col["id"] for col in column_def]
    df = pd.DataFrame(rows, columns=headers)

    assert len(df[df["subject_id"] == 9900070]) == 2, "Expected 2 rows for subject 9900070"

def test_api_doublesession_bug_intersection(setup_database, run_dbimport, start_webui):
    url = "http://127.0.0.1:3880/php/query_json.php"
    payload = {
        "columns": [
            {"table_id": "core", "column_id": "subject_id"},
            {"table_id": "core", "column_id": "project_id"},
            {"table_id": "core", "column_id": "wave_code"},
            {"table_id": "core", "column_id": "subject_sex"},
            {"table_id": "core", "column_id": "visit_number"},
            {"table_id": "mri_aseg", "column_id": "volume_rh_hippocampus"},
            {"table_id": "mri_aparc", "column_id": "area_lh_bankssts"},
        ],
        "set_op": "intersection",
        "date": "2024-05-22T12:52:00.708Z",
        "version": "undefined (Wed May 22 12:42:59 2024)",
        "project": "Proj1",
    }
    headers = {"Content-Type": "application/json"}

    response = requests.post(url, data=json.dumps(payload), headers=headers)
    assert response.status_code == 200

    r = response.json()
    column_def = r["data"]["column_def"]
    rows = r["data"]["rows"]
    headers = [col["id"] for col in column_def]
    df = pd.DataFrame(rows, columns=headers)

    assert len(df[df["subject_id"] == 9900070]) == 2, "Expected 2 rows for subject 9900070"