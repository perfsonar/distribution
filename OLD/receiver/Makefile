#
# Makefile for distribution receiver
#

# Normal setup
default:
	mkdir -p incoming
	[ -e "incoming/rrsync" ] \
		|| ln -s ../bin/rrsync incoming


# Tidy.
clean:
	find . -name "*~" | xargs rm -f


# Back to as-distributed.  THIS IS DESTRUCTIVE.
distclean: clean
	@mkdir -p incoming
	@for DIR in $$(ls -l incoming \
		| egrep -e '^d' \
		| awk '{ print $$9 }') ; \
	do \
		echo "Removing $${DIR}" ; \
		./bin/remove "$${DIR}" ; \
	done
	rm -rf incoming keys
