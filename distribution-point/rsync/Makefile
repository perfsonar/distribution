
NAME := distrobox
DEST := /opt/$(NAME)


default:
	@echo Nothing to do here.


$(DEST):
	mkdir -p $@
	chmod 700 $@

%: %.raw
	m4 "-D__NAME__=$(NAME)" "-D__DEST__=$(DEST)" $< > $@

$(DEST)/%: %
	cp $< $@
	chmod 500 $@

install: $(DEST) $(DEST)/update-rsync crontab
	crontab -l -u root \
	| sed -e '/^#BEGIN-distrobox/,/#END-distrobox/d' \
	| (cat && cat crontab) \
	| crontab -u root

TO_CLEAN += crontab


uninstall:
	crontab -l -u root \
	| sed -e '/^#BEGIN-distrobox/,/#END-distrobox/d' \
	| crontab -u root
	rm -rf $(DEST)


clean:
	rm -rf $(TO_CLEAN) *~
