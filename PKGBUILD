# Maintainer: Tomás Pinho <me(at)tomaspinho(dot)com>

pkgname=rtl8821ce-dkms-git
_pkgbase=rtl8821ce
pkgver=1.0.0.r11.g932e820
pkgrel=1
pkgdesc="rtl8821CE driver with firmware"
arch=('i686' 'x86_64')
url="https://github.com/Gabz4200/rtl8821ce"
license=('GPL2')
depends=('dkms')
makedepends=('git')
conflicts=("${_pkgbase}")
source=("git+https://github.com/Gabz4200/rtl8821ce.git")
#        'dkms.conf')
sha256sums=('SKIP')
#            '3f401c2a8c862af919b1fdaaa4270ef18f674725035c9769590d529b9aa5c078')


pkgver() {
    cd "${srcdir}/rtl8821ce"
    printf '%s.r%s.g%s' '1.0.0' "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

package() {
        cd "${srcdir}/rtl8821ce"
        mkdir -p "${pkgdir}/usr/src/${_pkgbase}-${pkgver}"
        cp -pr * "${pkgdir}/usr/src/${_pkgbase}-${pkgver}"
}
