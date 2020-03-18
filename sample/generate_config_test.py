# script to run in the Python console

import json
import psycopg2

from qgis.utils import iface


conn = psycopg2.connect("service=qgeologistest")
cur = conn.cursor()
cur.execute("select * from measure.measure_metadata")


def add_layer(source, name, provider, group=None):
    layer = QgsVectorLayer(source, name, provider)
    QgsProject.instance().addMapLayer(layer, addToLegend=group is None)
    if group is not None:
        group.addLayer(layer)
    return layer


main_layer = add_layer(
    """service='qgeologistest' sslmode=disable key='id' srid=4326 type=Point checkPrimaryKeyUnicity='0' table="qgis"."station" (point)""",
    "Stations",
    "postgres",
)

root_group = iface.layerTreeView().layerTreeModel().rootGroup()
group = root_group.addGroup("Mesures")


strat_layer = add_layer(
    """service='qgeologistest' sslmode=disable key='depth_from,depth_to,station_id' srid=4326 type=Polygon checkPrimaryKeyUnicity='0' table="qgis"."measure_stratigraphic_logvalue" (geom)""",
    "Stratigraphie",
    "postgres",
    group,
)

chem_layer = add_layer(
    """service='qgeologistest' sslmode=disable key='id' table="qgis"."measure_chemical_analysis_result" checkPrimaryKKeyUnicity='0'""",
    "Analyse chimique",
    "postgres",
    group,
)

log_measures = []
timeseries = [
    {
        "source": chem_layer.id(),
        "name": chem_layer.name(),
        "uom_column": "measure_unit",
        "feature_ref_column": "station_id",
        "feature_filter_type": "unique_data_from_values",
        "feature_filter_column": "chemical_element",
        "type": "instantaneous",
        "event_column": "measure_epoch",
        "value_column": "measure_value",
    }
]
imagery_data = []

for table_name, name, uom, x_type, storage_type in cur.fetchall():
    schema, table = table_name.split(".")
    layer = add_layer(
        """service='qgeologistest' sslmode=disable key='id' checkPrimaryKeyUnicity='0' table="qgis"."{}_{}" """.format(
            schema, table
        ),
        name,
        "postgres",
        group,
    )
    if x_type == "TimeAxis":
        # time series
        if storage_type == "Continuous":
            timeseries.append(
                {
                    "source": layer.id(),
                    "name": name,
                    "uom": uom,
                    "feature_ref_column": "station_id",
                    "type": storage_type.lower(),
                    "start_measure_column": "start_epoch",
                    "interval_column": "interval_s",
                    "values_column": "measures",
                }
            )
        elif storage_type == "Instantaneous":
            timeseries.append(
                {
                    "source": layer.id(),
                    "name": name,
                    "uom": uom,
                    "feature_ref_column": "station_id",
                    "type": storage_type.lower(),
                    "event_column": "measure_epoch",
                    "value_column": "measure_value",
                }
            )
        elif storage_type == "Cumulative":
            timeseries.append(
                {
                    "source": layer.id(),
                    "name": name,
                    "uom": uom,
                    "feature_ref_column": "station_id",
                    "type": storage_type.lower(),
                    "event_column": "measure_epoch",
                    "value_column": "measure_value",
                }
            )
    elif x_type == "DepthAxis":
        if storage_type == "Image":
            imagery_data.append(
                {
                    "name": name,
                    "source": "service=bdlhes",
                    "schema": "qgis",
                    "table": "measure_{}".format(table),
                    "feature_ref_column": "station_id",
                }
            )
        else:
            log_measures.append(
                {
                    "source": layer.id(),
                    "name": name,
                    "uom": uom,
                    "feature_ref_column": "station_id",
                    "type": storage_type.lower(),
                    "start_measure_column": "start_measure_altitude",
                    "interval_column": "altitude_interval",
                    "values_column": "measures",
                }
            )


config = {
    main_layer.id(): {
        "layer_name": "Stations",
        "id_column": "id",
        "name_column": "name",
        "stratigraphy_config": [
            {
                "source": strat_layer.id(),
                "feature_ref_column": "station_id",
                "depth_from_column": "depth_from",
                "depth_to_column": "depth_to",
                "formation_code_column": "formation_code",
                "rock_code_column": "rock_code",
                "formation_description_column": "formation_description",
                "rock_description_column": "rock_description",
            }
        ],
        "log_measures": log_measures,
        "timeseries": timeseries,
        "imagery_data": imagery_data,
    }
}

json = json.dumps(config)
print("config: ", json)
QgsProject.instance().writeEntry("QGeoloGIS", "config", json)
