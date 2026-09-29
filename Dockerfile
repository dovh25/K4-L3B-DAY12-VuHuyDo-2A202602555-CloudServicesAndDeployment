# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization
# Multi-stage build cho production
# ═══════════════════════════════════════════════════════════════════

# Stage 1: Builder
FROM python:3.11-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy các package đã cài đặt từ builder
COPY --from=builder /install /usr/local

# Tạo non-root user appuser
RUN useradd --create-home --uid 10001 appuser

# Copy mã nguồn ứng dụng
COPY . .

# Phân quyền cho appuser
RUN chown -R appuser:appuser /app

# Chuyển sang user thường
USER appuser

EXPOSE 8000

# Healthcheck gọi endpoint /health
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import os, urllib.request; port = os.environ.get('PORT', '8000'); urllib.request.urlopen(f'http://127.0.0.1:{port}/health').read()" || exit 1

# Khởi chạy uvicorn đọc cổng từ biến môi trường PORT (mặc định 8000)
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
