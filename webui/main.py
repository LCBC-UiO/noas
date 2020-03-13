
import os
import psycopg2
from psycopg2.extras import NamedTupleCursor
from flask import Flask, request, session, g, redirect, url_for, abort, \
     render_template, flash, Markup
import flask
import datetime
import time
import base64
import collections
from auth import login_required
from gconfig import get_cfg
from gdb import get_db
from log import log_page_visit

# config

app = Flask(__name__)

#-------------------------------------------------------------------------------

# config

app.config.update(dict(
  DEBUG=True,
  SECRET_KEY='development key',
  USERNAME='admin',
  PASSWORD='default'
))
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024
app.config.from_envvar('FLASKR_SETTINGS_DEFAULT', silent=False)
if os.path.isfile(os.environ['FLASKR_SETTINGS_OVERRIDE']):
  app.config.from_envvar('FLASKR_SETTINGS_OVERRIDE', silent=False)

#-------------------------------------------------------------------------------

# routes

@app.route('/', methods=['GET'])
def web_query():
  return render_template('test.html')

def get_cfg():
  return flask.current_app.config

#-------------------------------------------------------------------------------

@app.context_processor
def utility_processor():
  def _get_brand_str():
    return get_cfg().get('WEBBRAND')

  return dict(get_brand_str=_get_brand_str)

#-------------------------------------------------------------------------------

# start

if __name__ == "__main__":
  import configdict
  import gconfig
  import auth, bp_part, bp_oth
  app.register_blueprint(auth.bp)
  app.register_blueprint(bp_part.bp)
  app.register_blueprint(bp_oth.bp)
  with app.app_context():
    app.run(host=get_cfg()['WEBSERVERHOST'], port=get_cfg()['WEBSERVERPORT'], threaded=True)
