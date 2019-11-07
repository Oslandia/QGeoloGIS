# coding=UTF-8

import os

from PyQt5.QtWidgets import QDialog
from PyQt5 import uic


class ConfigurePlotDialog(QDialog):

    def __init__(self, layer, parent):
        super().__init__(parent)

        uic.loadUi(os.path.join(os.path.dirname(__file__),
                                'configure_plot_dialog.ui'), self)

        self._message.setText(self.tr("There is not plot configured for layer '{}'."
                                      "\nDo you want to configure one ?".format(layer.name())))
        self.setWindowTitle(self.tr("Configure a plot layer '{}'".format(layer.name())))

        self._name.setText(layer.name())

        for column_field in [self._id_column, self._name_column]:
            column_field.addItems(layer.fields().names())

    def config(self):
        return {
            "layer_name": self._name.text(),
            "id_column": self._id_column.currentText(),
            "name_column": self._name_column.currentText(),
            "stratigraphy_config": [],
            "log_measures": [],
            "imagery_data": []
        }
