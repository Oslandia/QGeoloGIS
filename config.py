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
from qgis.core import QgsProject, QgsVectorLayer


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

def export_config(config_json, filename):
    """Exports the given project configuration to a filename.
    Layer IDs stored in the configuration are converted into triple (source, url, provider)

    Filters on layers or virtual fields  will then be lost during the translation

    Parameters
    ----------
    config_json: dict
      The configuration as a JSON object converted to a dict
    filename: str
      Name of the file where to export the configuration to
    """

    new_dict = {}

    # root layers at the beginning of the dict
    for root_layer_id, config in config_json.items():
        root_layer = QgsProject.instance().mapLayer(root_layer_id)
        if not root_layer:
            continue

        # replace "source" keys
        for subkey in ("stratigraphy_config", "log_measures", "timeseries"):
            for layer_cfg in config[subkey]:
                source_id = layer_cfg["source"]
                source = QgsProject.instance().mapLayer(source_id)
                if not source:
                    continue

                layer_cfg["source"] = {
                    "source": source.source(),
                    "name": source.name(),
                    "provider": source.providerType()
                }

        root_key = "{}#{}#{}".format(root_layer.source(), root_layer.name(), root_layer.providerType())
        new_dict[root_key] = dict(config)

    # write to the output file
    with open(filename, "w", encoding="utf-8") as fo:
        json.dump(new_dict, fo, ensure_ascii=False, indent=4)


def import_config(filename, overwrite_existing=False):
    """Import the configuration from a given filename
    
    Layers are created and added to the current project.

    Parameters
    ----------
    filename: str
      Name of the file where to import the configuration from
    overwrite_existing: bool
      Whether to try to overwrite existing layers that have
      the same data source definition
    """
    with open(filename, "r", encoding="utf-8") as fi:
        config_json = json.load(fi)

    new_config = {}

    def find_existing_layer_or_create(source, name, provider, do_overwrite):
        if do_overwrite:
            for layer_id, layer in QgsProject.instance().mapLayers().items():
                if layer.source() == source and layer.providerType() == provider:
                    layer.setName(name)
                    return layer
        # layer not found, create it then !
        layer = QgsVectorLayer(source, name, provider)
        QgsProject.instance().addMapLayer(layer)
        return layer

    # root layers at the beginning of the dict
    for root_layer_source, config in config_json.items():
        root_layer_source, root_layer_name, root_layer_provider = root_layer_source.split('#')
        root_layer = find_existing_layer_or_create(root_layer_source,
                                                   root_layer_name,
                                                   root_layer_provider,
                                                   overwrite_existing)

        for subkey in ("stratigraphy_config", "log_measures", "timeseries"):
            for layer_cfg in config[subkey]:
                source = layer_cfg["source"]
                layer = find_existing_layer_or_create(source["source"],
                                                      source["name"],
                                                      source["provider"],
                                                      overwrite_existing)
                layer_cfg["source"] = layer.id()

        # change the main dict key
        new_config[root_layer.id()] = dict(config)

    return json.dumps(new_config)

def remove_layer_from_config(config, layer_id):
    """Remove a layer reference from a configuration object

    Parameters
    ----------
    config: dict
      The main plot configuration. It is modified in place.
    layer_id: str
      The layer whom references are to remove from the config
    """
    for root_layer_id, sub_config in config.items():
        if layer_id == root_layer_id:
            # remove the dictionary entry
            del config
            return
        for subkey in ("stratigraphy_config", "log_measures", "timeseries"):
            to_del = []
            for idx, layer_cfg in enumerate(sub_config[subkey]):
                sub_layer_id = layer_cfg["source"]
                if layer_id == sub_layer_id:
                    to_del.append(idx)
            for idx in to_del:
                sub_config[subkey].pop(idx)
