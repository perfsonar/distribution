#
# Rsyncd conf for distribution box
#

# uid = nobody
# gid = nobody
# use chroot = yes
max connections = 20
# pid file = /var/run/rsyncd.pid
# exclude = lost+found/
# transfer logging = yes
# timeout = 900
# ignore nonreadable = yes
# dont compress   = *.gz *.tgz *.zip *.z *.Z *.rpm *.deb *.bz2

[perfsonar]
	path = __REPOSITORY__
	comment = perfSONAR Software Repository
	list = true
	read only = true
	hosts allow = include(__IP_LIST__)
	hosts deny = *
