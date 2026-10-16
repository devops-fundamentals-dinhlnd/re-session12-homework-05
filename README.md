# BÁO CÁO THỰC HÀNH: CHẨN ĐOÁN VÀ KHẮC PHỤC 3 SỰ CỐ ĐỨT GÃY PIPELINE CI/CD THỰC TẾ

---

- **Môn học**: DevOps Fundamentals (IT-209)
- **Session**: 12 - Tối ưu hóa CI/CD Pipeline
- **Bài tập**: Bài 5 - Chẩn đoán và khắc phục 3 sự cố đứt gãy Pipeline CI/CD thực tế
- **Học viên**: Lu Nhựt Đình
- **Email**: dinhlunhut@gmail.com
- **Đường dẫn gợi ý nộp bài**: `homework/session_12/ex5/`
- **Tài liệu chẩn đoán sự cố chi tiết**: [troubleshooting.md](troubleshooting.md)

---

## 1. MỤC TIÊU VÀ YÊU CẦU

### 1.1. Mục tiêu
- Rèn luyện kỹ năng đọc hiểu nhật ký lỗi (Console Logs) trên GitHub Actions Runner.
- Xác định nguyên nhân gốc rễ (Root Cause Analysis) của các lỗi thường gặp trong môi trường CI/CD thực tế.
- Khắc phục triệt để các sự cố liên quan đến phân quyền hệ thống tệp, bảo mật chứng chỉ đăng nhập và ngữ cảnh bản dựng container.

### 1.2. 3 sự cố thực tế được xử lý
1. **Lỗi 1 (Permission Denied)**: `gradlew` thiếu cờ thực thi trên Linux runner -> Khắc phục bằng lệnh `chmod +x gradlew`.
2. **Lỗi 2 (Authentication Failed)**: Sai chính tả tên biến secret `REGISTRY_TOKEN` -> Khắc phục bằng việc sửa đúng tên biến và bổ sung `permissions: packages: write`.
3. **Lỗi 3 (Build Context Error)**: Không tìm thấy tệp `Dockerfile` do chỉ định sai thư mục `context` -> Khắc phục bằng cấu hình `context: .` và `file: ./Dockerfile`.

---

## 2. CẤU TRÚC THƯ MỤC DỰ ÁN

```
Ss12/5/
├── .github/
│   └── workflows/
│       └── broken-pipeline.yml  # Kịch bản GitHub Actions đã sửa hoàn chỉnh 3 lỗi
├── gradle/
│   └── wrapper/
│       ├── gradle-wrapper.jar   # Gradle wrapper executable
│       └── gradle-wrapper.properties # Cấu hình phiên bản Gradle (9.5.1)
├── src/
│   ├── main/
│   │   ├── java/com/example/tasks/
│   │   └── resources/
│   └── test/
│       ├── java/com/example/tasks/
│       └── resources/
├── .gitignore
├── build.gradle
├── Dockerfile                   # Dockerfile tại thư mục gốc (.)
├── gradlew / gradlew.bat
├── settings.gradle
├── troubleshooting.md           # Báo cáo phân tích chi tiết từng lỗi (Yêu cầu nộp bài)
└── README.md                    # Tài liệu tổng quan bài 5
```

---

## 3. NỘI DUNG KỊCH BẢN ĐÃ SỬA LỖI (`.github/workflows/broken-pipeline.yml`)

```yaml
name: CI/CD Pipeline (Fixed)

on:
  push:
    branches: [ "main" ]
  workflow_dispatch:

permissions:
  contents: read
  packages: write

jobs:
  test:
    name: Run Unit Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout mã nguồn
        uses: actions/checkout@v5

      - name: Thiết lập môi trường Java JDK 17
        uses: actions/setup-java@v5
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: 'gradle'

      # [FIXED LỖI 1]: Cấp quyền thực thi cho Gradle Wrapper trước khi chạy kiểm thử
      - name: Cấp quyền thực thi cho Gradle Wrapper
        run: chmod +x gradlew

      - name: Thực thi kiểm thử JUnit với Gradle
        run: ./gradlew test

  build-and-push:
    name: Build & Push Docker Image
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Checkout mã nguồn
        uses: actions/checkout@v5

      - name: Thiết lập Docker Buildx
        uses: docker/setup-buildx-action@v3

      # [FIXED LỖI 2]: Sửa đúng chính tả tên biến Secret REGISTRY_TOKEN (kèm fallback GITHUB_TOKEN)
      - name: Đăng nhập vào GitHub Container Registry (GHCR)
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.REGISTRY_TOKEN || secrets.GITHUB_TOKEN }}

      - name: Trích xuất Docker Metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=raw,value=latest
            type=sha,format=short

      # [FIXED LỖI 3]: Cấu hình context: . và file: ./Dockerfile đúng vị trí thư mục gốc
      - name: Đóng gói và đẩy Docker Image lên GHCR
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

---

## 4. HƯỚNG DẪN TỰ ĐẨY CODE VÀ NỘP BÀI

```bash
# Di chuyển vào thư mục bài 5
cd "d:\[IT-209] DevOps Fundamentals\Ss12\5"

# Khởi tạo git và push nhánh main
git init
git checkout -b main
git add .
git commit -m "fix: resolve 3 critical pipeline issues (permission, secret typo, and docker context)"
git remote add origin https://github.com/<your-username>/<your-repo-name>.git
git push -u origin main
```

Sau khi push lên GitHub:
1. Mở tab **Actions** kiểm tra pipeline chạy thành công tích xanh (**Success**).
2. Chụp ảnh màn hình giao diện pipeline tích xanh (lưu vào `Ss12/5/` ví dụ `pipeline_success.png`).
3. Sản phẩm nộp bài gồm:
   - Tệp kịch bản `.github/workflows/broken-pipeline.yml` đã sửa.
   - Tệp báo cáo `troubleshooting.md`.
   - Ảnh chụp màn hình kết quả tích xanh.
