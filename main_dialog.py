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

from PyQt5.QtCore import Qt
from qgis.PyQt.QtWidgets import (
    QDialog, QAction, QVBoxLayout, QWidget,
    QApplication
)
from qgis.PyQt.QtGui import QIcon
from qgis.PyQt.QtCore import QSize, pyqtSignal
from qgis.core import QgsProject, QgsFeatureRequest

from .config_create_dialog import ConfigCreateDialog
from .qgeologis.log_view import WellLogView
from .qgeologis.timeseries_view import TimeSeriesView
from .qgeologis.data_interface import LayerData, IntervalData
from .data_selector import DataSelector
from .config import LayerConfig, PlotConfig


def load_plots(obj, feature, config, config_list):

    feature_id = feature[config["id_column"]]
    feature_name = feature[config["name_column"]]

    min_x = []
    max_x = []
    for cfg in config_list:

        print(cfg)

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
                # FIXME for next release: set default value to "remove"
                nodata = cfg.get("nodata", 0.0)
                if nodata == "remove":
                    nodata = None
                data = LayerData(
                    data_l,
                    cfg["event_column"],
                    cfg["value_column"],
                    filter_expression=filter_expr,
                    uom=uom,
                    nodata_value=nodata
                )
                uom = data.uom()

                if data.get_x_min() is not None:
                    min_x.append(data.get_x_min())
                    max_x.append(data.get_x_max())
                    # FIXME
                    if hasattr(obj, "add_data_row"):
                        obj.add_data_row(data, title, uom, station_name=feature_name, config=cfg)
                    elif hasattr(obj, "add_data_column"):
                        obj.add_data_column(data, title, uom, station_name=feature_name, config=cfg)

            elif cfg["type"] == "continuous":
                obj.add_histogram(
                    data_l,
                    filter_expr,
                    {
                        f : cfg[f] for f in (
                            "min_event_column",
                            "max_event_column",
                            "value_column"
                        )
                    },
                    title,
                    config=cfg,
                    station_name=feature_name
                )

    if not min_x:
        return None, None
    else:
        return (min(min_x), max(max_x))


class WellLogViewWrapper(WellLogView):
    def __init__(self, config, iface):
        WellLogView.__init__(self)
        self.__iface = iface
        self.__features = []
        self.__config = config

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
        for cfg in self.__config.get_stratigraphy_plots():

            layer = QgsProject.instance().mapLayers()[cfg.get_layerid()]
            f = "{}='{}'".format(cfg["feature_ref_column"],
                                 feature[self.__config["id_column"]])

            self.add_stratigraphy(
                layer, f, {
                    "depth_from_column": cfg["depth_from_column"],
                    "depth_to_column": cfg["depth_to_column"],
                    "formation_code_column": cfg["formation_code_column"],
                    "rock_code_column": cfg["rock_code_column"],
                    "formation_description_column": cfg.get("formation_description_column"),
                    "rock_description_column": cfg.get("rock_description_column")
                },
                cfg.get("name", self.tr("Stratigraphy")),
                cfg.get_style_file(),
                config=cfg
            )

        # load log measures
        load_plots(self, feature, self.__config,
                   self.__config.get_log_plots())

        # load imagery
        feature_id = feature[self.__config["id_column"]]
        for cfg in self.__config["imagery_data"]:
            self.add_imagery_from_db(cfg, feature_id)

    def on_add_column(self):

        if not self.__features and self.__iface:
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

        min_x = []
        max_x = []
        for feature in self.__features:
            fmin_x, fmax_x = load_plots(self, feature, self.__config,
                                        self.__config.get_timeseries())
            if fmin_x:
                min_x.append(fmin_x)
                max_x.append(fmax_x)

        if min_x:
            self.set_x_range(min(min_x), max(max_x))

    def on_add_row(self):
        s = DataSelector(self, self.__features,  self.__config.get_timeseries(),  self.__config)
        s.exec_()


class MainDialog(QWidget):

    def __init__(self, parent, plot_type, config, layer, iface):
        """Create a plot dialog that updates when a layer selection updates.

        Parameters
        ----------
        parent: QObject
          Qt parent object
        plot_type: str
          Type of plot, either "logs" or "timeseries"
        config: dict
          Layer configuration
        layer: QgsVectorLayer
          Main layer
        iface: QgisInterface
          QGIS interface class
        """

        super().__init__(parent)
        self.setWindowTitle("{} {}".format(layer.name(), plot_type))
        self.setMinimumSize(QSize(600, 400))

        self.__layer = layer
        self.__config = LayerConfig(config, layer.id())
        self.__iface = iface

        if plot_type == "logs":
            self.__view = WellLogViewWrapper(self.__config, self.__iface)
        elif plot_type == "timeseries":
            self.__view = TimeSeriesWrapper(self.__config)
        else:
            raise RuntimeError("Invalid plot_type {}".format(plot_type))
        self.__view.styles_updated.connect(self.on_styles_updated)

        layout = QVBoxLayout()
        layout.setContentsMargins(0, 0, 0, 0)
        layout.addWidget(self.__view)
        self.setLayout(layout)

        self.__layer.selectionChanged.connect(self.__update_selected_features)

        self.__update_selected_features()

    def __update_selected_features(self):

        if not self.__layer.selectedFeatureCount():
            return

        QApplication.setOverrideCursor(Qt.WaitCursor)
        self.__view.set_features(self.__layer.selectedFeatures())
        QApplication.restoreOverrideCursor()

    def on_styles_updated(self):
        styles = self.__view.styles()

        for cfg in (self.__config.get_vertical_plots() + self.__config.get_timeseries()):
            for layer_id, (style, renderer_type) in styles.items():
                if cfg.get("source") == layer_id:
                    cfg.set_symbology(style, renderer_type)
                    break

