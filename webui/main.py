
import os
import flask
import textwrap

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
def web_buildquery():
  from db import Db
  import json
  with Db().get().cursor() as cur:
    cur.execute(sql_getmeta);
    meta_json = cur.fetchall()[0].meta_json
    #print(json.dumps(meta_json, indent=2, sort_keys=True, default=str))
    Db().get().close()
    return flask.render_template('dbquery.html', dbmeta=meta_json)


sql_getdata_main = """\
SELECT 
{col_selection}
FROM core_core as core
{joins}
WHERE TRUE AND 
{where}
ORDER BY core.subject_id, core.project_id, core.wave_code
"""

def get_sql_selection(meta_json, rvalues):
  def _get_sql_selection(tabmeta, rvalues, sqls):
    if rvalues.get('include_' + tabmeta['id']) != "1" and tabmeta['idx'] != 0:
      return
    as_pfx = tabmeta['id'] if tabmeta['idx'] != 0 else ''
    for ci in tabmeta['cols']:
      if rvalues.get('{}{}{}'.format(tabmeta['id'], '_' if tabmeta['idx'] == 0 else '', ci['id'])) == "1":
        sqls.append("{}.{} AS {}".format(tabmeta['id'], ci['id'], as_pfx+ci['id']))
  sqls = []
  for tabmeta in meta_json:
    _get_sql_selection(tabmeta, rvalues, sqls)
  return "\n,".join(sqls)


def get_sql_join(meta_json, rvalues):
  def _get_sql_join_long(tabmeta, rvalues, sqls):
    if rvalues.get('include_' + tabmeta['id']) != "1" or tabmeta['idx'] == 0:
      return
    sqls.append("LEFT OUTER JOIN long_{table_id} {table_id} ON core.subject_id={table_id}.subject_id AND core.project_id={table_id}.project_id AND core.wave_code={table_id}.wave_code".format(table_id=tabmeta['id']))
  sqls = []
  for tabmeta in meta_json:
    _get_sql_join_long(tabmeta, rvalues, sqls)
  return "\n".join(sqls)

sql_getdata_where_main= """\
(
{bool}
{conjunction_conditions})
"""

sql_getdata_where_condition_long = """\
  {conjunction} core.subject_id IN (SELECT DISTINCT(subject_id) FROM long_{table_id} t WHERE t.project_id=core.project_id AND t.project_id=core.project_id AND t.wave_code=core.wave_code)
"""

def get_sql_where(meta_json, rvalues):
  def _get_where_long(tabmeta, rvalues, sqlconj):
    # skip non-included tables and core table
    if rvalues.get('include_{}'.format(tabmeta['id'])) != "1" or tabmeta['idx'] == 0:
      return ""
    return sql_getdata_where_condition_long.format(conjunction=sqlconj, table_id=tabmeta['id'])
  if rvalues.get("options_join") == "all":
    return "TRUE"
  b    = "TRUE" if rvalues.get("options_join") == "intersect" else "FALSE"
  conj = "AND"  if rvalues.get("options_join") == "intersect" else "OR"
  cc = ""
  for tabmeta in meta_json:
    cc += _get_where_long(tabmeta, rvalues, conj)
  # skip empty WHERE (no data sets selected)
  if cc == "":
    return "TRUE"
  return sql_getdata_where_main.format(
    bool=textwrap.indent(b, ' ' * 2), 
    conjunction_conditions=textwrap.indent(cc, ' ' * 2)
  )

@app.route('/query', methods=['GET', 'POST'])
def web_query():
  from db import Db
  import json
  with Db().get().cursor() as cur:
    cur.execute(sql_getmeta);
    meta_json = cur.fetchall()[0].meta_json
    Db().get().close()
  #print(json.dumps(meta_json, indent=2, sort_keys=True, default=str))
  sql_selection = get_sql_selection(meta_json, flask.request.values)
  sql_join = get_sql_join(meta_json, flask.request.values)
  sql_where = get_sql_where(meta_json, flask.request.values)
  sql = sql_getdata_main.format(
    col_selection=textwrap.indent(sql_selection, ' ' * 2),
    joins=textwrap.indent(sql_join, ' ' * 2),
    where=textwrap.indent(sql_where, ' ' * 2),
  )
  print(sql)
  with Db().get().cursor() as cur:
    cur.execute(sql)
    rows = cur.fetchall()
    # header
    coldescr =  [ dict(name=x.name, typname=Db().typecode2str(x.type_code)) for x in cur.description ]
    columns = [col['name'] for col in coldescr]
    # data
    row_dicts = []
    for row in rows:
        row_dicts.append(dict(zip(columns, row)))
    Db().get().close()
  return flask.render_template('dbres.html', colnames=coldescr, qrows=row_dicts, gnu_r_str="", dlinfo="")


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
