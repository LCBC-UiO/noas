
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

sql_getmeta = """\
select
  array_to_json(array_agg(row_to_json(t))) as meta_json
from
  (
  select
    mt.id,
    mt.category,
    mt.title,
    mt.idx,
    (
			select row_count(mt.category || '_' || mt.id)
		) as n,
    (
    select
      array_to_json(array_agg(row_to_json(d)))
    from
      (
      select
        mc.id,
        mc.title,
        mc.idx
      from
        metacolumns mc
      where
        mt.id = mc.metatable_id
      order by
        mc.idx ) d ) as cols
  from
    metatables mt
  order by
    mt.idx,
    mt.title ) t
    """

@app.route('/', methods=['GET'])
def web_query():
  from db import Db

  with Db().get().cursor() as cur:
    cur.execute(sql_getmeta);
    import json
    meta_json = cur.fetchall()[0].meta_json
    print(json.dumps(meta_json, indent=2, sort_keys=True, default=str))

  return flask.render_template('dbquery.html', dbmeta=meta_json)

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
  with app.app_context():
    from config import Config
    app.run(host=Config()['WEBSERVERHOST'], port=Config()['WEBSERVERPORT'], threaded=True)
