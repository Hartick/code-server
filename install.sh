#!/bin/sh
set -eu

unset DRY_RUN \
  VERBOSE \
  VERSION \
  ARCH

usage() {
  cat <<EOF
$0 [-d] [-v]

  -d Enables a dry run where where the steps that would have taken place
     are printed but do not actually execute.

  -v Runs in verbose mode. Every executed shell command will be printed.
EOF
  exit 1
}

main() {
  VERSION=3.3.1
  ARCH="$(arch)"

  while getopts ":vd" opt; do
    case "$opt" in
    d) DRY_RUN=1 ;;
    v) VERBOSE=1 ;;
    h | ?) usage ;;
    esac
  done

  shift $((OPTIND - 1))

  if [ ${VERBOSE-} ]; then
    set -x
  fi

  if [ ! "$ARCH" ]; then
    echo "Unsupported architecture $(uname -m)."
    echo "Please install from npm."
    echo "See https://github.com/cdr/code-server#yarn-npm"
    exit 1
  fi

  os_name

  case "$(os)" in
  macos)
    install_macos
    ;;
  ubuntu | debian | raspbian)
    install_deb
    ;;
  centos | fedora | rhel | suse)
    install_rpm
    ;;
  arch)
    install_arch
    ;;
  *)
    # TODO fix
    echo "Unsupported OS $(os_name)."
    exit 1
    ;;
  esac
}

install_macos() {
  if command_exists brew; then
    echo "Installing from Homebrew."

    echo
    (
      set -x
      brew install code-server
    )

    return
  fi

  echo "Homebrew is not installed so using static release."

  install_static
}

install_deb() {
  set_sudo

  echo "Installing v$VERSION deb package from GitHub releases."
  echo
  tmp_dir="$(mktemp -d)"
  (
    cd "$tmp_dir"
    set -x
    curl -#fOL "https://github.com/cdr/code-server/releases/download/v${VERSION}/code-server_${VERSION}_$ARCH.deb"
  )

  echo
  (
    set -x
    $sudo dpkg -i "$tmp_dir/code-server_${VERSION}_$ARCH.deb"
  )
  rm -Rf "$tmp_dir"

  echo
  echo_systemd_postinstall
}

install_rpm() {
  set_sudo

  echo "Installing v$VERSION rpm package from GitHub releases."
  echo
  tmp_dir="$(mktemp -d)"
  (
    cd "$tmp_dir"
    set -x
    curl -#fOL "https://github.com/cdr/code-server/releases/download/v${VERSION}/code-server-${VERSION}-$ARCH.rpm"
  )

  echo
  (
    set -x
    $sudo rpm -i "$tmp_dir/code-server-$VERSION-$ARCH.rpm"
  )
  rm -Rf "$tmp_dir"

  echo
  echo_systemd_postinstall
}

install_arch() {
  set_sudo

  echo "Installing from the AUR."
  echo
  tmp_dir="$(mktemp -d)"
  (
    cd "$tmp_dir"
    set -x
    git clone https://aur.archlinux.org/code-server.git
  )

  echo
  (
    cd "$tmp_dir/code-server"
    set -x
    makepkg -si
  )
  rm -Rf "$tmp_dir"

  echo
  echo_systemd_postinstall
}

install_static() {
  echo static
}

# os prints the detected operating system.
#
# Example outputs:
# - macos
# - debian, ubuntu, raspbian
# - centos, fedora, rhel, opensuse
# - alpine
# - arch
#
# Inspired by https://github.com/docker/docker-install/blob/26ff363bcf3b3f5a00498ac43694bf1c7d9ce16c/install.sh#L111-L120.
os() {
  if [ "$(uname)" = "Darwin" ]; then
    echo "macos"
    return
  fi

  if [ ! -f /etc/os-release ]; then
    return
  fi

  (
    . /etc/os-release
    case "$ID" in opensuse-*)
      # opensuse's ID's look like opensuse-leap and opensuse-tumbleweed.
      echo "opensuse"
      return
      ;;
    esac

    echo "$ID"
  )
}

# os_name prints a human readable name for the OS.
os_name() {
  if [ "$(uname)" = "Darwin" ]; then
    echo "macOS v$(sw_vers -productVersion)"
    return
  fi

  if [ ! -f /etc/os-release ]; then
    return
  fi

  (
    . /etc/os-release
    echo "$PRETTY_NAME"
  )
}

arch() {
  case "$(uname -m)" in
  aarch64)
    echo arm64
    ;;
  x86_64)
    echo amd64
    ;;
  esac
}

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

echo_systemd_postinstall() {
  cat <<EOF
To have systemd start code-server now and restart on boot:
  systemctl --user enable --now code-server
Or, if you don't want/need a background service you can run:
  code-server
EOF
}

set_sudo() {
  user="$(id -un 2>/dev/null || true)"
  if [ "$user" = "root" ]; then
    sudo=""
    return
  fi

  if command_exists sudo; then
    sudo="sudo -E"
  elif command_exists su; then
    sudo="su -c"
  else
    echo "This installer needs the ability to run commands as root."
    echo "Please run as root or install sudo or su."
    exit 1
  fi
}

main "$@"
