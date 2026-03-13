#!/bin/bash

# --- Konfigurasi Path ---
BASE_DIR="$(dirname "$0")/.."
INPUT_FILE="$BASE_DIR/input/domains.txt"
ALL_SUBS="$BASE_DIR/output/all-subdomains.txt"
LIVE_HOSTS="$BASE_DIR/output/live.txt"
PROGRESS_LOG="$BASE_DIR/logs/progress.log"
ERROR_LOG="$BASE_DIR/logs/errors.log"

# Pastikan folder output dan logs tersedia
mkdir -p "$BASE_DIR/output" "$BASE_DIR/logs"

# Fungsi untuk Logging dengan Timestamp
log_status() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$PROGRESS_LOG"
}

# --- Validasi Input ---
if [ ! -f "$INPUT_FILE" ]; then
    log_status "ERROR: File input $INPUT_FILE tidak ditemukan!"
    exit 1
fi

# Inisialisasi file output agar bersih di awal proses
> "$ALL_SUBS"
> "$LIVE_HOSTS"

log_status "=== Memulai Recon Otomatis ==="

# --- Proses Enumerasi Subdomain ---
while IFS= read -r domain || [ -n "$domain" ]; do
    # Skip baris kosong
    [[ -z "$domain" ]] && continue
    
    log_status "Sedang memproses: $domain"
    
    # Menjalankan assetfinder dan deduplikasi dengan anew
    # Stderr diarahkan ke errors.log
    assetfinder --subs-only "$domain" 2>>"$ERROR_LOG" | anew "$ALL_SUBS" >> "$PROGRESS_LOG"
    
    if [ $? -eq 0 ]; then
        log_status "Selesai enumerasi subdomain untuk $domain"
    else
        log_status "Terjadi kesalahan pada $domain (cek errors.log)"
    fi
done < "$INPUT_FILE"

# --- Verifikasi Live Hosts ---
log_status "Memulai verifikasi live hosts untuk semua subdomain..."

# httpx dengan flag:
# -sc (status code)
# -title (page title)
# -silent (mengurangi noise)
if [ -s "$ALL_SUBS" ]; then
    cat "$ALL_SUBS" | httpx -sc -title -silent 2>>"$ERROR_LOG" | anew "$LIVE_HOSTS" >> "$PROGRESS_LOG"
else
    log_status "INFO: Tidak ada subdomain ditemukan untuk dicek."
fi

# --- Statistik Akhir ---
UNIQUE_COUNT=$(wc -l < "$ALL_SUBS")
LIVE_COUNT=$(wc -l < "$LIVE_HOSTS")

log_status "=== Recon Selesai ==="
log_status "Total Subdomain Unik: $UNIQUE_COUNT"
log_status "Total Live Hosts: $LIVE_COUNT"
echo "--------------------------------------------------" | tee -a "$PROGRESS_LOG"
