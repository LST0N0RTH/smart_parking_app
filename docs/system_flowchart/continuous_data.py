"""Nodes and connections for one continuous vertical system flow."""


def build(Node, Edge):
    nodes = []

    def n(key, kind, y, *lines, lane="backend", side="main", h=130,
          uncertain=False):
        x, w = {
            "main": (925, 650),
            "left": (90, 640),
            "right": (1770, 640),
        }[side]
        nodes.append(Node(key, kind, x, y, w, h, tuple(lines), lane, uncertain))

    # Main line: start to finish, always moving downward.
    n("START", "start", 250, "เริ่ม: ระบบ Smart Parking", lane="app", h=90)
    n("A1", "io", 420, "ผู้ใช้เข้าสู่ระบบ", "ขอสถานะช่อง M/N/O", lane="app", h=120)
    n("B1", "process", 610, "Backend ตรวจสิทธิ์", "ตอบ GET /slots", h=120)
    n("DB1", "database", 800, "อ่าน Slots", "available / reserved / occupied", h=120)
    n("A2", "io", 990, "เลือกช่อง รถ เวลา", "และวิธีชำระเงิน", lane="app")
    n("D1", "decision", 1190, "ข้อมูลจอง + ช่องว่าง", "ผ่านเงื่อนไข?", h=160)
    n("B2", "database", 1410, "บันทึก Booking / Payment pending", "Slot=reserved + Entry QR", h=140)
    n("A3", "document", 1620, "เว็บแอปแสดงรหัสจอง", "และ QR ทางเข้า", lane="app")
    n("D2", "decision", 1820, "ยกเลิกก่อนเข้า", "หรือ no-show +30 นาที?", h=160)
    n("H1", "io", 2050, "IR1 + IR2 ก่อน Servo ทางเข้า", "ESP32-CAM ส่ง gate/event", lane="hardware", uncertain=True)
    n("D3", "decision", 2240, "payload มี IR1+IR2", "vehicle_detected=true?", h=160)
    n("A4", "io", 2470, "เปิดลิงก์ QR ทางเข้า", "GET /scan/{token}", lane="app")
    n("D4", "decision", 2660, "QR / เวลา / Booking", "คู่ IR ผ่านและไม่มี override?", h=160)
    n("B3", "process", 2890, "Backend บันทึก open ทางเข้า", "MQTT parking/servo/command")
    n("H2", "process", 3080, "ESP32-CAM รับคำสั่ง", "สั่ง Servo ตัวเดียวเปิดทางเข้า", lane="hardware", uncertain=True)
    n("H3", "io", 3270, "IR3 หลัง Servo ทางเข้า", "ส่ง gate_closed", lane="hardware", uncertain=True)
    n("D5", "decision", 3460, "IR3 ตรง command_id", "QR และ Booking?", h=160)
    n("B4", "database", 3690, "บันทึก entered_at", "ส่ง booking update")
    n("V1", "io", 3890, "Webcam บริเวณช่อง M/N/O", "อ่านภาพจริงต่อเนื่อง", lane="vision")
    n("V2", "process", 4080, "median 7 ภาพ + เทียบภาพว่าง", "วิเคราะห์ทุก 30 วินาที", lane="vision")
    n("B5", "io", 4270, "MQTT parking/slot/vision", "Backend รับผล occupied M/N/O")
    n("D6", "decision", 4460, "ภาพ + Booking ทำให้", "สถานะช่องเปลี่ยน?", h=160)
    n("B6", "database", 4690, "บันทึก SlotStatus + log", "occupied / reserved / available")
    n("A5", "io", 4880, "เว็บแอปแสดงสถานะช่อง", "ผู้ใช้เข้าสู่หน้าชำระเงิน", lane="app")
    n("D7", "decision", 5070, "วิธีชำระ", "PromptPay หรือบัตร?", h=160)
    n("D8", "decision", 5520, "entered_at มี", "Payment ยัง pending?", h=160)
    n("B7", "database", 5750, "บันทึก paid + ready_to_exit", "overstay +50 เมื่อเกินเวลา", h=140)
    n("A6", "document", 5960, "เว็บแอปแสดงใบเสร็จ", "และ QR ทางออก", lane="app")
    n("H4", "io", 6160, "IR4 + IR5 ก่อน Servo ทางออก", "ESP32-CAM ส่ง gate/event", lane="hardware", uncertain=True)
    n("D9", "decision", 6350, "payload มี IR4+IR5", "vehicle_detected=true?", h=160)
    n("A7", "io", 6580, "เปิดลิงก์ QR ทางออก", "GET /scan/{token}", lane="app")
    n("D10", "decision", 6770, "Exit QR ใช้ได้ + paid", "คู่ IR และไม่มี override?", h=160)
    n("B8", "process", 7000, "Backend บันทึก open ทางออก", "MQTT parking/servo/command")
    n("H5", "process", 7190, "ESP32-CAM รับคำสั่ง", "สั่ง Servo ตัวเดิมเปิดทางออก", lane="hardware", uncertain=True)
    n("H6", "io", 7380, "IR6 หลัง Servo ทางออก", "ส่ง gate_closed", lane="hardware", uncertain=True)
    n("D11", "decision", 7570, "IR6 ตรง command_id", "QR + paid + Booking?", h=160)
    n("B9", "database", 7800, "บันทึก completed / exited_at", "Slot=available", h=140)
    n("B10", "process", 8010, "Backend ส่ง WROOM set_status", "และ WebSocket /ws/slots")
    n("END", "end", 8210, "จบการจอดหนึ่งรายการ", lane="app", h=90)

    # Attached parallel work and rejection paths. No separate section frames.
    n("ADMIN", "io", 420, "Admin Dashboard", "เลือก Servo / RGB override", lane="app", side="right", h=120)
    n("ADMIN_CMD", "process", 610, "Backend ส่ง MQTT override", "ESP32-CAM / ESP32-WROOM", side="right", h=120)
    n("ADMIN_ACK", "process", 800, "รับ ACK / heartbeat", "บันทึก logs / no_response 5 วินาที", side="right", h=120)
    n("REJECT_BOOK", "end", 1190, "ปฏิเสธการจอง", "แสดงเหตุผล", lane="app", side="right")
    n("LED_RESERVED", "process", 1410, "ESP32-WROOM รับ set_status", "RGB LED ช่องที่จอง (คาดหวัง)", lane="hardware", side="right", uncertain=True)
    n("CANCEL", "database", 1820, "ยกเลิก pending / เพิกถอน QR", "Slot=available", side="left")
    n("CANCEL_END", "end", 2010, "จบรายการที่ไม่เข้า", "ส่ง WROOM + WebSocket", lane="app", side="left", h=120)
    n("WAIT_ENTRY", "process", 2240, "รอรถที่จุดตรวจ", "ยังไม่เปิด Servo", lane="hardware", side="right")
    n("REJECT_ENTRY", "end", 2660, "แจ้งเหตุผล / สแกนใหม่", "ไม่ส่งคำสั่งเปิดไม้กั้น", lane="app", side="left")
    n("IGNORE_ENTRY", "end", 3460, "เพิกเฉยต่อเหตุการณ์", "ไม่บันทึกเวลาเข้า", side="left")
    n("CALIB", "document", 3890, "ต้องมี calibration + ภาพว่างจริง", "ROI ของ M/N/O", lane="vision", side="left", uncertain=True)
    n("UNCHANGED", "process", 4460, "คงสถานะช่องเดิม", "อ่านภาพรอบถัดไป", lane="vision", side="right")
    n("LED_CHANGED", "process", 4690, "ESP32-WROOM รับ set_status", "RGB LED ช่องที่เปลี่ยน (คาดหวัง)", lane="hardware", side="right", uncertain=True)
    n("PAY_QR", "document", 5290, "QR ที่แอปเรียก PromptPay", "เปิด GET /scan/{token}", lane="app", side="left")
    n("PAY_CARD", "io", 5290, "เลือกบัตรที่บันทึก", "POST /payments/confirm", lane="app", side="right")
    nodes.append(Node("PAY_MERGE", "connector", 1222, 5435, 56, 56, ("P",)))
    n("REJECT_PAY", "end", 5520, "ปฏิเสธการชำระ", "แจ้งเงื่อนไข", lane="app", side="left")
    n("PAY_EVENT", "io", 5750, "Backend ส่ง payment/event", "เป้าหมาย ESP32-CAM", side="right")
    n("WAIT_EXIT", "process", 6350, "รอรถทางออก", "ยังไม่เปิด Servo", lane="hardware", side="right")
    n("REJECT_EXIT", "end", 6770, "แจ้งเหตุผล / สแกนใหม่", "ไม่เปิดไม้กั้น", lane="app", side="left")
    n("IGNORE_EXIT", "end", 7570, "เพิกเฉยต่อเหตุการณ์", "ไม่ปิดรายการจอด", side="left")
    n("LED_AVAILABLE", "process", 8010, "ESP32-WROOM รับ available", "RGB LED ช่องเดิม (คาดหวัง)", lane="hardware", side="right", uncertain=True)

    edges = []

    def e(a, b, label, ap="bottom", bp="top", via=(), lx=0, ly=0,
          dashed=False):
        edges.append(Edge(a, b, ap, bp, tuple(via), label, lx, ly, dashed))

    # The main path has no phase breaks. All transitions have a source label.
    main = (
        ("START", "A1", "ผู้ใช้เริ่มใช้งาน"),
        ("A1", "B1", "HTTP"),
        ("B1", "DB1", "อ่านช่อง"),
        ("DB1", "A2", "สถานะช่อง"),
        ("A2", "D1", "POST /bookings"),
        ("D1", "B2", "ผ่าน"),
        ("B2", "A3", "Entry QR"),
        ("A3", "D2", "รอเข้าใช้"),
        ("D2", "H1", "ยังไม่ยกเลิก"),
        ("H1", "D3", "parking/gate/event"),
        ("D3", "A4", "คู่ IR พร้อม"),
        ("A4", "D4", "HTTP GET"),
        ("D4", "B3", "ผ่าน"),
        ("B3", "H2", "MQTT open"),
        ("H2", "H3", "Servo เปิด / รถผ่าน"),
        ("H3", "D5", "IR3 gate_closed"),
        ("D5", "B4", "ตรงกัน"),
        ("B4", "V1", "ระหว่างรถจอด; Vision ทำงานต่อเนื่อง"),
        ("V1", "V2", "ภาพจริง"),
        ("V2", "B5", "occupied M/N/O"),
        ("B5", "D6", "ตรวจ payload"),
        ("D6", "B6", "สถานะเปลี่ยน"),
        ("B6", "A5", "WebSocket"),
        ("A5", "D7", "เลือกชำระ"),
        ("D8", "B7", "ผ่าน"),
        ("B7", "A6", "Exit QR"),
        ("A6", "H4", "รถมาถึงทางออก"),
        ("H4", "D9", "parking/gate/event"),
        ("D9", "A7", "คู่ IR พร้อม"),
        ("A7", "D10", "HTTP GET"),
        ("D10", "B8", "ผ่าน"),
        ("B8", "H5", "MQTT open"),
        ("H5", "H6", "Servo เดิม / รถผ่าน"),
        ("H6", "D11", "IR6 gate_closed"),
        ("D11", "B9", "ตรงกัน"),
        ("B9", "B10", "สถานะ available"),
        ("B10", "END", "แจ้งช่องว่าง"),
    )
    dashed_targets = {"H2", "H3", "D5", "H5", "H6", "D11"}
    for a, b, label in main:
        y = (next(x for x in nodes if x.key == a).y
             + next(x for x in nodes if x.key == a).h
             + next(x for x in nodes if x.key == b).y) // 2
        e(a, b, label, lx=1440, ly=y+5, dashed=b in dashed_targets)

    e("START", "ADMIN", "ผู้ดูแลทำงานขนาน", "right", "top",
      ((2090, 295),), 1935, 282)
    e("ADMIN", "ADMIN_CMD", "Admin API", lx=2250, ly=580)
    e("ADMIN_CMD", "ADMIN_ACK", "ACK / timeout", lx=2250, ly=770, dashed=True)
    e("D1", "REJECT_BOOK", "ไม่ผ่าน", "right", "left", lx=1690, ly=1255)
    e("B2", "LED_RESERVED", "MQTT set_status=reserved", "right", "left",
      lx=1690, ly=1390, dashed=True)
    e("D2", "CANCEL", "ยกเลิก / no-show", "left", "right", lx=805, ly=1885)
    e("CANCEL", "CANCEL_END", "คืนช่อง", lx=630, ly=1990)
    e("D3", "WAIT_ENTRY", "ไม่ครบคู่", "right", "left", lx=1690, ly=2305)
    e("WAIT_ENTRY", "H1", "ตรวจ IR ใหม่", "right", "right",
      ((2440, 2305), (2440, 1995), (1650, 1995), (1650, 2115)),
      2060, 1980, True)
    e("D4", "REJECT_ENTRY", "ไม่ผ่าน", "left", "right", lx=805, ly=2725)
    e("D5", "IGNORE_ENTRY", "ไม่ตรง", "left", "right", lx=805, ly=3525)
    e("CALIB", "V1", "ไฟล์จริง", "right", "left", lx=815, ly=3935)
    e("V2", "V1", "อ่านภาพรอบถัดไป", "left", "left",
      ((790, 4145), (790, 3955)), 772, 4055, True)
    e("D6", "UNCHANGED", "ไม่เปลี่ยน", "right", "left", lx=1690, ly=4525)
    e("UNCHANGED", "A5", "ไปชำระ", "left", "right",
      ((1650, 4525), (1650, 4945)), 1700, 4860)
    e("B6", "LED_CHANGED", "MQTT set_status", "right", "left",
      lx=1690, ly=4670, dashed=True)
    e("D7", "PAY_QR", "PromptPay", "left", "top",
      ((800, 5150), (800, 5250), (410, 5250)), 615, 5235)
    e("D7", "PAY_CARD", "บัตร", "right", "top",
      ((1700, 5150), (1700, 5250), (2090, 5250)), 1890, 5235)
    e("PAY_QR", "PAY_MERGE", "QR scan", "bottom", "left",
      ((410, 5463),), 800, 5448)
    e("PAY_CARD", "PAY_MERGE", "confirm API", "bottom", "right",
      ((2090, 5463),), 1700, 5448)
    e("PAY_MERGE", "D8", "คำขอยืนยันชำระ", lx=1440, ly=5510)
    e("D8", "REJECT_PAY", "ไม่ผ่าน", "left", "right", lx=805, ly=5585)
    e("B7", "PAY_EVENT", "MQTT payment_paid", "right", "left",
      lx=1690, ly=5730)
    e("D9", "WAIT_EXIT", "ไม่ครบคู่", "right", "left", lx=1690, ly=6415)
    e("WAIT_EXIT", "H4", "ตรวจ IR ใหม่", "right", "right",
      ((2440, 6415), (2440, 6105), (1650, 6105), (1650, 6225)),
      2050, 6090, True)
    e("D10", "REJECT_EXIT", "ไม่ผ่าน", "left", "right", lx=805, ly=6835)
    e("D11", "IGNORE_EXIT", "ไม่ตรง", "left", "right", lx=805, ly=7635)
    e("B10", "LED_AVAILABLE", "MQTT set_status=available", "right", "left",
      lx=1690, ly=7990, dashed=True)

    return nodes, edges
