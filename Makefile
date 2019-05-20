prefix = /usr

SUBDIRS = \
	tests \

default:

all: check test

$(SUBDIRS):
	$(MAKE) -C $@

check: shellcheck
	$(MAKE) -C tests check

shellcheck:
	shellcheck archive.sh

test:
	$(MAKE) -C tests test

install:
	install -Dm755 archive.sh $(DESTDIR)$(prefix)/bin/archive

clean:
	@for dir in $(SUBDIRS); do \
	  $(MAKE) -C $$dir clean; \
	done

.PHONY: \
	all \
	check \
	clean \
	default \
	install \
	shellcheck \
	test \
	$(SUBDIRS) \
