import singleton
import psycopg2
from psycopg2.extras import NamedTupleCursor


class Db(metaclass=singleton.Singleton):
  def __init__(self):
    self._db = None
    self._typecode2str = None

  def get(self):
    if self._db is None or self._db.closed:
      from config import Config
      conn_string = "host='{}' port={} dbname='{}' user='{}'".format(
        Config()['DBHOST'],
        Config()['DBPORT'],
        Config()['DBNAME'],
        Config()['DBUSER'],
      )
      print("connecting: " + conn_string)
      self._db = psycopg2.connect(conn_string, cursor_factory=NamedTupleCursor)
    return self._db
  
  def exec_file(self, fn):
    with open(fn, mode='r') as f:
      data=f.read()
      print(data)
      self.get().cursor().execute(data)
      self.get().commit()
      self.get().close()

  def has_table(self, table_id):
    with self.get().cursor() as cur:
      cur.execute("SELECT exists (SELECT relname FROM pg_class WHERE relname = '{}')".format(table_id))
      r = cur.fetchall()[0].exists
      self.get().close()

  # map postgresql type_code to string 
  # (see https://www.postgresql.org/docs/current/static/catalog-pg-type.html)
  def typecode2str(self, type_code):
    # only fetch dict once
    if self._typecode2str is None:
      with self.get().cursor() as cur:
        sql = "select json_object_agg(typelem, typname) as tc2str_json from pg_type where typelem > 0 and typarray = 0"
        cur.execute(sql)
        self._typecode2str = cur.fetchall()[0].tc2str_json
        self.get().close()
    return self._typecode2str[str(type_code)]
  

