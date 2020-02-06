# coding=UTF-8

import os

from PyQt5.QtWidgets import QDialog
from PyQt5 import uic

from qgis.core import QgsProject, QgsMapLayer

from .config import PlotConfig


class ConfigCreateDialog(QDialog):

    def __init__(self, parent):
        super().__init__(parent)

        uic.loadUi(os.path.join(os.path.dirname(__file__),
                                'config_create_dialog.ui'), self)

        self._type.currentIndexChanged.connect(self.__on_type_changed)

        self._source.currentIndexChanged.connect(self._on_source_changed)
        for layer in QgsProject.instance().mapLayers().values():
            if layer.type() == QgsMapLayer.VectorLayer:
                self._source.addItem(layer.name(), layer)

    def __on_type_changed(self, index):
        self._type_widgets.setCurrentIndex(index)

    def _on_source_changed(self, index):

        layer = self._source.itemData(index)

        for column_field in [self._feature_ref_column, self._depth_from_column,
                             self._depth_to_column, self._start_measure_column,
                             self._interval_column, self._value_continuous_column,
                             self._event_column, self._value_instantaneous_column]:
            column_field.clear()
            column_field.addItems(layer.fields().names())

        for column_field in [self._formation_code_column, self._rock_code_column,
                             self._formation_description_column, self._rock_description_column]:
            column_field.clear()
            column_field.addItems([''] + layer.fields().names())

    def config(self):

        # Stratigraphy
        config = None
        if self._type.currentIndex() == 0:
            config = {
                "depth_from_column": self._depth_from_column.currentText(),
                "depth_to_column": self._depth_to_column.currentText(),
                "formation_code_column": self._formation_code_column.currentText() or None,
                "rock_code_column": self._rock_code_column.currentText() or None,
                "formation_description_column": self._formation_description_column.currentText() or None,
                "rock_description_column": self._rock_description_column.currentText() or None,
                "style": "formation_style.xml"
                }

        # log measure continuous
        elif self._type.currentIndex() == 1:
            config = {
                "start_measure_column": self._start_measure_column.currentText(),
                "interval_column": self._interval_column.currentText(),
                "values_column": self._value_continuous_column.currentText(),
                "uom":  self._uom_continuous.text(),
                "type": "continuous",
                "min": self._continuous_min.text() if self._continuous_min.isEnabled() else None,
                "max": self._continuous_max.text() if self._continuous_max.isEnabled() else None
                }

        # log measure instantaneous
        elif self._type.currentIndex() == 2:
            config = {
                "start_measure_column": self._start_measure_column.currentText(),
                "event_column": self._event_column.currentText(),
                "value_column": self._value_instantaneous_column.currentText(),
                "uom":  self._uom_instantaneous.text(),
                "type": "instantaneous",
                "min": self._instantaneous_min.text() if self._instantaneous_min.isEnabled() else None,
                "max": self._instantaneous_max.text() if self._instantaneous_max.isEnabled() else None
                }

        config["source"] = self._source.itemData(self._source.currentIndex()).id()
        config["feature_ref_column"] = self._feature_ref_column.currentText()
        config["name"] = self._name.text()

        return (["stratigraphy_config", "log_measures", "log_measures"][self._type.currentIndex()],
                PlotConfig(config))
