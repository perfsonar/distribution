#
# Rsyncd conf for distribution box
#


dont compress = *.gz *.tgz *.zip *.z *.rpm *.deb *.iso *.bz2 *.tbz
# dont compress   = *.gz *.tgz *.zip *.z *.Z *.rpm *.deb *.bz2
# exclude = lost+found/
# gid = nobody
# ignore nonreadable = yes
max connections = 20
# pid file = /var/run/rsyncd.pid
read only = yes
refuse options = checksum dry-run xattrs
# timeout = 900
# transfer logging = yes
# uid = nobody
use chroot = yes

[perfsonar]
	path = __REPOSITORY__
	comment = perfSONAR Software Repository
	exclude = index/
	list = yes
	hosts allow = include(__IP_LIST__)
	hosts deny = *
