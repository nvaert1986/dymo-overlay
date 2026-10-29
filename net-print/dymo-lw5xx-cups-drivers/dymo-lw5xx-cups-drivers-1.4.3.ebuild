# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools

# DYMO publishes the driver only as a folder in its Drivers repository,
# without tags or release archives. LW5xx_Linux has been unchanged since it
# was added (git tree b886b1a6 in every commit since); an earlier commit also
# carried it as "LW5xx Linux 1.4.3.zip", which is where the version comes
# from. configure.ac still says 2.0.0.0.
COMMIT="9f2f15b3f1c2dddf4dcdfb64f380748120d249ba"

DESCRIPTION="DYMO CUPS drivers for the LabelWriter 550, 5XL and Wireless series"
HOMEPAGE="https://github.com/dymosoftware/Drivers"
# The archive is the whole repository (Windows and older Linux drivers too),
# about 45 MB; src_unpack only extracts the LW5xx_Linux folder.
SRC_URI="https://github.com/dymosoftware/Drivers/archive/${COMMIT}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/Drivers-${COMMIT}/LW5xx_Linux"

# The sources say "version 2 of the License, or (at your option) any later
# version"; LICENSE in the folder is the GPL-2 text.
LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="~amd64"

# Upstream's test suite does not build: src/lw/tests needs
# src/common/DummyLanguageMonitor.cpp, which is not in the repository.
RESTRICT="test"

# Both filters link only CUPS (scripts/elf-deps.sh on the built filters):
#
#   libcups.so.2       -> net-print/cups
#   libcupsimage.so.2  -> net-print/cups
#
# Boost is used for headers only (interprocess named_mutex, thread_time) and
# is not linked. The repository bundles a 158 MB Boost copy under src/boost
# that the build never puts on its include path; it is removed anyway so
# the system's headers are the only ones in reach.
RDEPEND="net-print/cups"
DEPEND="
	${RDEPEND}
	dev-libs/boost
"

PATCHES=(
	"${FILESDIR}"/${P}-cxxflags.patch
	"${FILESDIR}"/${P}-ctime.patch
)

DOCS=( AUTHORS ChangeLog README docs/SAMPLES )

src_unpack() {
	# Only the Linux 5xx driver; skips the Windows installers and the zipped
	# 4xx driver that make up most of the archive.
	tar -xzf "${DISTDIR}/${P}.tar.gz" -C "${WORKDIR}" "Drivers-${COMMIT}/LW5xx_Linux" || die
}

src_prepare() {
	default
	rm -r src/boost || die
	eautoreconf
}

src_install() {
	default
	dodoc docs/DYMO_SDK_for_Linux.rtf
}

pkg_postinst() {
	if [[ -n ${REPLACING_VERSIONS} ]]; then
		return
	fi
	elog "The drivers are installed next to net-print/dymo-cups-drivers (the"
	elog "LabelWriter 4xx and older): their filters are raster2dymolw_v2 and"
	elog "raster2dymolm_v2 and their PPDs lw550*.ppd, lw5xl*.ppd, lww.ppd and"
	elog "lmmls.ppd, so both packages can be installed at once."
	elog
	elog "Set up a printer with the KDE or CUPS printer settings, choosing the"
	elog "\"DYMO LabelWriter 550\" (or 550 Turbo, 5XL, ...) driver, or as root:"
	elog
	elog "  lpinfo -v | grep -i dymo"
	elog "  lpadmin -p LabelWriter-550 -E -v '<usb:// URI from above>' -m lw550.ppd"
	elog
	elog "The driver reads the printer's status before every job, so it needs a"
	elog "queue that talks to the printer directly (USB, or the network on the"
	elog "550 Turbo and 5XL). A raw queue or a printer shared from Windows does"
	elog "not give it that status, and jobs fail after about 30 seconds."
	elog
	elog "The 550 series only prints on DYMO labels: the printer itself reads"
	elog "the RFID tag on the roll and refuses other labels."
}
