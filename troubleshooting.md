# BÁO CÁO CHẨN ĐOÁN VÀ KHẮC PHỤC SỰ CỐ PIPELINE (TROUBLESHOOTING)

---

- **Môn học**: DevOps Fundamentals (IT-209)
- **Session**: 12 - Tối ưu hóa CI/CD Pipeline
- **Bài tập**: Bài 5 - Chẩn đoán và khắc phục 3 sự cố đứt gãy Pipeline CI/CD thực tế
- **Học viên**: Lu Nhựt Đình
- **Email**: dinhlunhut@gmail.com
- **Đường dẫn gợi ý nộp bài**: `homework/session_12/ex5/`
- **Tệp kịch bản được phân tích & khắc phục**: `.github/workflows/broken-pipeline.yml`

---

## 1. TỔNG QUAN TÌNH TRẠNG PIPELINE BAN ĐẦU

Pipeline CI/CD bao gồm 2 Job liên tiếp:
1. **Job `test`**: Thực thi biên dịch và kiểm thử đơn vị JUnit cho ứng dụng Spring Boot bằng Gradle Wrapper.
2. **Job `build-and-push`**: Đóng gói multi-stage Docker Image và đẩy lên GitHub Container Registry (`ghcr.io`).

Khi chạy trên GitHub Actions, quy trình gặp phải chuỗi 3 sự cố nghiêm trọng khiến pipeline liên tục bị đứt gãy (Failed/Red):
- **Sự cố 1 (Permission Denied)**: Job `test` thất bại ngay tại bước thực thi lệnh `./gradlew test`.
- **Sự cố 2 (Authentication Failed)**: Sau khi qua được bước test, Job `build-and-push` thất bại tại bước đăng nhập `docker/login-action@v3`.
- **Sự cố 3 (Build Context Error)**: Sau khi đăng nhập thành công, bước đóng gói `docker/build-push-action@v5` thất bại do không tìm thấy tệp Dockerfile.

---

## 2. PHÂN TÍCH VÀ KHẮC PHỤC CHI TIẾT 3 SỰ CỐ

### 2.1. SỰ CỐ 1: GRADLE WRAPPER THIẾU QUYỀN THỰC THI (PERMISSION DENIED)

#### A. Triệu chứng & Trích xuất Log lỗi:
```
Run ./gradlew test
/home/runner/work/_temp/08b792ce-8c5a-4b9d-a41e-64d852026857.sh: line 1: ./gradlew: Permission denied
Error: Process completed with exit code 126.
```

#### B. Nguyên nhân gốc rễ (Root Cause):
- Lập trình viên phát triển mã nguồn trên hệ điều hành Windows. Hệ thống tệp NTFS của Windows không quản lý các cờ quyền POSIX (`rwxr-xr-x`). Khi commit và đẩy tệp `gradlew` lên Git repository, tệp này chỉ mang thuộc tính tệp thông thường (`100644 - rw-r--r--`).
- Khi runner Ubuntu Linux (`ubuntu-latest`) checkout mã nguồn về không gian làm việc `$GITHUB_WORKSPACE`, tệp `gradlew` không có bit thực thi (`+x`). Khi lệnh `./gradlew test` được gọi, kernel Linux từ chối quyền thực thi và trả về mã lỗi `126 (Permission denied)`.

#### C. Biện pháp khắc phục:
Bổ sung một bước chạy lệnh `chmod +x gradlew` ngay trước khi thực thi `./gradlew test`.

#### D. So sánh mã nguồn (Diff):
```yaml
# ❌ TRƯỚC KHI SỬA (LỖI)
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-java@v5
        with:
          java-version: '17'
          distribution: 'temurin'
      - run: ./gradlew test

# ✅ SAU KHI SỬA (CHÍNH XÁC)
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-java@v5
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: 'gradle'
      - name: Cấp quyền thực thi cho Gradle Wrapper
        run: chmod +x gradlew
      - name: Thực thi kiểm thử JUnit với Gradle
        run: ./gradlew test
```

---

### 2.2. SỰ CỐ 2: LỖI ĐĂNG NHẬP DOCKER REGISTRY DO SAI TÊN BIẾN SECRET (AUTHENTICATION FAILED)

#### A. Triệu chứng & Trích xuất Log lỗi:
```
Run docker/login-action@v3
Logging into ghcr.io...
Error: Username and password are required
hoặc:
Error: Error response from daemon: Get "https://ghcr.io/v2/": unauthorized
Error: Process completed with exit code 1.
```

#### B. Nguyên nhân gốc rễ (Root Cause):
- Trong bước cấu hình `docker/login-action@v3`, tên biến bí mật bị viết sai chính tả, ví dụ:
  - Viết thiếu ký tự: `${{ secrets.REGISTY_TOKEN }}` (thiếu chữ `R`)
  - Viết sai tên đã cấu hình trong mục Repository Secrets.
- Trong GitHub Actions, khi tham chiếu đến một Secret không tồn tại, GitHub sẽ trả về chuỗi rỗng (`""`) mà không báo lỗi cú pháp. Khi `login-action` nhận mật khẩu rỗng, quá trình xác thực với máy chủ `ghcr.io` bị từ chối với lỗi `unauthorized` hoặc `password required`.

#### C. Biện pháp khắc phục:
1. Sửa lại chính xác tên biến Secret: `${{ secrets.REGISTRY_TOKEN }}`.
2. Áp dụng kỹ thuật Fallback an toàn: `${{ secrets.REGISTRY_TOKEN || secrets.GITHUB_TOKEN }}`.
3. Bổ sung khối khai báo quyền `permissions: packages: write` ở cấp độ workflow để `GITHUB_TOKEN` luôn được ủy quyền ghi Container Image lên GitHub Container Registry ngay cả khi chưa kịp cấu hình PAT thủ công.

#### D. So sánh mã nguồn (Diff):
```yaml
# ❌ TRƯỚC KHI SỬA (LỖI)
      - name: Đăng nhập Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.REGISTY_TOKEN }}   # <-- Sai chính tả

# ✅ SAU KHI SỬA (CHÍNH XÁC)
      - name: Đăng nhập vào GitHub Container Registry (GHCR)
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.REGISTRY_TOKEN || secrets.GITHUB_TOKEN }}
```

---

### 2.3. SỰ CỐ 3: KHÔNG TÌM THẤY DOCKERFILE DO SAI BUILD CONTEXT (BUILD CONTEXT ERROR)

#### A. Triệu chứng & Trích xuất Log lỗi:
```
Run docker/build-push-action@v5
#1 [internal] load build definition from Dockerfile
#1 ERROR: failed to solve: failed to read dockerfile: open /home/runner/work/Ss12_05/Ss12_05/app/Dockerfile: no such file or directory
Error: buildx failed with: ERROR: failed to solve: failed to read dockerfile: open /home/runner/work/Ss12_05/Ss12_05/app/Dockerfile: no such file or directory
Error: Process completed with exit code 1.
```

#### B. Nguyên nhân gốc rễ (Root Cause):
- Trong bước `docker/build-push-action@v5`, tham số `context` hoặc `file` bị chỉ định sai đường dẫn (ví dụ trỏ vào `./app` hoặc `./app/Dockerfile`).
- Tuy nhiên, trong cấu trúc repository của dự án, tệp `Dockerfile` nằm ngay tại thư mục gốc của repository (`.`). Do đó Docker daemon không thể định vị được tệp đặc tả bản dựng, dẫn đến lỗi biên dịch Buildx bị hủy bỏ.

#### C. Biện pháp khắc phục:
Cấu hình lại tham số ngữ cảnh bản dựng chính xác:
- `context: .` (thư mục gốc không gian làm việc hiện tại).
- `file: ./Dockerfile` (tệp Dockerfile nằm tại thư mục gốc).

#### D. So sánh mã nguồn (Diff):
```yaml
# ❌ TRƯỚC KHI SỬA (LỖI)
      - name: Build & Push Docker Image
        uses: docker/build-push-action@v5
        with:
          context: ./app              # <-- Sai ngữ cảnh làm việc
          file: ./app/Dockerfile      # <-- Không tìm thấy tệp
          push: true
          tags: ${{ steps.meta.outputs.tags }}

# ✅ SAU KHI SỬA (CHÍNH XÁC)
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

## 3. NỘI DUNG TỆP KỊCH BẢN HOÀN CHỈNH ĐÃ KHẮC PHỤC

Đường dẫn tệp: `.github/workflows/broken-pipeline.yml`

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

## 4. BẢNG TỔNG KẾT KHẮC PHỤC VÀ BÀI HỌC KINH NGHIỆM

| STT | Tên sự cố | Thông điệp lỗi chính | Nguyên nhân cốt lõi | Biện pháp xử lý triệt để |
| :---: | :--- | :--- | :--- | :--- |
| **1** | **Permission Denied** | `./gradlew: Permission denied` (Exit 126) | Tệp thiếu quyền thực thi POSIX khi checkout trên Linux | Thêm `run: chmod +x gradlew` hoặc chạy `git update-index --chmod=+x gradlew` |
| **2** | **Authentication Failed** | `unauthorized` / `Password required` (Exit 1) | Sai chính tả biến Secret (`REGISTY_TOKEN`) | Sửa đúng tên Secret, kết hợp fallback `GITHUB_TOKEN` và cấp quyền `packages: write` |
| **3** | **Build Context Error** | `failed to read dockerfile: no such file` (Exit 1) | Chỉ định sai thư mục `context` (`./app`) | Khai báo chính xác `context: .` và `file: ./Dockerfile` |

---

## 5. HƯỚNG DẪN TỰ ĐẨY CODE VÀ KIỂM TRA TÍCH XANH

```bash
# 1. Di chuyển vào thư mục bài 5
cd "d:\[IT-209] DevOps Fundamentals\Ss12\5"

# 2. Khởi tạo git và push nhánh main
git init
git checkout -b main
git add .
git commit -m "fix: resolve 3 critical pipeline issues (permission, secret typo, and docker context)"
git remote add origin https://github.com/<your-username>/<your-repo-name>.git
git push -u origin main
```

Sau khi push:
1. Mở tab **Actions** trên GitHub repository.
2. Theo dõi 2 Job `Run Unit Tests` và `Build & Push Docker Image` lần lượt vượt qua cả 3 điểm lỗi trước đó.
3. Xác nhận toàn bộ pipeline chuyển sang trạng thái tích xanh (**Success** :white_check_mark:).
4. Chụp ảnh màn hình giao diện pipeline tích xanh (lưu vào `Ss12/5/` ví dụ `pipeline_success.png`) để nộp bài cùng tệp `troubleshooting.md`.
