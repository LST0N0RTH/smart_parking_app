#!/bin/bash
echo "🚀 Downloading Flutter (Turbo Mode)..."
# ใช้ --depth 1 เพื่อดึงแค่ไฟล์ที่จำเป็น เซิร์ฟเวอร์จะได้ไม่ทำงานหนักจนดับ
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

echo "🛠 Building Web App..."
flutter build web