# Copyright (c) 2020 SiFive Inc.
# SPDX-License-Identifier: CC-BY-4.0

# BUILD_DIR is the path to where built outputs should be stored
BUILD_DIR ?= build

# GRAPHS is the list of all Graphvis graphs to build for the
# `graphs` target
GRAPHS ?= boot coordinator

# Building the Initialization Protocol graphs depends on the
# `dot` utility from Graphviz
DOT ?= $(shell which dot)
ifeq ($(DOT),)
$(error Unable to find dot, is Graphviz installed?)
endif

.PHONY: all
all: graphs

.PHONY:
help:
	@echo "------------------------------------------"
	@echo "OmniXtend Initialization Protocol Makefile"
	@echo "------------------------------------------"
	@echo "Targets:"
	@echo ""
	@echo " - all"
	@echo "\tBuilds all documentation"
	@echo " - graphs"
	@echo "\tBuilds all Graphviz graphs"
	@echo " - clean"

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/%.png: %.dot $(BUILD_DIR)
	$(DOT) -Tpng -o$@ $<

GRAPHS_PNG = $(addprefix $(BUILD_DIR)/,$(addsuffix .png,$(GRAPHS)))
GRAPHS_SRC = $(addsuffix .dot,$(GRAPHS))

.PHONY: graphs
graphs: $(GRAPHS_PNG)

.PHONY: clean
clean:
	-rm -rf $(BUILD_DIR)
