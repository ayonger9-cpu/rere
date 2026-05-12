#!/bin/bash
# ========================================================
# update-bin.sh
#
# Update wrapper CLI account manager dari fork. Idempotent — aman
# dipanggil berkali-kali.
#
# Layout (match install.sh persis):
#   sshman                            → /usr/local/bin
#   vmessman / vlessman / trojanman   → /usr/local/sbin
#
# Cleanup behavior: kalau ada copy stray di lokasi yg "salah"
# (misal /usr/local/bin/vmessman dari update-bin.sh versi sebelumnya
# yg keliru install ke /bin), di-hapus supaya PATH lookup gak
# nge-resolve ke copy lama.
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

# Per-binary destination + stray location.
#   dest_for      = lokasi resmi (match install.sh)
#   stray_for     = lokasi yg HARUS di-cleanup kalau ada copy nyangkut
dest_for() {
  case "$1" in
    sshman) echo "/usr/local/bin" ;;
    vmessman|vlessman|trojanman) echo "/usr/local/sbin" ;;
  esac
}
stray_for() {
  case "$1" in
    sshman) echo "/usr/local/sbin/sshman" ;;
    vmessman|vlessman|trojanman) echo "/usr/local/bin/$1" ;;
  esac
}

BINS=(sshman vmessman vlessman trojanman)
UPDATED=0
FAILED=0

for f in "${BINS[@]}"; do
  url="${HOSTING}/${f}"
  tmp="$(mktemp)"
  if curl -fsSL "$url" -o "$tmp"; then
    d="$(dest_for "$f")"
    install -m 0755 "$tmp" "${d}/${f}"
    say "OK  -> ${d}/${f}"
    stray="$(stray_for "$f")"
    if [ -n "$stray" ] && [ -e "$stray" ]; then
      rm -f "$stray"
      say "removed stray $stray"
    fi
    rm -f "$tmp"
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
# Plus log lokasi yg PATH lookup user akan resolve — supaya kalau ada
# mismatch ke-spot di sini.
for f in "${BINS[@]}"; do
  via_path="$(command -v "$f" 2>/dev/null || true)"
  installed="$(dest_for "$f")/${f}"
  if [ -x "$installed" ]; then
    "$installed" >/dev/null 2>&1 || true
  fi
  if [ -z "$via_path" ]; then
    say "WARN: \`$f\` gak ke-resolve di PATH (\$PATH=$PATH). Installed at $installed."
  elif [ "$via_path" != "$installed" ]; then
    say "WARN: \`$f\` PATH resolve ke $via_path, tapi install ke $installed. Cek PATH order."
  else
    say "resolved \`$f\` -> $via_path"
  fi
done

say "Wrapper CLI sekarang udah support arg [mode 0/1/2] untuk auto-quota."
say "  sshman   add <user> <pass> [iplimit] [mode]"
say "  vmessman / vlessman / trojanman  add <user> [days] [mode]"
say "Override default 100/250 GB lewat /usr/local/etc/quota-mode.conf."
