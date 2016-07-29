# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=6

inherit eutils

DESCRIPTION="Shell script daemon for fstrim to maintain ssd drive performance"
HOMEPAGE="https://github.com/dobek/fstrimDaemon"
if [[ ${PV} == *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/dobek/${PN}.git"
	KEYWORDS=""
else
	SRC_URI="https://github.com/dobek/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~ia64 ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86"
fi

SLOT="0"
LICENSE="GPL-2"
IUSE="systemd"

RDEPEND="sys-apps/util-linux"
DEPEND="${RDEPEND}"

src_prepare() {
	epatch "${FILESDIR}/${PN}-1.1.1-fixes.patch"
	eapply_user
}

src_compile() {
	:
}

src_install() {
	dosbin usr/sbin/fstrimDaemon.sh
	dodoc README.md
	if ! use systemd ; then
		doinitd etc/init.d/fstrimDaemon
		doconfd etc/conf.d/fstrimDaemon
	else
		systemd_dounit usr/lib/systemd/system/fstrimDaemon.service
	fi
}
