#!/usr/bin/env python
# -*- coding: utf-8 -*-

from PyQt4.QtCore import pyqtSignal, QObject
from qgis.core import QgsFeatureRequest


class DataInterface(QObject):

    data_modified = pyqtSignal()

    def __init__(self):
        QObject.__init__(self)

    def get_x_values(self):
        raise("DataInterface is an abstract class, get_x_values() "
              "must be defined")

    def get_y_values(self):
        raise("DataInterface is an abstract class, get_y_values() "
              "must be defined")

    # keep here just for compatibility but it should'nt exist
    # plot_item doesn't need layer object
    def get_layer(self):
        raise("DataInterface is an abstract class, get_layer() "
              "must be defined")


class LayerData(DataInterface):

    def __init__(self, layer, x_fieldname, y_fieldname):

        DataInterface.__init__(self)

        self.__y_fieldname = y_fieldname
        self.__x_fieldname = x_fieldname
        self.__layer = layer
        self.__y_values = None
        self.__x_values = None

        layer.attributeValueChanged.connect(self.__build_data)
        layer.featureAdded.connect(self.__build_data)
        layer.featureDeleted.connect(self.__build_data)

        self.__build_data()

    def get_y_values(self):
        return self.__y_values

    def get_layer(self):
        return self.__layer

    def get_x_values(self):
        return self.__x_values

    def __build_data(self):

        self.__y_values = [f[self.__y_fieldname]
                           for f in self.__layer.getFeatures()]
        self.__x_values = [f[self.__x_fieldname]
                           for f in self.__layer.getFeatures()]

        self.data_modified.emit()


class FeatureData(DataInterface):

    def __init__(self, layer, y_fieldname, x_values, feature_id=0):

        DataInterface.__init__(self)

        self.__y_fieldname = y_fieldname
        self.__layer = layer
        self.__x_values = x_values
        self.__feature_id = feature_id

        # TODO connect on feature modification

        self.__build_data()

    def get_y_values(self):
        return self.__y_values

    def get_layer(self):
        return self.__layer

    def get_x_values(self):
        return self.__x_values

    def __build_data(self):

        req = QgsFeatureRequest()
        req.setFilterExpression("$id={}".format(self.__feature_id))
        f = next(self.__layer.getFeatures())

        if not f:
            return

        self.__y_values = [float(value)
                           for value in f[self.__y_fieldname].split(",")]

        self.data_modified.emit()
