#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
#   Copyright (C) 2018 Oslandia <infos@oslandia.com>
#
#   This file is a piece of free software; you can redistribute it and/or
#   modify it under the terms of the GNU Library General Public
#   License as published by the Free Software Foundation; either
#   version 2 of the License, or (at your option) any later version.
#
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   Library General Public License for more details.
#   You should have received a copy of the GNU Library General Public
#   License along with this library; if not, see <http://www.gnu.org/licenses/>.
#

import os
import json
from qgis.core import QgsProject


class PlotConfig:

    def __init__(self, config):
        self.__config = dict(config)
        self.__filter_value = None
        self.__filter_unique_values = []

    def get_layerid(self):
        return self.__config["source"]

    def get_uom(self):
        if self.__config["type"] == "instantaneous":
            return (self.__config["uom"] if "uom" in self.__config
                    else "@" + self.__config["uom_column"])
        else:
            return self.__config["uom"]

    def get_style_file(self):
        style = self.__config.get("style")
        return os.path.join(os.path.dirname(__file__), 'qgeologis/styles',
                            style if style else "stratigraphy_style.xml")

    def get(self, key, default=None):
        return self.__config.get(key, default)

    def __getitem__(self, key):
        return self.__config[key]

    # TODO: filter_value and filter_unique_values setter and getter
    # are only helper method and should not be part of the configuration
    def set_filter_value(self, value):
        self.__filter_value = value

    def set_filter_unique_values(self, values):
        self.__filter_unique_values = values

    def get_filter_value(self):
        return self.__filter_value

    def get_filter_unique_values(self):
        return self.__filter_unique_values

    def get_dict(self):
        return self.__config


class LayerConfig:

    def __init__(self, config, layer_id):
        self.__global_config = config
        self.__config = config.get(layer_id)

        self.__stratigraphy_plots = [p for p in self.__config.get("stratigraphy_config", [])]
        self.__log_plots = [p for p in self.__config.get("log_measures", [])]
        self.__timeseries = [p for p in self.__config.get("timeseries", [])]

    def get(self, key, default=None):
        return self.__config.get(key, default)

    def __getitem__(self, key):
        return self.__config[key]

    def get_stratigraphy_plots(self):
        return self.__stratigraphy_plots

    def get_log_plots(self):
        return self.__log_plots

    def get_timeseries(self):
        return self.__timeseries

    def get_vertical_plots(self):
        return self.__stratigraphy_plots + self.__log_plots

    def add_plot_config(self, config_type, plot_config):
        plots = (self.__stratigraphy_plots if config_type == "stratigraphy_config" else
                 self.__log_plots if config_type == "log_measures" else
                 self.__timeseries if config_type == "timeseries" else None)

        plots.append(plot_config.get_dict())

        if config_type not in self.__config:
            self.__config[config_type] = []

        self.__config[config_type].append(plot_config.get_dict())
        self.config_modified()

    def config_modified(self):
        json_config = json.dumps(self.__global_config)
        QgsProject.instance().writeEntry("QGeoloGIS", "config", json_config)
