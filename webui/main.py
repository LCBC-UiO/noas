
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

# route query builder

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
			select row_count(mt.category, mt.id)
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

#-------------------------------------------------------------------------------

# route query results

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
  def _get_sql_join_repeated(tabmeta, rvalues, sqls):
    if rvalues.get('include_' + tabmeta['id']) != "1" or tabmeta['idx'] == 0:
      return
    sqls.append("LEFT OUTER JOIN repeated_{table_id} {table_id} ON core.subject_id={table_id}.subject_id AND core.project_id={table_id}.project_id AND core.wave_code={table_id}.wave_code".format(table_id=tabmeta['id']))
  sqls = []
  for tabmeta in meta_json:
    if (tabmeta['category'] == "long"):
      _get_sql_join_long(tabmeta, rvalues, sqls)
    elif (tabmeta['category'] == "repeated"):
      _get_sql_join_repeated(tabmeta, rvalues, sqls)
  return "\n".join(sqls)

sql_getdata_where_main= """\
(
{bool}
{conjunction_conditions})
"""

sql_getdata_where_condition_long = """\
  {conjunction} core.subject_id IN (SELECT DISTINCT(subject_id) FROM long_{table_id} t WHERE t.subject_id=core.subject_id AND t.project_id=core.project_id AND t.wave_code=core.wave_code)
"""
sql_getdata_where_condition_repeated = """\
  {conjunction} core.subject_id IN (SELECT DISTINCT(subject_id) FROM repeated_{table_id} t WHERE t.subject_id=core.subject_id AND t.project_id=core.project_id AND t.wave_code=core.wave_code)
"""
"""

def get_sql_where(meta_json, rvalues):
  def _get_where_long(tabmeta, rvalues, sqlconj):
    # skip non-included tables and core table
    if rvalues.get('include_{}'.format(tabmeta['id'])) != "1" or tabmeta['idx'] == 0:
      return ""
    if tabmeta['category'] == "long":
      return sql_getdata_where_condition_long.format(conjunction=sqlconj, table_id=tabmeta['id'])
    if tabmeta['category'] == "repeated":
      return sql_getdata_where_condition_repeated.format(conjunction=sqlconj, table_id=tabmeta['id'])
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

def generate_gnu_r_str(request_values):
  # generate R code to import query data
  from config import Config
  port = Config()['WEBSERVERPORT']
  host = Config()['WEBSERVERHOSTNAME']
  gnu_r_str =  '# requires the "httr" library!\n'
  gnu_r_str += 'if (! "httr" %in% rownames(installed.packages())) {\n'
  gnu_r_str += '  write("please install the \\"httr\\" library", "")\n'
  gnu_r_str += '} else {\n'
  gnu_r_str += "  # define query parameters\n"
  gnu_r_str += "  body <- list(NULL\n"
  for k,v in request_values.items():
    gnu_r_str += "    ,{} = \"{}\"\n".format(k,v)
  gnu_r_str += "    ,{} = \"{}\"\n".format("options_format", "tsv")
  gnu_r_str +=  "  )\n"
  gnu_r_str += "  # download\n"
  gnu_r_str += '  rx <- httr::POST("http://{}:{}/query",body=body)\n'.format(host, port)
  gnu_r_str += '  # convert to table\n'
  gnu_r_str += '  con <- textConnection(httr::content(rx, "text"))\n'
  gnu_r_str += '  d_noas <- read.table(con, header=T, sep="\\t", na.strings="None")\n'
  gnu_r_str += '  write("your data is available in \\"d_noas\\"", "")\n'
  gnu_r_str += '  close(con)\n'
  gnu_r_str += '}\n'
  gnu_r_str += "\n"
  gnu_r_str += "\n"
  return gnu_r_str

@app.route('/query', methods=['GET', 'POST'])
def web_query():
  from db import Db
  import datetime
  import json
  # fetch metadata and build query
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
  # get results
  typecode2str = Db().get_typecode2str()
  with Db().get().cursor() as cur:
    cur.execute(sql)
    rows = cur.fetchall()
    # header
    coldescr =  [ dict(name=x.name, typname=typecode2str[str(x.type_code)]) for x in cur.description ]
    columns = [col['name'] for col in coldescr]
    # data
    row_dicts = []
    for row in rows:
        row_dict = dict(zip(columns, row))
        # convert to str
        # (fixes date format being "Tue, 15 Jun 1954 00:00:00 GMT" instead of 1954-06-15)
        for k,v in row_dict.items():
          if type(v) is datetime.date:
            row_dict[k] = str(v)
        row_dicts.append(row_dict)
    Db().get().close()
  # TSV output?
  if flask.request.values.get('options_format', None) == "tsv":
      # convert to Tsv
      q_tsv = '\t'.join(str(x.name) for x in cur.description)
      q_tsv += '\n'
      for row in row_dicts:
        print(row)
        q_tsv += '\t'.join(str(v) for k,v in row.items())
        q_tsv += '\n'
      return flask.Response(q_tsv, mimetype="text/plain")
  # generate download info
  dlinfo = dict()
  def _get_query_md5(rqvals):
    from hashlib import md5
    m = md5()
    qstr=""
    for k,v in rqvals.items():
      qstr += "{} = \"{}\"\n".format(k,v)
    m.update(qstr.encode('utf-8'))
    return m.hexdigest()[0:7]
  dlinfo['md5'] = _get_query_md5(flask.request.values) # todo: print belonging query?
  import datetime
  dlinfo['date'] = datetime.datetime.now().strftime("%Y-%m-%d")
  dlinfo['time'] = datetime.datetime.now().strftime("%H.%M")
  gnu_r_str = generate_gnu_r_str(flask.request.values)
  return flask.render_template('dbres.html', colnames=coldescr, qrows=row_dicts, gnu_r_str=gnu_r_str, sql_str=sql, dlinfo=dlinfo)


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
