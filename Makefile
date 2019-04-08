PLUGIN_NAME=$(shell grep "^name" metadata.txt | cut -d'=' -f2)
VERSION=$(shell grep "^version" metadata.txt | cut -d'=' -f2)

SOURCES=__init__.py \
	qgis_plugin.py \
	metadata.txt \
	well_log/__init__.py \
	well_log/data_interface.py \
	well_log/legend_item.py \
	well_log/qt_qgis_compat.py \
	well_log/timeseries_view.py \
	well_log/well_log_common.py \
	well_log/well_log_plot.py \
	well_log/well_log_view.py \
	well_log/well_log_z_scale.py \
	well_log/well_log_stratigraphy.py \
	well_log/img/*.svg \
	well_log/styles/*.svg \
	well_log/styles/*.xml

ZIP_FILE=qgiswelllog-$(VERSION).zip

QGIS2_PATH=~/.qgis2/python/plugins/$(PLUGIN_NAME)
QGIS3_PATH=~/.local/share/QGIS/QGIS3/profiles/default/python/plugins/$(PLUGIN_NAME)

.PHONY = zip
zip: $(ZIP_FILE)

$(ZIP_FILE): $(SOURCES)
	zip $(ZIP_FILE) $(SOURCES)

deploy: $(ZIP_FILE)
	mkdir -p $(QGIS2_PATH)
	unzip -o $(ZIP_FILE) -d $(QGIS2_PATH)
	mkdir -p $(QGIS3_PATH)
	unzip -o $(ZIP_FILE) -d $(QGIS3_PATH)



