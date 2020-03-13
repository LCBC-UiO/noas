# -*- coding: utf-8 -*-

import singleton
import flask

class Config(metaclass=singleton.Singleton):
  def __init__(self):
    pass
  def __getitem__(self, key):
      return flask.current_app.config[key]
