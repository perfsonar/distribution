#
# Makefile for perfSONAR repository
#

RECEIVER_DIR:=../receiver/incoming
REPO_DIR:=./repo


default: build


RECEIVER_ABSOLUTE:=$(shell cd "$(RECEIVER_DIR)" && pwd)


LINK_TABLE=link-table
$(LINK_TABLE): directory-tree
	sed -e 's/#.*$$//g; /^\s*$$/d' < $< > $@
TO_CLEAN += $(LINK_TABLE)


BUILD_SCRIPT=build-script
BUILD_DIR=$(REPO_DIR).build
$(BUILD_SCRIPT): $(LINK_TABLE)
	rm -f $@
	@true
	@true Repo Directory
	@true
	printf "mkdir -p \"%s\"\n" "$(BUILD_DIR)" >> $@
	echo foo
	@true
	@true Directory Tree
	@true
	cat $< \
	| awk -v "DIR=$(BUILD_DIR)" \
		'$$1 ~ /\// { printf "mkdir -p \"%s/%s\"\n", DIR, $$1 }' \
	>> $@
	@true
	@true Symbolic Links to Incoming Directories
	@true
	cat $< \
	| awk -v "RECEIVER=$(RECEIVER_ABSOLUTE)" -v "REPO=$(BUILD_DIR)" \
	  '{ printf "ln -s \"%s/%s\" \"%s/%s\"\n", RECEIVER, $$2, REPO, $$1 }' \
	>> $@
	echo 'rm -rf "$(REPO_DIR)"' >> $@
	echo 'mv -f "$(BUILD_DIR)" "$(REPO_DIR)"' >> $@
	sh $(BUILD_SCRIPT)
TO_CLEAN += $(BUILD_SCRIPT) $(BUILD_DIR) $(REPO_DIR)


HTTPD_CONF=./httpd.conf
$(HTTPD_CONF): $(HTTPD_CONF).raw
	sed -e 's|__REPO__|$(shell cd "$(REPO_DIR)" && pwd)|g' < $< > $@
TO_CLEAN += $(HTTPD_CONF)


build: $(BUILD_SCRIPT) $(HTTPD_CONF)


clean:
	rm -rf $(TO_CLEAN) *~
