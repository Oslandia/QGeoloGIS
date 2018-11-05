# -*- coding: utf-8 -*-

from qgis.core import QgsVectorLayer, QgsFeatureRequest, QgsExpression, QgsMapLayerRegistry, QgsFeatureRendererV2, QgsMapToPixel
from qgis.core import QgsPoint, QgsGeometry, QgsRenderContext, QgsField, QgsFields, QgsFeature, QgsWKBTypes, QgsRectangle
from qgis.core import QgsCoordinateTransform, QgsCoordinateReferenceSystem
from qgis.gui import QgsMapCanvas, QgsMapCanvasLayer

from PyQt4.QtGui import QGraphicsScene, QImage, QPixmap, QMainWindow, QBrush, QColor, QWheelEvent, QPen, QIcon
from PyQt4.QtGui import QGraphicsView, QColor, QGraphicsItem, QGraphicsLineItem, QRegion, QPushButton, QVBoxLayout, QHBoxLayout
from PyQt4.QtGui import QWidget, QDialog, QDialogButtonBox, QToolBar, QToolButton, QAction, QActionGroup, QStatusBar, QSizePolicy
from PyQt4.QtGui import QStackedWidget, QComboBox, QListWidget, QListWidgetItem, QFont, QFontMetrics, QPolygonF, QLabel, QFileDialog
from PyQt4.QtCore import Qt, QObject, QRectF, QSizeF, QVariant
from PyQt4.QtXml import QDomDocument

POINT_RENDERER = 0
LINE_RENDERER = 1
POLYGON_RENDERER = 2

# X and Y data orientations
ORIENTATION_LEFT_TO_RIGHT = 0
ORIENTATION_RIGHT_TO_LEFT = 1 # unused
ORIENTATION_UPWARD = 2
ORIENTATION_DOWNWARD = 3

def qgis_render_context(painter, width, height):
    mtp = QgsMapToPixel()
    # the default viewport if centered on 0, 0
    mtp.setParameters( 1,        # map units per pixel
                       width/2,  # map center in geographical units
                       height/2, # map center in geographical units
                       width,    # output width in pixels
                       height,   # output height in pixels
                       0.0       # rotation in degrees
    )
    context = QgsRenderContext()
    context.setMapToPixel(mtp)
    context.setPainter(painter)
    return context

class LogItem(QGraphicsItem):
    def __init__(self, parent=None):
        QGraphicsItem.__init__(self, parent)

        self.__selected = False

    def selected(self):
        return self.__selected

    def set_selected(self, sel):
        self.__selected = sel

    def draw_background(self, painter, outline=True):
        old_pen = painter.pen()
        old_brush = painter.brush()
        p = QPen()
        b = QBrush()
        if self.__selected:
            p.setColor(QColor("#ffff99"))
            p.setWidth(2)
            b.setColor(QColor("#ffff66"))
            b.setStyle(Qt.SolidPattern)
        if self.__selected or outline:
            painter.setBrush(b)
            painter.setPen(p)
            painter.drawRect(0, 0, self.boundingRect().width()-1, self.boundingRect().height()-1)
            if outline:
                painter.setBrush(QBrush())
                painter.setPen(QPen())
                painter.drawRect(0, 0, self.boundingRect().width()-1, self.boundingRect().height()-1)
            painter.setBrush(old_brush)
            painter.setPen(old_pen)
