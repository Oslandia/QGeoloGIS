# -*- coding: utf-8 -*-
#
#   Copyright (C) 2019 Oslandia <infos@oslandia.com>
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

from qgis.PyQt.QtWidgets import QSplitter, QAction
from qgis.PyQt.QtGui import QIcon
from qgis.PyQt.QtCore import Qt, QSize
from qgis.core import QgsProject, QgsFeatureRequest

from .config_create_dialog import ConfigCreateDialog
from .qgeologis.log_view import WellLogView
from .qgeologis.timeseries_view import TimeSeriesView
from .qgeologis.data_interface import LayerData, FeatureData
from .data_selector import DataSelector
from .config import LayerConfig, PlotConfig


def load_plots(feature, config, add_function, config_list):

    feature_id = feature[config["id_column"]]
    feature_name = feature[config["name_column"]]

    for c in config_list:
        cfg = PlotConfig(c)

        if cfg.get("feature_filter_type") == "unique_data_from_values":
            # don't load it now, we need to filter
            # we will load it from data selector
            continue

        if cfg["type"] in ("continuous", "instantaneous"):
            layerid = cfg.get_layerid()
            data_l = QgsProject.instance().mapLayers()[layerid]
            filter_expr = "{}='{}'".format(cfg["feature_ref_column"],
                                           feature_id)

            title = cfg["name"]

            if cfg["type"] == "instantaneous":
                uom = cfg.get_uom()
                data = LayerData(data_l, cfg["event_column"], cfg["value_column"],
                                 filter_expression=filter_expr, uom=uom)
                uom = data.uom()

            if cfg["type"] == "continuous":
                req = QgsFeatureRequest()
                req.setFilterExpression(filter_expr)
                uom = cfg.get_uom()
                fids = [f.id() for f in data_l.getFeatures(req)]
                data = FeatureData(data_l, cfg["values_column"], feature_ids=fids,
                                   x_start_fieldname=cfg["start_measure_column"],
                                   x_delta_fieldname=cfg["interval_column"])

            add_function(data, title, uom, station_name=feature_name)


class WellLogViewWrapper(WellLogView):
    def __init__(self, config, iface):
        WellLogView.__init__(self)
        self.__config = config
        self.__iface = iface
        self.__features = []

        image_dir = os.path.join(os.path.dirname(__file__), "qgeologis", "img")
        self.__action_add_configuration = QAction(QIcon(os.path.join(image_dir, "new_plot.svg")),
                                                  "Add a new column configuration", self.toolbar)
        self.__action_add_configuration.triggered.connect(self.on_add_configuration)
        self.toolbar.addAction(self.__action_add_configuration)

    def on_add_configuration(self):
        dialog = ConfigCreateDialog(self)
        if dialog.exec_():
            config_type, plot_config = dialog.config()
            self.__config.add_plot_config(config_type, plot_config)

        self.update_view()

    def set_features(self, features):
        self.__features = features
        self.update_view()

    def update_view(self):

        self.clear_data_columns()

        for feature in self.__features:
            self.__load_feature(feature)

    def __load_feature(self, feature):

        # load stratigraphy
        for c in self.__config.get_stratigraphy_plots():
            cfg = PlotConfig(c)

            layer = QgsProject.instance().mapLayers()[cfg.get_layerid()]
            f = "{}='{}'".format(cfg["feature_ref_column"],
                                 feature[self.__config["id_column"]])

            self.add_stratigraphy(
                layer, f, (cfg["depth_from_column"],
                           cfg["depth_to_column"],
                           cfg["formation_code_column"],
                           cfg["rock_code_column"],
                           cfg.get("formation_description_column"),
                           cfg.get("rock_description_column")),
                cfg.get("name", self.tr("Stratigraphy")),
                cfg.get_style_file())

        # load log measures
        load_plots(feature, self.__config, self.add_data_column,
                   self.__config.get_log_plots())

        # load imagery
        feature_id = feature[self.__config["id_column"]]
        for cfg in self.__config["imagery_data"]:
            self.add_imagery_from_db(cfg, feature_id)

    def on_add_column(self):

        if not self.__features:
            self.__iface.messageBar().pushWarning(
                "QGeoloGIS",
                u"Impossible to add plot without selecting a feature")
            return

        sources = list(self.__config["log_measures"])
        sources += [dict(list(d.items()) + [("type", "image")])
                    for d in self.__config["imagery_data"]]
        s = DataSelector(self, self.__features, sources, self.__config)
        s.exec_()

    def add_imagery_from_db(self, cfg, feature_id):
        if cfg.get("provider", "postgres_bytea") != "postgres_bytea":
            raise "Access method not implemented !"

        import psycopg2
        import tempfile
        conn = psycopg2.connect(cfg["source"])
        cur = conn.cursor()
        cur.execute("select {depth_from}, {depth_to}, {data}, {format} from {schema}.{table} where {ref_column}=%s"\
                    .format(depth_from=cfg.get("depth_from_column", "depth_from"),
                            depth_to=cfg.get("depth_to_column", "depth_to"),
                            data=cfg.get("image_data_column", "image_data"),
                            format=cfg.get("image_data_column", "image_format"),
                            schema=cfg["schema"],
                            table=cfg["table"],
                            ref_column=cfg["feature_ref_column"]),
                    (feature_id,))
        r = cur.fetchone()
        if r is None:
            return

        depth_from, depth_to = float(r[0]), float(r[1])
        image_data = r[2]
        image_format = r[3]
        f = tempfile.NamedTemporaryFile(mode="wb", suffix=image_format.lower())
        image_filename = f.name
        f.close()
        with open(image_filename, "wb") as fo:
            fo.write(image_data)
        self.add_imagery(image_filename, cfg["name"], depth_from, depth_to)


class TimeSeriesWrapper(TimeSeriesView):
    def __init__(self, config):
        TimeSeriesView.__init__(self)
        self.__config = config
        self.__features = []

    def set_features(self, features):
        self.__features = features
        self.update_view()

    def update_view(self):

        self.clear_data_rows()

        for feature in self.__features:
            load_plots(feature, self.__config, self.add_data_row,
                       self.__config.get_timeseries())

    def on_add_row(self):
        s = DataSelector(self, self.__features,  self.__config.get_timeseries(),  self.__config)
        s.exec_()


class MainDialog(QSplitter):

    def __init__(self, config, layer, iface):

        super().__init__(Qt.Vertical)
        self.setWindowTitle("{} plot viewer".format(layer.name()))
        self.setMinimumSize(QSize(600, 400))

        self.__layer = layer
        self.__config = LayerConfig(config, layer.id())
        self.__iface = iface

        self.__well_log_view = WellLogViewWrapper(self.__config, self.__iface)
        self.__time_series_view = TimeSeriesWrapper(self.__config)

        self.addWidget(self.__well_log_view)
        self.addWidget(self.__time_series_view)

        self.__layer.selectionChanged.connect(self.__update_selected_features)

        self.__update_selected_features()

    def __update_selected_features(self):

        self.__well_log_view.setVisible(
            self.__config.get("stratigraphy_config") is not None
            or self.__config.get("log_measures") is not None)

        self.__time_series_view.setVisible(
            self.__config.get("timeseries") is not None)

        if not self.__layer.selectedFeatureCount():
            return

        self.__well_log_view.set_features(self.__layer.selectedFeatures())
        self.__time_series_view.set_features(self.__layer.selectedFeatures())
