
import os
import flask

app = flask.Flask(__name__)

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
  return flask.render_template('test.html')

#-------------------------------------------------------------------------------

@app.context_processor
def utility_processor():
  from config import Config

  def _get_brand_str():
    return Config()['WEBBRAND']

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
    from config import Config
    app.run(host=Config()['WEBSERVERHOST'], port=Config()['WEBSERVERPORT'], threaded=True)
