SHELL := /bin/bash

BASH ?= bash
SHELLCHECK ?= shellcheck
SHFMT ?= shfmt
BATS ?= bats

SHELL_SOURCES := $(wildcard src/*.sh) install.sh uninstall.sh $(wildcard scripts/*.sh) $(wildcard tests/unit/*.sh) $(wildcard tests/integration/*.sh)
FORMAT_SOURCES := $(SHELL_SOURCES)
BUILD_DIR := $(CURDIR)/build

.PHONY: lint format-check unit-test bats-test integration integration-systemd package package-test verify clean

lint:
	$(SHELLCHECK) --shell=bash --severity=warning $(SHELL_SOURCES)

format-check:
	$(SHFMT) -d -i 2 -ci $(FORMAT_SOURCES)

unit-test:
	$(BASH) tests/unit/test_monitor.sh
	$(BASH) tests/unit/test_installer.sh

bats-test:
	$(BATS) tests/bats

integration:
	$(BASH) tests/integration/test_fault_injection.sh

integration-systemd:
	MINIOPS_ALLOW_SYSTEMD_TEST=1 $(BASH) tests/integration/test_systemd.sh

package:
	$(BASH) scripts/package.sh

package-test:
	$(BASH) tests/integration/test_package.sh

verify: lint format-check unit-test bats-test integration package-test

clean:
	rm -rf -- "$(BUILD_DIR)"
