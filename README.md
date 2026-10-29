# dymo-overlay

A Portage overlay packaging DYMO's CUPS drivers for the LabelWriter 550
series, which ::gentoo's `net-print/dymo-cups-drivers` (4xx and older) does
not cover.

| Package | Source | Installs | Notes |
|---|---|---|---|
| `net-print/dymo-lw5xx-cups-drivers` | DYMO's GPL source, [dymosoftware/Drivers](https://github.com/dymosoftware/Drivers) `LW5xx_Linux` | CUPS filters `raster2dymolw_v2`, `raster2dymolm_v2` and 8 PPDs | LabelWriter 550, 550 Turbo, 550 Pro, 550 Twin Pro, 5XL, 5XL Pro, Wireless; MobileLabeler |

## Layout

```
dymo-overlay/
├── metadata/layout.conf
├── profiles/{repo_name,categories}
└── net-print/dymo-lw5xx-cups-drivers/
    ├── dymo-lw5xx-cups-drivers-1.4.3.ebuild
    ├── metadata.xml · Manifest
    └── files/
        ├── dymo-lw5xx-cups-drivers-1.4.3-cxxflags.patch
        └── dymo-lw5xx-cups-drivers-1.4.3-ctime.patch
```

## Installing the overlay (as root)

Portage runs as `portage:portage`, so the overlay belongs in the standard
root-owned location, `/var/db/repos/dymo-overlay` — not in a home directory.

```bash
cat > /etc/portage/repos.conf/dymo-overlay.conf <<'CONF'
[dymo-overlay]
location = /var/db/repos/dymo-overlay
sync-type = git
sync-uri = https://github.com/nvaert1986/dymo-overlay.git
auto-sync = yes
masters = gentoo
priority = 50
CONF

emaint sync -r dymo-overlay
```

`emerge --sync` then keeps it current alongside `::gentoo`.

## Installing dymo-lw5xx-cups-drivers

```bash
echo 'net-print/dymo-lw5xx-cups-drivers ~amd64' >> /etc/portage/package.accept_keywords/dymo-overlay
emerge -av net-print/dymo-lw5xx-cups-drivers
```

It installs next to `net-print/dymo-cups-drivers`: DYMO gave the newer
filters a `_v2` suffix and the PPDs new names (`lw550*.ppd`, `lw5xl*.ppd`,
`lww.ppd`, `lmmls.ppd`), so no file is shared. Keep both installed if you
have LabelWriters from both series.

Then add the printer in the KDE or CUPS printer settings with the "DYMO
LabelWriter 550" (or 550 Turbo, 5XL, ...) driver, or as root:

```bash
lpinfo -v | grep -i dymo
lpadmin -p LabelWriter-550 -E -v '<usb:// URI from above>' -m lw550.ppd
```

## Runtime notes

- **The queue has to reach the printer itself.** Before every job the
  filter asks the printer for its status (`ESC A`) and waits for the answer
  over CUPS's back channel. A queue on USB, or on the network for the 550
  Turbo and 5XL, provides that. A raw queue, or a 550 shared from a Windows
  PC, does not: the job fails after about 30 seconds without printing. The
  LabelWriter 4xx driver has no such requirement.
- **The filter only runs under CUPS.** It looks itself up as a CUPS
  destination by its program name (CUPS passes the queue name) and refuses
  to start when it finds none ("Unable to get synchronization lock"), so
  running it by hand needs `exec -a <existing queue>`.
- **DYMO labels only.** The 550 series reads the RFID tag on the roll and
  refuses other labels. That is the printer's own check, not the driver's.
- **Boost** is needed at build time only, for headers. The repository's own
  158 MB Boost copy is deleted before building; the build never used it.
- **No tests.** Upstream's test suite does not build (it needs a
  `DummyLanguageMonitor.cpp` that is not in the repository), so
  `RESTRICT="test"`.
- **amd64 only** is keyworded because that is what was built and tested. It is
  plain C++ against CUPS, so other architectures (a Raspberry Pi print server,
  say) will most likely build too; add a keyword in `package.accept_keywords`
  with `**` to try.

## Upgrading

```bash
emaint sync -r dymo-overlay
emerge -av net-print/dymo-lw5xx-cups-drivers
```

## Bumping the version

DYMO publishes no releases or tags: the driver is the `LW5xx_Linux` folder
of [dymosoftware/Drivers](https://github.com/dymosoftware/Drivers), and the
ebuild pins a commit. The folder's git tree has been `b886b1a6` since it was
added in 2021. To see whether it changed:

```bash
gh api "repos/dymosoftware/Drivers/commits?path=LW5xx_Linux" --jq '.[] | "\(.sha) \(.commit.author.date)"'
gh api repos/dymosoftware/Drivers/git/trees/main --jq '.tree[] | select(.path=="LW5xx_Linux") | .sha'
```

A new tree means a new driver. Then:

1. Take the version from DYMO's release name if there is one (the
   1.4.3 comes from an earlier commit's `LW5xx Linux 1.4.3.zip`), else from
   `configure.ac`'s `AC_INIT`.
2. `git mv` the ebuild, set `COMMIT` to the newest commit, and check that
   both patches still apply (`configure.ac` may have stopped overwriting
   `CXXFLAGS`; the `<ctime>` include may be there already).
3. Compare the installed files with `src/*/Makefile.am` and
   `ppd/Makefile.am` for new filters or PPDs, and re-run the collision
   check against `net-print/dymo-cups-drivers`.
4. `ebuild <new>.ebuild manifest`. The distfile is GitHub's archive of the
   whole repository (about 45 MB).

```bash
cd net-print/dymo-lw5xx-cups-drivers
git mv dymo-lw5xx-cups-drivers-<old>.ebuild dymo-lw5xx-cups-drivers-<new>.ebuild
ebuild dymo-lw5xx-cups-drivers-<new>.ebuild manifest
```
