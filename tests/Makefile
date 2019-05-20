SOURCES = $(wildcard test-*.sh)

CHECKS = $(SOURCES:.sh=.check)

TESTS = $(SOURCES:.sh=.test)

LOGS = $(SOURCES:.sh=.log)

default:

all: check test

%.check: %.sh
	shellcheck $<

%.test: %.sh
ifeq ($(VERBOSE), yes)
	@echo "[test] running $<"
	@bash $< 2>&1 | tee $*.log
else
	@bash $< &> $*.log
endif

$(CHECKS):

$(TESTS):

check: $(CHECKS)

test: $(TESTS)

clean:
	-rm -f $(LOGS)

.PHONY: \
	check \
	clean \
	default \
	test \
