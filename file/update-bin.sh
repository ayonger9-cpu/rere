#!/bin/bash
# ========================================================
# update-bin.sh
#
# Update wrapper CLI account manager (sshman, vmessman, vlessman, trojanman)
# di /usr/local/bin DAN /usr/local/sbin dari fork. Idempotent — aman
# dipanggil berkali-kali.
#
# Kenapa dua lokasi:
#   install.sh aslinya naro sshman di /usr/local/bin tapi vmessman /
#   vlessman / trojanman di /usr/local/sbin. Bergantung PATH (biasanya
#   /sbin sebelum /bin di root shell), bare `vmessman` bisa resolve ke
#   /usr/local/sbin/vmessman — jadi kalau update cuma /bin doang, copy
#   lama di /sbin yg ke-jalanin. Solusi paling robust: tulis ke dua-
#   duanya sehingga either-or lookup PATH selalu dapet versi baru.
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
DESTS=(/usr/local/bin /usr/local/sbin)

say() { echo "[update-bin] $*"; }

if [ "$(id -u)" -ne 0 ]; then
  say "ERROR: jalanin sebagai root (script tulis ke ${DESTS[*]})."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  say "ERROR: curl tidak ditemukan. Install dulu: apt-get install -y curl"
  exit 1
fi

for d in "${DESTS[@]}"; do mkdir -p "$d"; done

BINS=(sshman vmessman vlessman trojanman)
UPDATED=0
FAILED=0

for f in "${BINS[@]}"; do
  url="${HOSTING}/${f}"
  tmp="$(mktemp)"
  if curl -fsSL "$url" -o "$tmp"; then
    for d in "${DESTS[@]}"; do
      install -m 0755 "$tmp" "${d}/${f}"
      say "OK  -> ${d}/${f}"
    done
    rm -f "$tmp"
    UPDATED=$(( UPDATED + 1 ))
  else
    rm -f "$tmp"
    say "GAGAL download $f dari $url"
    FAILED=$(( FAILED + 1 ))
  fi
done

# Verifikasi: bandingin checksum di dua lokasi (harus identik).
for f in "${BINS[@]}"; do
  a="/usr/local/bin/${f}"; b="/usr/local/sbin/${f}"
  if [ -f "$a" ] && [ -f "$b" ]; then
    ha="$(md5sum "$a" | awk '{print $1}')"
    hb="$(md5sum "$b" | awk '{print $1}')"
    if [ "$ha" != "$hb" ]; then
      say "WARN: ${f} md5 berbeda di bin vs sbin (bin=$ha sbin=$hb)"
    fi
  fi
done

say "Selesai. Updated: $UPDATED, Gagal: $FAILED."

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi

# Smoke test ringan: usage harusnya muncul (exit non-zero karena no args itu wajar).
for f in "${BINS[@]}"; do
  resolved="$(command -v "$f" 2>/dev/null || true)"
  [ -z "$resolved" ] && resolved="/usr/local/bin/${f}"
  if [ -x "$resolved" ]; then
    "$resolved" >/dev/null 2>&1 || true
    say "resolved \`$f\` -> $resolved (via PATH)"
  fi
done

say "Wrapper CLI sekarang udah support arg [mode 0/1/2] untuk auto-quota."
say "  sshman   add <user> <pass> [iplimit] [mode]"
say "  vmessman / vlessman / trojanman  add <user> [days] [mode]"
say "Override default 100/250 GB lewat /usr/local/etc/quota-mode.conf."
