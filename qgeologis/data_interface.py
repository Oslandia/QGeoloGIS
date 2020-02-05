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

from qgis.PyQt.QtCore import pyqtSignal, QObject, QVariant
from qgis.core import QgsFeatureRequest

import numpy as np

class DataInterface(QObject):
    """DataInterface is a class that abstracts how a bunch of (X,Y) data are represented"""

    data_modified = pyqtSignal()

    def __init__(self):
        QObject.__init__(self)

    def get_x_values(self):
        raise("DataInterface is an abstract class, get_x_values() "
              "must be defined")

    def get_y_values(self):
        raise("DataInterface is an abstract class, get_y_values() "
              "must be defined")

    def get_x_min(self):
        raise("DataInterface is an abstract class, get_x_min() "
              "must be defined")

    def get_x_max(self):
        raise("DataInterface is an abstract class, get_x_min() "
              "must be defined")

    def get_y_min(self):
        raise("DataInterface is an abstract class, get_y_min() "
              "must be defined")

    def get_y_max(self):
        raise("DataInterface is an abstract class, get_y_max() "
              "must be defined")

    # keep here just for compatibility but it should'nt exist
    # plot_item doesn't need layer object
    # FIXME a layer seems to be needed for symbology.
    # TODO: try to make it internal to plotter UI
    def get_layer(self):
        raise("DataInterface is an abstract class, get_layer() "
              "must be defined")



class LayerData(DataInterface):
    """LayerData model data that are spanned on multiple features (resp. rows) on a layer (resp. table).

    This means each feature (resp. row) of a layer (resp. table) has one (X,Y) pair.
    They will be sorted on X before being displayed.
    """

    def __init__(self, layer, x_fieldname, y_fieldname, filter_expression = None, nodata_value = 0.0, uom = None):

        DataInterface.__init__(self)

        self.__y_fieldname = y_fieldname
        self.__x_fieldname = x_fieldname
        self.__layer = layer
        self.__y_values = None
        self.__x_values = None
        self.__x_min = None
        self.__x_max = None
        self.__y_min = None
        self.__y_max = None
        self.__filter_expression = filter_expression
        self.__nodata_value = nodata_value
        self.__uom = uom

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

    def get_x_min(self):
        return self.__x_min

    def get_x_max(self):
        return self.__x_max

    def get_y_min(self):
        return self.__y_min

    def get_y_max(self):
        return self.__y_max

    def uom(self):
        return self.__uom

    def __build_data(self):

        req = QgsFeatureRequest()
        if self.__filter_expression is not None:
            req.setFilterExpression(self.__filter_expression)

        # Get unit of the first feature if needed
        if self.__uom is not None and self.__uom.startswith("@"):
            req2 = QgsFeatureRequest(req)
            req2.setLimit(1)
            for f in self.__layer.getFeatures(req):
                self.__uom = f[self.__uom[1:]]
                break

        req.setSubsetOfAttributes([self.__x_fieldname, self.__y_fieldname], self.__layer.fields())
        # Do not forget to add an index on this field to speed up ordering
        req.addOrderBy(self.__x_fieldname)

        xy_values = [(f[self.__x_fieldname], f[self.__y_fieldname] if f[self.__y_fieldname] is not None else self.__nodata_value)
                     for f in self.__layer.getFeatures(req)]

        self.__x_values = [coord[0] for coord in xy_values]
        self.__y_values = [coord[1] for coord in xy_values]

        self.__x_min, self.__x_max = (min(self.__x_values), max(self.__x_values)) if self.__x_values else (None, None)
        self.__y_min, self.__y_max = (min(self.__y_values), max(self.__y_values)) if self.__y_values else (None, None)

        self.data_modified.emit()


class FeatureData(DataInterface):
    """FeatureData model data that are stored on one feature (resp. row) in a layer (resp. table).
    
    This usually means data are the result of a sampling with a regular sampling interval for X.
    The feature has one array attribute that stores all values and the X values are given during
    construction.
    """

    def __init__(self, layer, y_fieldname, x_values=None, feature_ids=None, x_start=None, x_delta=None, x_start_fieldname=None, x_delta_fieldname=None):
        """
        layer: input QgsVectorLayer
        y_fieldname: name of the field in the input layer that carries data
        x_values: sequence of X values, that should be of the same length as data values.
                  If None, X values are built based on x_start and x_delta
        x_start: starting X value. Should be used with x_delta
        x_delta: interval between two X values.
        feature_ids: IDs of the features read. If set to None, the input data are assumed to represent one feature with ID=0
                     If more than one feature id is passed, their data will be merged.
                     In case of overlap between features, one will be arbitrarily chosen, and a warning will be raised.
        x_start_fieldname: name of the field in the input layer that carries the starting X value
        x_delta_fieldname: name of the field in the input layer that carries the interval between two X values
        """
        x_start_defined = x_start is not None or x_start_fieldname is not None
        x_delta_defined = x_delta is not None or x_delta_fieldname is not None

        if x_values is None:
            if not x_start_defined and not x_delta_defined:
                raise ValueError("Define either x_values or x_start / x_delta")
            if (not x_start_defined and x_delta_defined) or (x_start_defined and not x_delta_defined):
                raise ValueError("Both x_start and x_delta must be defined")

        if feature_ids is None:
            feature_ids = [0]

        if x_start_fieldname is None and len(feature_ids) > 1:
            raise ValueError("More than one feature, but only one starting value, define x_start_fieldname")
        if x_delta_fieldname is None and len(feature_ids) > 1:
            raise ValueError("More than one feature, but only one delta value, define x_delta_fieldname")

        DataInterface.__init__(self)

        self.__y_fieldname = y_fieldname
        self.__layer = layer
        self.__x_values = x_values
        self.__x_start = x_start
        self.__x_start_fieldname = x_start_fieldname
        self.__x_delta = x_delta
        self.__x_delta_fieldname = x_delta_fieldname
        self.__feature_ids = feature_ids

        # TODO connect on feature modification

        self.__build_data()

    def get_y_values(self):
        return self.__y_values

    def get_layer(self):
        return self.__layer

    def get_x_values(self):
        return self.__x_values

    def get_x_min(self):
        return self.__x_min

    def get_x_max(self):
        return self.__x_max

    def get_y_min(self):
        return self.__y_min

    def get_y_max(self):
        return self.__y_max

    def __build_data(self):

        req = QgsFeatureRequest()
        req.setFilterFids(self.__feature_ids)

        self.__x_values = []
        self.__y_values = []
        current_data_range = None
        for f in self.__layer.getFeatures(req):
            raw_data = f[self.__y_fieldname]
            if self.__x_start_fieldname is not None:
                x_start = f[self.__x_start_fieldname]
                x_delta = f[self.__x_delta_fieldname]
            else:
                x_start = self.__x_start
                x_delta = self.__x_delta

            if isinstance(raw_data, list):
                # QGIS 3 natively reads array values
                # Null values still have to be filtered out
                # WARNING: extracting list from PostgreSQL's arrays seem very sloowww
                y_values = [None if isinstance(x, QVariant) else x for x in raw_data]
            elif isinstance(raw_data, str):
                # We assume values are separated by a ','
                y_values = [None if value == 'NULL' else float(value)
                                   for value in raw_data.split(",")]
            else:
                print("Unsupported data format: {}".format(raw_data.__class__))

            x_values = np.linspace(x_start, x_start + x_delta * (len(y_values) - 1), len(y_values)).tolist()
            
            data_range = (x_start, x_start + x_delta * (len(y_values) - 1))
            if current_data_range is None:
                current_data_range = data_range
                self.__x_values = x_values
                self.__y_values = y_values
            else:
                # look for overlap
                if (current_data_range[0] < data_range[0] < current_data_range[1]) or \
                   (current_data_range[0] < data_range[1] < current_data_range[1]):
                    print("Overlap in data around feature #{}".format(f.id()))
                    continue
                if current_data_range[0] > data_range[1]:
                    # new data are "on the left"
                    self.__x_values = x_values + self.__x_values
                    self.__y_values = y_values + self.__y_values
                else:
                    # new data are "on the right"
                    self.__x_values = self.__x_values + x_values
                    self.__y_values = self.__y_values + y_values
                current_data_range = (self.__x_values[0], self.__x_values[-1])

        self.__x_min, self.__x_max = ((min(self.__x_values), max(self.__x_values))
                                      if self.__x_values else (None, None))
        self.__y_min, self.__y_max = ((min(y for y in self.__y_values if y is not None),
                                       max(y for y in self.__y_values if y is not None))
                                      if self.__y_values else (None, None))

        self.data_modified.emit()
