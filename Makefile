.PHONY: all build check clean clean-man deps deps-develop deps-test dist install install-man lint man prettier prettier-fix spec-check ste-lint test tidy tidy-fix uninstall

# Filesystem configuration
PREFIX			?= /usr/local
BINDIR			?= $(PREFIX)/bin
LIBDIR			?= $(PREFIX)/libdata/perl5/site_perl
MANDIR			?= $(PREFIX)/man
# The installed share tree uses the File::ShareDir layout under the
# perl library path, so Fugu::File->share_path resolves it from @INC.
SHAREDIST		= $(LIBDIR)/auto/share/dist/App-FuguVM

# Build configuration.  The version derives from the latest semantic
# version tag, without the leading v.  There is no VERSION file.
VERSION			?= $(shell (git describe --tags --match 'v*' --abbrev=0 2>/dev/null || echo v0.0.0) | sed 's/^v//')
DIST			= App-FuguVM
TARBALL			= $(DIST)-$(VERSION).tar.gz

# Build tools.  mandoc renders the cat pages of the man target.
MANDOC			?= mandoc
PERLTIDY		= perl -MPerl::Tidy -e 'Perl::Tidy::perltidy()'
# Pin the version so that local runs and CI agree on formatting
PRETTIER		= npx prettier@3.9.6

# Every Perl source in the tree: modules by extension, executables by
# shebang.  Files in bin/ and scripts/ carry no extension, because a
# tool's name does not encode its language.  Thus the shebang identifies
# them.  Perl::Critic selects files the same way.  lint and tidy
# therefore cover the same set, with no list to keep true.
PERLSRC			= find lib bin scripts -type f \( -name '*.pm' -o \
			  -exec sh -c 'head -1 "$$1" | grep -q "^\#!.*perl"' \
			  _ {} \; \) -print

DEPS			= scripts/deps

MAN1			= man/fuguvm/fuguvm.1
CATMAN1			= $(MAN1:.1=.cat1)

all: deps check

build: dist

# prettier stays out of check: it runs through npx, and no deps/
# manifest provides node. CI runs it in its own job.
check: lint test tidy spec-check ste-lint

clean: clean-man
	rm -rf build
	rm -f *.tmp

clean-man:
	rm -f $(CATMAN1)

deps:
	$(DEPS) runtime

deps-develop: deps deps-test
	$(DEPS) develop

deps-test: deps
	$(DEPS) test

# The dist tarball is a standard Perl distribution: Makefile.PL,
# MANIFEST, lib/, bin/, share/ and the module tests. CI attaches it to
# each release, and consumers install it with cpanm.
dist:
	@./scripts/dist --version $(VERSION)

install: install-man
	# Install the binary
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 bin/fuguvm $(DESTDIR)$(BINDIR)/fuguvm
	# Install Perl libraries.  App/ is a shared parent: other
	# distributions live there too, so it is created, never removed
	install -d $(DESTDIR)$(LIBDIR)/App
	install -d $(DESTDIR)$(LIBDIR)/App/FuguVM
	install -m 644 lib/App/FuguVM.pm lib/App/FuguVM.pod $(DESTDIR)$(LIBDIR)/App/
	install -m 644 lib/App/FuguVM/*.pm lib/App/FuguVM/*.pod $(DESTDIR)$(LIBDIR)/App/FuguVM/
	# Install the share tree where share_path finds it
	install -d $(DESTDIR)$(SHAREDIST)/fuguvm/expect
	install -d $(DESTDIR)$(SHAREDIST)/fuguvm/vms
	install -d $(DESTDIR)$(SHAREDIST)/scripts
	install -m 644 share/fuguvm/cache-generation $(DESTDIR)$(SHAREDIST)/fuguvm/
	install -m 644 share/fuguvm/fuguvm.conf.sample $(DESTDIR)$(SHAREDIST)/fuguvm/
	install -m 644 share/fuguvm/expect/*.exp $(DESTDIR)$(SHAREDIST)/fuguvm/expect/
	install -m 644 share/fuguvm/vms/*.sample $(DESTDIR)$(SHAREDIST)/fuguvm/vms/
	install -m 755 scripts/ftp $(DESTDIR)$(SHAREDIST)/scripts/ftp

install-man:
	# Install man pages
	install -d $(DESTDIR)$(MANDIR)/man1
	install -m 644 $(MAN1) $(DESTDIR)$(MANDIR)/man1/

spec-check:
	@./scripts/spec-check

ste-lint:
	@./scripts/ste-lint

lint:
	@$(PERLSRC) | xargs perl -MPerl::Critic::Command -e 'Perl::Critic::Command::run()' -- --severity 4 --verbose 8

man: $(CATMAN1)

prettier:
	@$(PRETTIER) --check --no-error-on-unmatched-pattern '**/*.md' '**/*.json' '**/*.yml' || { echo "Run 'make prettier-fix' to fix formatting"; exit 1; }

prettier-fix:
	$(PRETTIER) --write --no-error-on-unmatched-pattern '**/*.md' '**/*.json' '**/*.yml'

%.cat1: %.1
	$(MANDOC) -Tascii $< > $@

test:
	prove -l -v t/fuguvm/*.t
	prove -l -v t/scripts/*.t
	prove -l -v t/ci/*.t

tidy:
	@$(PERLSRC) | while read f; do \
		$(PERLTIDY) -- --standard-output "$$f" | diff -q "$$f" - >/dev/null 2>&1 || echo "$$f"; \
	done | grep . && echo "Run 'make tidy-fix' to fix formatting" && exit 1 || echo "All files formatted correctly"

tidy-fix:
	@$(PERLSRC) | while read f; do \
		$(PERLTIDY) -- -b -bext='/' "$$f"; \
	done

uninstall:
	# Remove the binary
	rm -f $(DESTDIR)$(BINDIR)/fuguvm
	# Remove Perl libraries.  App/ is a shared parent: other
	# distributions live beside ours.  Remove what this project
	# owns, then rmdir the parent, which fails harmlessly when it
	# still holds something
	rm -rf $(DESTDIR)$(LIBDIR)/App/FuguVM
	rm -f $(DESTDIR)$(LIBDIR)/App/FuguVM.pm
	rm -f $(DESTDIR)$(LIBDIR)/App/FuguVM.pod
	rm -rf $(DESTDIR)$(SHAREDIST)
	-rmdir $(DESTDIR)$(LIBDIR)/App 2>/dev/null
	# Remove man pages
	rm -f $(DESTDIR)$(MANDIR)/man1/fuguvm.1
