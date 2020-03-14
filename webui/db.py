import singleton
import psycopg2
from psycopg2.extras import NamedTupleCursor


class Db(metaclass=singleton.Singleton):
  def __init__(self):
    self._db = None

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

  def has_table(self, table_id):
    with Db().get().cursor() as cur:
      cur.execute("SELECT exists (SELECT relname FROM pg_class WHERE relname = '{}')".format(table_id))
      return cur.fetchall()[0].exists

