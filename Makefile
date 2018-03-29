## MORF REST Server Makefile for installation.

PREFIX ?= /usr/local
INSTALL_MODULE= $(PREFIX)/redfish
GIT_DIR ?= git
APP_DIR ?= $(GIT_DIR)/app
DB_DIR ?= $(GIT_DIR)/db_init
OUTPUT_DIR ?= output

all: clean build

build:
	for f in `find $(APP_DIR) -name "*.lua" -printf "%P\n"`; do \
		mkdir -p $(OUTPUT_DIR)/`dirname "$$f"`; \
		luajit -b -s $(APP_DIR)/"$$f" $(OUTPUT_DIR)/"$$f"; \
	done

clean:
	rm -rf $(OUTPUT_DIR)

uninstall:
	@echo "==== Uninstalling Redfish server. ===="
	rm -rf $(INSTALL_MODULE)
	@echo "==== Redfish server uninstalled.===="

install:
	@echo "==== Installing Redfish server. ===="
	install -d $(INSTALL_MODULE)
	install -d $(INSTALL_MODULE)/oem
	install -d $(INSTALL_MODULE)/extensions/constants
	install -d $(INSTALL_MODULE)/extensions/routes

	cp -R $(OUTPUT_DIR)/* $(INSTALL_MODULE)
	cp -R $(DB_DIR) $(INSTALL_MODULE)/db_init

	@echo "==== Successfully installed Redfish server to $(PREFIX) ===="
