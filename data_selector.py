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

from qgis.PyQt.QtCore import Qt
from qgis.PyQt.QtWidgets import QDialog, QVBoxLayout, QDialogButtonBox, QAbstractItemView
from qgis.PyQt.QtWidgets import (QListWidget, QListWidgetItem, QHBoxLayout, QLabel, QComboBox)

from qgis.core import QgsProject, QgsFeatureRequest

from .qgeologis.data_interface import FeatureData, LayerData


class DataSelector(QDialog):

    def __init__(self, viewer, features, config_list, config):
        QDialog.__init__(self)

        self.__viewer = viewer
        self.__features = features
        self.__config_list = config_list
        self.__config = config
        vbox = QVBoxLayout()

        btn = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        btn.accepted.connect(self.accept)
        btn.rejected.connect(self.reject)

        self.__list = QListWidget()
        self.__list.setSelectionMode(QAbstractItemView.ExtendedSelection)

        hbox = QHBoxLayout()
        lbl = QLabel("Sub selection")
        self.__sub_selection_combo = QComboBox()
        self.__sub_selection_combo.setEnabled(False)
        hbox.addWidget(lbl)
        hbox.addWidget(self.__sub_selection_combo)

        self.__title_label = QLabel()

        hbox2 = QHBoxLayout()
        hbox2.addWidget(self.__title_label)

        vbox.addLayout(hbox2)
        vbox.addWidget(self.__list)
        vbox.addLayout(hbox)
        vbox.addWidget(btn)

        self.__list.itemSelectionChanged.connect(self.on_selection_changed)
        self.__sub_selection_combo.currentIndexChanged[str].connect(self.on_combo_changed)

        self.setLayout(vbox)
        self.setWindowTitle("Choose the data to add")
        self.resize(400, 200)

        self._populate_list()
        self.set_title(",".join([feature[self.__config["name_column"]]
                                 for feature in self.__features]))

    def set_title(self, title):
        self.__title_label.setText("Station(s): {}".format(title))

    def _populate_list(self):
        self.__list.clear()
        for cfg in self.__config_list:
            if cfg["type"] in ("continuous", "instantaneous"):
                # check number of features for this station

                if cfg.get("feature_filter_type") == "unique_data_from_values":
                    # get unique filter values

                    layerid = cfg["source"]
                    data_l = QgsProject.instance().mapLayers()[layerid]
                    values = set()
                    for feature in self.__features:
                        feature_id = feature[self.__config["id_column"]]
                        req = QgsFeatureRequest()
                        req.setFilterExpression("{}={}".format(cfg["feature_ref_column"],
                                                               feature_id))
                        values.update([f[cfg["feature_filter_column"]]
                                       for f in data_l.getFeatures(req)])

                        cfg.set_filter_unique_values(sorted(list(values)))

            item = QListWidgetItem(cfg["name"])
            item.setData(Qt.UserRole, cfg)
            self.__list.addItem(item)

    def accept(self):

        for feature in self.__features:
            self.__load_feature(feature)

    def __load_feature(self, feature):

        feature_id = feature[self.__config["id_column"]]
        feature_name = feature[self.__config["name_column"]]
        for item in self.__list.selectedItems():
            # now add the selected configuration
            cfg = item.data(Qt.UserRole)
            if cfg["type"] in ("continuous", "instantaneous"):
                layerid = cfg["source"]
                data_l = QgsProject.instance().mapLayers()[layerid]
                req = QgsFeatureRequest()
                filter_expr = "{}={}".format(cfg["feature_ref_column"], feature_id)
                req.setFilterExpression(filter_expr)

                title = cfg["name"]

                if cfg["type"] == "instantaneous":
                    if cfg.get_filter_value():
                        filter_expr += " and {}='{}'".format(cfg["feature_filter_column"],
                                                             cfg.get_filter_value())

                        print("filter_expr={}".format(filter_expr))
                        title = cfg.get_filter_value()
                    else:
                        title = cfg["name"]

                    f = None
                    for f in data_l.getFeatures(req):
                        pass
                    if f is None:
                        return
                    uom = cfg.get_uom()
                    data = LayerData(data_l, cfg["event_column"], cfg["value_column"],
                                     filter_expression=filter_expr, uom=uom)
                    uom = data.uom()

                if cfg["type"] == "continuous":
                    uom = cfg["uom"]
                    fids = [f.id() for f in data_l.getFeatures(req)]
                    data = FeatureData(data_l, cfg["values_column"], feature_ids=fids,
                                       x_start_fieldname=cfg["start_measure_column"],
                                       x_delta_fieldname=cfg["interval_column"])

                if hasattr(self.__viewer, "add_data_column"):
                    self.__viewer.add_data_column(data, title, uom,
                                                  station_name=feature_name)
                if hasattr(self.__viewer, "add_data_row"):
                    self.__viewer.add_data_row(data, title, uom, station_name=feature_name)
            elif cfg["type"] == "image":
                self.__viewer.add_imagery_from_db(cfg, feature_id)

        QDialog.accept(self)

    def on_selection_changed(self):
        self.__sub_selection_combo.clear()
        self.__sub_selection_combo.setEnabled(False)
        for item in self.__list.selectedItems():
            cfg = item.data(Qt.UserRole)
            for v in cfg.get_filter_unique_values():
                self.__sub_selection_combo.addItem(v)
            if cfg.get_filter_value():
                self.__sub_selection_combo.setCurrentIndex(
                    self.__sub_selection_combo.findText(cfg.get_filter_value()))
            self.__sub_selection_combo.setEnabled(True)
            return

    def on_combo_changed(self, text):
        for item in self.__list.selectedItems():
            cfg = item.data(Qt.UserRole)
            cfg.set_filter_value(text)
            item.setData(Qt.UserRole, cfg)
            return
