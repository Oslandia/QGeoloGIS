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


class PlotConfig:

    def __init__(self, config):
        self.__config = config

    def is_visible(self):
        return self.__config.get("visible", True)

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


class LayerConfig:

    def __init__(self, config):
        self.__config = config

        self.__stratigraphy_plots = []
        self.__log_plots = []
        self.__timeseries = []

        for plot in self.__config.get("stratigraphy_config", []):
            self.__stratigraphy_plots.append(PlotConfig(plot))

        for plot in self.__config.get("log_measures", []):
            self.__log_plots.append(PlotConfig(plot))

        for timeserie in self.__config.get("timeseries", []):
            self.__timeseries.append(PlotConfig(timeserie))

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
