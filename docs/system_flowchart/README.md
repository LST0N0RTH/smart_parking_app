# System Flowchart — Coolkids Smart Parking

ผังงานนี้มี **เส้นทางหลักแนวตั้งเส้นเดียวต่อเนื่อง** จากเริ่มระบบ → จอง → รถเข้า → ตรวจช่อง → ชำระ → รถออก → จบรายการ กิ่งด้านข้างคือทางปฏิเสธ การยกเลิก และงานที่ทำขนานกัน ไม่มีกรอบแบ่งเป็นผังย่อย เนื้อหาอ้างอิงโค้ดปัจจุบันของ `smart_parking_app`, `smart_parking_backend` และ `smart_parking_photo_vision` ณ วันที่ 18 ตุลาคม 2026 ไม่มีการสร้างข้อมูลรถ การจอง ผลภาพ หรือผลเซนเซอร์ขึ้นมาเพื่อประกอบผัง

## ไฟล์ส่งมอบ

- `system_flowchart.svg` — ภาพเวกเตอร์สำหรับอ่าน ขยาย และใส่รายงาน
- `system_flowchart.drawio` — ผังที่แก้ข้อความและตำแหน่งได้ใน diagrams.net
- `system_flowchart.png` — ภาพตัวอย่างความละเอียดสูงสำหรับเปิดดูทันที
- `continuous_data.py` — รายการขั้นตอนและลูกศรของผังเดียว
- `build_flowchart.py` — สร้าง SVG และ draw.io จากรายการข้างต้น

เมื่อแก้ข้อความใน `continuous_data.py` ให้รัน `python3 build_flowchart.py` จากโฟลเดอร์นี้เพื่อสร้าง SVG และ draw.io ใหม่ แล้วเรนเดอร์ PNG จาก SVG อีกครั้งก่อนส่งงาน

## วิธีอ่าน

อ่านจากบนลงล่างตามเส้นทางกลาง วงรีหมายถึงเริ่ม/จบ, สี่เหลี่ยมหมายถึงกระบวนการ, สี่เหลี่ยมด้านขนานหมายถึงข้อมูลเข้า/ออก, ข้าวหลามตัดหมายถึงการตัดสินใจ, ทรงกระบอกหมายถึงการบันทึก/อ่านฐานข้อมูล, รูปเอกสารหมายถึง QR/ไฟล์ และวงกลม `P` คือจุดรวมทางเลือกชำระเงิน เส้นประรอบอุปกรณ์และลูกศรอุปกรณ์หมายถึง **อินเทอร์เฟซที่ฝั่งซอฟต์แวร์คาดหวัง แต่ยังไม่มีเฟิร์มแวร์ให้ตรวจยืนยันการทำงานจริง**

Vision ทำงานต่อเนื่องเป็นอิสระจากการบันทึก `entered_at` และรายงานผลทุก 30 วินาที ผังวางขั้นวิเคราะห์ภาพไว้ระหว่าง “รถเข้า” กับ “ชำระเงิน” เพื่อให้อ่านรายการจอดหนึ่งรายการต่อเนื่องกัน; ลูกศรวนกลับระบุการอ่านภาพรอบถัดไป กิ่ง Admin ด้านขวาบนเป็นงานขนานที่เริ่มได้ระหว่างระบบทำงาน

## หลักฐานจากโค้ดรายช่วง

| ช่วงในผัง | สิ่งที่ยืนยันได้ | หลักฐาน |
|---|---|---|
| จองช่อง | เว็บขอสถานะช่องผ่าน `GET /slots`; Backend รับการจองเมื่อเวลา รถ และช่องผ่านเงื่อนไข แล้วบันทึก `Booking`, `Payment(pending)`, `Slot(reserved)` และ Entry QR | `smart_parking_app/lib/services/api_service.dart:250-275,414-452`; `smart_parking_app/lib/screens/booking_screen.dart:125-209`; `smart_parking_backend/main.py:4197-4203,4234-4460` |
| LED ช่องจอด | Backend ส่ง `set_status` ของ M/N/O ไป `parking/slot/{slot}/command` โดยระบุ `esp32_wroom` เป็นอุปกรณ์เป้าหมาย | `smart_parking_backend/main.py:3029-3056,3109-3154` |
| เซนเซอร์ทางเข้า | Backend รับ `parking/gate/event` จาก `esp32_cam`; เหตุการณ์ก่อนกั้นใช้ `IR1/IR2` และยืนยันคู่จาก `active_sensors` หรือ `sensor_states` ร่วมกับ `vehicle_detected=true` | `smart_parking_backend/main.py:1363-1375,3443-3457,3616-3677` |
| QR และ Servo ทางเข้า | QR ที่แอปแสดงบรรจุ URL `/scan/{token}`; Backend ตรวจ token/เวลา/booking/คู่ IR/Admin override ก่อนบันทึกคำสั่ง `open` ไป `parking/servo/command` พร้อม `close_sensor=IR3` | `smart_parking_app/lib/screens/booking_screen.dart:197-209,357`; `smart_parking_backend/main.py:1794-1809,2982-3027,3058-3082,3459-3519,5012-5192` |
| ผ่านไม้กั้นเข้า | Backend รับ `gate_closed` ที่ `IR3`; ก่อนบันทึก `entered_at` ตรวจ `command_id`, QR ที่ใช้แล้ว และ booking ให้ตรงกัน | `smart_parking_backend/main.py:3521-3583,3653-3687` |
| Webcam | ต้องมีไฟล์ calibration และภาพอ้างอิงจริง; โปรแกรมอ่าน Webcam, ใช้ median 7 ภาพ, วิเคราะห์ ROI ของ M/N/O ทุก 30 วินาที แล้วส่ง `parking/slot/vision` | `smart_parking_photo_vision/slot_vision/slot_camera_calibration.py:252-329`; `smart_parking_photo_vision/slot_vision/slot_vision_service.py:20-24,55-90,279-300,333-350,363-436` |
| สถานะช่อง | Backend ตรวจผลภาพและ Booking ปัจจุบัน: ภาพพบรถหรือ booking ที่ `entered_at` แล้ว → `occupied`; มี booking แต่ยังไม่เข้า → `reserved`; ไม่มี → `available` (เว้น Admin override) จากนั้นบันทึก log, ส่งคำสั่ง WROOM และ broadcast `/ws/slots` | `smart_parking_backend/main.py:3156-3298`; `smart_parking_app/lib/providers/parking_provider.dart:316-435` |
| ชำระเงิน | ชำระได้เมื่อ `entered_at` มีค่าและ Payment ยัง `pending`; การยืนยัน API หรือการเปิด URL ของ QR ที่แอปเรียก PromptPay ทำให้ Backend บันทึก `paid`, คิดค่าจอดเกินเวลา 50 บาทเมื่อเข้าเงื่อนไข, เปลี่ยน booking เป็น `ready_to_exit`, ออก Exit QR และส่ง `parking/payment/event` | `smart_parking_app/lib/screens/payment_screen.dart:129-216,459-509`; `smart_parking_backend/main.py:1932-2020,4648-4741,4860-5010,5193-5248` |
| ทางออก | คู่ก่อนกั้นคือ `IR4/IR5`; Backend ตรวจ Exit QR และ `paid` ก่อนสั่ง Servo ตัวเดิมเปิด; รับ `gate_closed` ที่ `IR6` แล้วบันทึก `completed`, `exited_at`, Slot=`available`, ส่ง WROOM command และ WebSocket | `smart_parking_backend/main.py:3443-3457,3459-3519,3521-3610,3653-3687,5249-5318` |
| งานขนานและทางเลือก | ยกเลิกก่อนรถเข้าหรือ no-show หลังเวลาเริ่ม 30 นาที → คืนช่อง/ยกเลิก pending/เพิกถอน QR; Admin ส่ง Servo/RGB override; Backend บันทึก ACK, heartbeat, logs และสถานะ `no_response` เมื่อไม่มี ACK ภายใน 5 วินาที | `smart_parking_backend/main.py:1111-1160,1856-1929,2631-2730,2732-2775,3301-3389,4474-4544,6242-6343` |

## อุปกรณ์ทั้งหมดตามคำขอ

| อุปกรณ์ | บทบาทในผัง |
|---|---|
| ESP32-CAM 1 ตัว **ถอดกล้องออก** | ชื่ออุปกรณ์ฝั่ง Backend สำหรับเหตุการณ์ IR ทางเข้า/ทางออกและคำสั่ง Servo; **ไม่แสดงการอ่านภาพหรือสแกน QR ด้วยบอร์ดนี้** |
| IR1, IR2 | คู่ก่อน Servo ที่ทางเข้า; ผู้ใช้ระบุว่าอยู่ตรงข้าม IR3 และ IR6 |
| IR3 | หลัง Servo ทางเข้าที่ Backend ยอมรับเหตุการณ์ `gate_closed`; ผู้ใช้ระบุว่าอยู่ตรงข้าม IR4/IR5 |
| IR4, IR5 | คู่ก่อน Servo ที่ทางออก; ผู้ใช้ระบุว่าอยู่ตรงข้าม IR3 และ IR6 |
| IR6 | หลัง Servo ทางออกที่ Backend ยอมรับเหตุการณ์ `gate_closed`; ผู้ใช้ระบุว่าอยู่ตรงข้าม IR1/IR2 |
| Servo Motor 1 ตัว | คำสั่งเปิดทางเข้าและทางออกใช้ topic เดียวกัน; ผังระบุว่าเป็น Servo ตัวเดียวตามรายการฮาร์ดแวร์ของผู้ใช้ |
| ESP32-WROOM 1 ตัว | เป้าหมายของ `set_status` สำหรับช่อง M/N/O |
| RGB LED 3 ตัว | ตัวละหนึ่งช่อง M, N, O; โค้ด Backend ส่งเพียงสถานะ `available/reserved/occupied` |
| Webcam 1 ตัวบริเวณ Slot | ภาพจริงสำหรับโปรแกรม `slot_vision_service.py` ที่ตรวจ M/N/O |

การเปิด QR ในผังหมายถึง HTTP `GET /scan/{token}` ที่เกิดจากการเปิดลิงก์ใน QR เท่านั้น โค้ดสามส่วนนี้ **ไม่ได้ระบุรุ่นหรืออุปกรณ์ที่ใช้เปิดลิงก์** จึงไม่ใส่เครื่องสแกนหรือกล้องเพิ่มในรายการฮาร์ดแวร์

## ข้อจำกัดที่ต้องคงไว้เมื่อนำไปใช้ต่อ

1. ไม่พบซอร์สเฟิร์มแวร์ ESP32 ในสามโฟลเดอร์ที่ให้ตรวจ จึงยืนยัน **รูปแบบคำสั่ง/เหตุการณ์ที่ Backend ส่งหรือรับ** ได้ แต่ยืนยันมุม Servo การเคลื่อนไหวจริง การจับคู่ IR ในไมโครคอนโทรลเลอร์ และสีจริงของ RGB LED ไม่ได้ เส้นประในผังแยกส่วนนี้ไว้ชัดเจน
2. ไม่พบ `slot_vision/runtime/slot_calibration.json` หรือภาพอ้างอิง `slot_empty_reference.png` ในโฟลเดอร์ Vision ปัจจุบัน โปรแกรม Vision จะหยุดหากไม่มีไฟล์ปรับเทียบดังกล่าว (`slot_vision_service.py:55-90,333-345`) ผังแสดงขั้นตอนปรับเทียบที่ต้องทำกับกล้องจริง
3. โค้ดแอปเรียก QR ชำระว่า “PromptPay” แต่ QR ที่สร้างคือ URL ของ Backend `/scan/{token}` และ endpoint นี้ตั้งสถานะ `paid` เอง (`main.py:1794-1809,5193-5248`) ส่วน `POST /payments/confirm` ก็ตั้งสถานะ `paid` สำหรับวิธีอื่นใน Backend (`main.py:4648-4741`) ไม่พบการตรวจผลโอนจากธนาคารหรือ payment gateway ในสามส่วนที่ตรวจ ดังนั้น `paid` ในผังหมายถึง **สถานะในฐานข้อมูล** เท่านั้น
4. Backend มี topic `parking/gate/display` และชื่อ `oled` ในรายการอุปกรณ์ที่รู้จัก (`main.py:1363-1396,2301-2336`) แต่ผู้ใช้ไม่ได้ระบุ OLED ในฮาร์ดแวร์ชุดนี้ จึงไม่วาด OLED เป็นอุปกรณ์ในผัง
5. ผังนี้อธิบายพฤติกรรมที่อ่านได้จากโค้ด ไม่ใช่ผลทดสอบกับรถและอุปกรณ์จริง ไม่มีการจำลองข้อมูลหรือสร้างตัวอย่างค่าจากเซนเซอร์

ไฟล์ SVG และ draw.io ผ่านการตรวจโครงสร้าง XML; PNG ถูกเรนเดอร์จาก SVG เพื่อตรวจข้อความ สัญลักษณ์ และลูกศรก่อนส่ง
