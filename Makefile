BIN_DIR ?= $(CURDIR)/bin
.PHONY: install

install: bin/irsyncplus.sh
	ln -sf $(BIN_DIR)/irsyncplus.sh /bin/doit 

