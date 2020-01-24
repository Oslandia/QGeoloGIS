if __name__ == '__main__':
    from qgis.PyQt.QtWidgets import QApplication
    from qgis.core import *
    import sys
    import os
    from .main_dialog import MainDialog


    QgsApplication.setPrefixPath("/usr/local", True)
    app = QgsApplication([], False)
    app.initQgis()

    path = lambda x: os.path.join(os.path.dirname(__file__), x)

    collar = QgsVectorLayer(path('test_collar.geojson'), 'collar', 'ogr')
    assert(collar.isValid())

    formation = QgsVectorLayer(path('test_formation.geojson'), 'formation', 'ogr')
    assert(formation.isValid())

    radiometry = QgsVectorLayer(path('test_radiometry.geojson'), 'radiometry', 'ogr')
    assert(radiometry.isValid())

    QgsProject.instance().addMapLayer(collar)
    QgsProject.instance().addMapLayer(formation)
    QgsProject.instance().addMapLayer(radiometry)

    collar.select([0])

    cfg = { collar.id(): {
              "layer_name": "collar",
                  "id_column": "id",
                  "name_column": "id",
                  "stratigraphy_config": [
                  {
                      "name": "Stratigraphy",
                      "source": formation.id(),
                      "feature_ref_column": "hole_id",
                      "depth_from_column": "from_",
                      "depth_to_column": "to_",
                      "formation_code_column": "comments",
                      "rock_code_column": "code",
                      "formation_description_column": "comments",
                      "rock_description_column": "code",
                      "style": "formation_style.xml"}
                  ],
                  "log_measures": [
                  {
                      "source": radiometry.id(),
                      "name": "Radiometry",
                      "uom": "Gamma",
                      "feature_ref_column": "hole_id",
                      "type": "instantaneous",
                      "min":0,
                      "event_column": "from_",
                      "value_column": "gamma",
                      "visible": True}
                  ],
                  "timeseries": [],
                  "imagery_data": []
        }}
    dlg = MainDialog(None, 'logs', cfg, collar)
    dlg.show()
    app.exec_()
