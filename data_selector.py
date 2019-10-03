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
from qgis.PyQt.QtWidgets import (QListWidget, QListWidgetItem, QHBoxLayout, QLabel, QComboBox,
                                 QPushButton)

from qgis.core import QgsProject, QgsFeatureRequest
from qgis.gui import QgsMessageBar

from .qgeologis.data_interface import FeatureData, LayerData


class DataSelector(QDialog):

    def __init__(self, viewer, feature_id, feature_name, config_list, config):
        QDialog.__init__(self)

        self.__viewer = viewer
        self.__feature_id = feature_id
        self.__feature_name = feature_name
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

        from_elsewhere_btn = QPushButton("Select another station")

        self.__title_label = QLabel()

        hbox2 = QHBoxLayout()
        hbox2.addWidget(self.__title_label)
        hbox2.addWidget(from_elsewhere_btn)

        vbox.addLayout(hbox2)
        vbox.addWidget(self.__list)
        vbox.addLayout(hbox)
        vbox.addWidget(btn)

        self.__list.itemSelectionChanged.connect(self.on_selection_changed)
        self.__sub_selection_combo.currentIndexChanged[str].connect(self.on_combo_changed)
        from_elsewhere_btn.clicked.connect(self.on_from_elsewhere_clicked)

        self.setLayout(vbox)
        self.setWindowTitle("Choose the data to add")
        self.resize(400, 200)

        self._populate_list()
        self.set_title(feature_name)

    def set_title(self, title):
        self.__title_label.setText("Station: {}".format(title))

    def _populate_list(self):
        self.__list.clear()
        for cfg in self.__config_list:
            if cfg["type"] in ("continuous", "instantaneous"):
                # check number of features for this station

                if cfg.get("feature_filter_type") == "unique_data_from_values":
                    # get unique filter values
                    cfg["filter_unique_values"] = sorted(list(set([f[cfg["feature_filter_column"]] for f in data_l.getFeatures(req)])))

            elif cfg["type"] == "image":
                if not self.__viewer.has_imagery_data(cfg, self.__feature_id):
                    continue

            item = QListWidgetItem(cfg["name"])
            item.setData(Qt.UserRole, cfg)
            self.__list.addItem(item)

    def accept(self):
        for item in self.__list.selectedItems():
            # now add the selected configuration
            cfg = item.data(Qt.UserRole)
            if cfg["type"] in ("continuous", "instantaneous"):
                layerid = cfg["source"]
                data_l = QgsProject.instance().mapLayers()[layerid]
                req = QgsFeatureRequest()
                filter_expr = "{}={}".format(cfg["feature_ref_column"], self.__feature_id)
                req.setFilterExpression(filter_expr)

                title = cfg["name"]

                if cfg["type"] == "instantaneous":
                    if "filter_value" in cfg:
                        filter_expr += " and {}='{}'".format(cfg["feature_filter_column"], cfg["filter_value"])
                        title = cfg["filter_value"]
                    else:
                        title = cfg["name"]

                    f = None
                    for f in data_l.getFeatures(req):
                        pass
                    if f is None:
                        return
                    uom = cfg["uom"] if "uom" in cfg else "@" + cfg["uom_column"]
                    data = LayerData(data_l, cfg["event_column"], cfg["value_column"], filter_expression=filter_expr, uom=uom)
                    uom = data.uom()

                if cfg["type"] == "continuous":
                    uom = cfg["uom"]
                    fids = [f.id() for f in data_l.getFeatures(req)]
                    data = FeatureData(data_l, cfg["values_column"], feature_ids=fids,
                                       x_start_fieldname=cfg["start_measure_column"],
                                       x_delta_fieldname=cfg["interval_column"])

                if hasattr(self.__viewer, "add_data_column"):
                    self.__viewer.add_data_column(data, title, uom, station_name = self.__feature_name)
                if hasattr(self.__viewer, "add_data_row"):
                    self.__viewer.add_data_row(data, title, uom, station_name = self.__feature_name)
            elif cfg["type"] == "image":
                self.__viewer.add_imagery_from_db(cfg, self.__feature_id)

        QDialog.accept(self)

    def on_selection_changed(self):
        self.__sub_selection_combo.clear()
        self.__sub_selection_combo.setEnabled(False)
        for item in self.__list.selectedItems():
            cfg = item.data(Qt.UserRole)
            if "filter_unique_values" in cfg:
                for v in cfg["filter_unique_values"]:
                    self.__sub_selection_combo.addItem(v)
            if "filter_value" in cfg:
                self.__sub_selection_combo.setCurrentIndex(self.__sub_selection_combo.findText(cfg["filter_value"]))
            self.__sub_selection_combo.setEnabled(True)
            return

    def on_combo_changed(self, text):
        for item in self.__list.selectedItems():
            cfg = item.data(Qt.UserRole)
            cfg["filter_value"] = text
            item.setData(Qt.UserRole, cfg)
            return

    def on_from_elsewhere_clicked(self):
        layer_config = get_layer_config()
        from qgis.utils import iface
        if iface.activeLayer() is None:
            iface.messageBar().pushMessage(u"Please select an active layer", QgsMessageBar.CRITICAL)
            return
        uri, provider = iface.activeLayer().source(), iface.activeLayer().dataProvider().name()
        if (uri, provider) not in layer_config:
            iface.messageBar().pushMessage(u"Unconfigured layer", QgsMessageBar.CRITICAL)
            return

        config = layer_config[(uri, provider)]
        iface.messageBar().pushMessage(u"Please select a feature on the active layer")
        self.__tool = FeatureSelectionTool(iface.mapCanvas(), iface.activeLayer())
        iface.mapCanvas().setMapTool(self.__tool)
        self.__tool.featureSelected.connect(self.on_other_station_selected)

        self.setModal(False)
        self.setWindowState(Qt.WindowMinimized)

    def on_other_station_selected(self, selected):
        self.__feature_id = selected[0].id()
        self._populate_list()
        self.__feature_name = selected[0][self.__config["name_column"]]
        self.set_title(self.__feature_name)
        self.setModal(True)
        self.setWindowState(Qt.WindowActive)
