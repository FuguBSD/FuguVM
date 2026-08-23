# mk/local.mk: the consumer hook of this repository (MK-LOCAL).
# sync never touches this file.

# Filesystem configuration
PREFIX		?= /usr/local
BINDIR		?= $(PREFIX)/bin
LIBDIR		?= $(PREFIX)/libdata/perl5/site_perl
MANDIR		?= $(PREFIX)/man
# The installed share tree uses the File::ShareDir layout under the
# perl library path, so Fugu::File->share_path resolves it from @INC.
SHAREDIST	= $(LIBDIR)/auto/share/dist/App-FuguVM

# Build tools. mandoc renders the cat pages of the man target.
MANDOC		?= mandoc

# The executable joins the module and shebang scan
PERL_SRC_DIRS	= lib bin scripts

# The full test tier set of make test
TEST_GLOBS	= t/fuguvm/*.t t/scripts/*.t t/ci/*.t

MAN1		= man/fuguvm/fuguvm.1
CATMAN1		= man/fuguvm/fuguvm.cat1

man: $(CATMAN1)

$(CATMAN1): $(MAN1)
	$(MANDOC) -Tascii $(MAN1) > $(CATMAN1)

clean: clean-man
	rm -rf build
	rm -f *.tmp

clean-man:
	rm -f $(CATMAN1)

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

.PHONY: man clean clean-man install install-man uninstall
