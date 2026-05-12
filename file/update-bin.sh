#!/bin/bash
# ========================================================
# update-bin.sh
#
# Update wrapper CLI account manager (sshman, vmessman, vlessman, trojanman)
# di /usr/local/bin dari fork. Idempotent — aman dipanggil berkali-kali.
#
# Cara pakai (1 baris dari fork main):
#   bash <(curl -sL https://raw.githubusercontent.com/ayonger9-cpu/rere/main/file/update-bin.sh)
#
# Override host (mis. mau tarik dari branch lain atau fork lain):
#   HOSTING="https://raw.githubusercontent.com/ayonger9-cpu/rere/<branch>/file" \
#     bash <(curl -sL "${HOSTING}/update-bin.sh")
# ========================================================

set -e

HOSTING="${HOSTING:-https://raw.githubusercontent.com/ayonger9-cpu/rere/main/file}"
DEST="${DEST:-/usr/local/bin}"

say() { echo "[update-bin] $*"; }

if [ "$(id -u)" -ne 0 ]; then
  say "ERROR: jalanin sebagai root (script tulis ke $DEST)."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  say "ERROR: curl tidak ditemukan. Install dulu: apt-get install -y curl"
  exit 1
fi

mkdir -p "$DEST"

BINS=(sshman vmessman vlessman trojanman)
UPDATED=0
FAILED=0

for f in "${BINS[@]}"; do
  url="${HOSTING}/${f}"
  tmp="$(mktemp)"
  if curl -fsSL "$url" -o "$tmp"; then
    install -m 0755 "$tmp" "${DEST}/${f}"
    rm -f "$tmp"
    say "OK  -> ${DEST}/${f}"
    UPDATED=$(( UPDATED + 1 ))
  else
    rm -f "$tmp"
    say "GAGAL download $f dari $url"
    FAILED=$(( FAILED + 1 ))
  fi
done

say "Selesai. Updated: $UPDATED, Gagal: $FAILED."

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi

# Smoke test ringan: usage harusnya muncul (exit non-zero karena no args itu wajar).
for f in "${BINS[@]}"; do
  if [ -x "${DEST}/${f}" ]; then
    "${DEST}/${f}" >/dev/null 2>&1 || true
  fi
done

say "Wrapper CLI sekarang udah support arg [mode 0/1/2] untuk auto-quota."
say "  sshman   add <user> <pass> [iplimit] [mode]"
say "  vmessman / vlessman / trojanman  add <user> [days] [mode]"
say "Override default 100/250 GB lewat /usr/local/etc/quota-mode.conf."
