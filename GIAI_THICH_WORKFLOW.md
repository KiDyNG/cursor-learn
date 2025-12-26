# GIẢI THÍCH WORKFLOW "TRỢ LÝ CHÍNH"

## 📋 TỔNG QUAN

Workflow này là một **AI Assistant (Trợ lý AI)** được xây dựng trên n8n, hoạt động như một chatbot thông minh cho xưởng nội thất MinhKhoa. Workflow nhận tin nhắn từ Telegram/Zalo, xử lý qua AI Agent, và trả lời người dùng với khả năng học hỏi và tìm kiếm thông tin.

---

## 🔄 LUỒNG HOẠT ĐỘNG CHÍNH

### **1. ĐIỂM VÀO (Entry Point)**

#### **Node: `chat_bot` (Webhook)**
- **Loại**: Webhook (POST)
- **Chức năng**: Nhận tin nhắn từ bot Telegram/Zalo
- **Path**: `2c429418-efa2-4357-ba0a-c02758bbd000`
- **Output**: Dữ liệu tin nhắn từ người dùng (text, voice, image, document)

---

### **2. PHÂN LOẠI ĐẦU VÀO (Input Classification)**

#### **Node: `Switch`**
- **Loại**: Switch (điều kiện phân nhánh)
- **Chức năng**: Phân loại loại tin nhắn nhận được
- **5 nhánh output**:
  1. **Voice**: Nếu có `message.voice.file_id` → Gửi đến `Download Voice`
  2. **Text**: Nếu có `message.text` → Gửi đến `Input`
  3. **Image Only**: Nếu có `message.photo_url` (không có caption) → Gửi đến `Download Image`
  4. **Documents**: Nếu có `message.from.id` → Gửi đến `Download Documents`
  5. **Image + Caption**: Nếu có `message.photo_url` (có caption) → Gửi đến `Download Image`

---

### **3. XỬ LÝ ĐẦU VÀO (Input Processing)**

#### **A. Xử lý Voice**
- **`Download Voice`**: Tải file voice từ URL
- **`Transcribe a recording`**: Chuyển đổi voice → text bằng Google Gemini
- **→** Kết quả text được gửi đến `Input`

#### **B. Xử lý Image**
- **`Download Image`**: Tải ảnh từ URL
- **`Fix Input Item`**: Sửa lỗi MIME type (jpg → jpeg)
- **`Analyze an image`**: Phân tích ảnh bằng Google Gemini Vision
- **→** Kết quả được gửi đến `Input`

#### **C. Xử lý Documents**
- **`Download Documents`**: Tải file tài liệu
- **`Edit Fields`**: Chuẩn hóa metadata (file_id, file_name, file_size, mime_type, extension, caption)
- **`Switch2`**: Phân loại theo MIME type:
  - PDF → `Analyze document`
  - Image → `Analyze document`
  - CAD files → `If File Size < 20MB` → `CAD to PDF` (chuyển đổi CAD sang PDF)
- **`Analyze document`**: Phân tích tài liệu bằng Google Gemini
- **→** Kết quả được gửi đến `Input`

#### **D. Xử lý Text**
- Trực tiếp gửi đến `Input`

---

### **4. CHUẨN BỊ DỮ LIỆU (Data Preparation)**

#### **Node: `Input`**
- **Loại**: Set (chuẩn hóa dữ liệu)
- **Chức năng**: Chuẩn bị input chuẩn cho AI Agent
- **Output fields**:
  - `content`: Nội dung text
  - `type`: Loại input (text/image/document)
  - `prompt`: Prompt cho AI
  - `metadata`: Metadata bổ sung
  - `imageUrl`: URL ảnh (nếu có)

#### **Node: `Prepare Smart Search`**
- **Loại**: Code (JavaScript)
- **Chức năng**: Phân tích intent và quyết định có cần tìm kiếm web không
- **Logic**:
  - Phát hiện từ khóa: "giá thị trường", "xu hướng", "tin tức", "đối thủ" → Cần web search
  - Tạo query tìm kiếm phù hợp
- **Output**: `needWebSearch`, `webSearchQuery`, `searchType`

---

### **5. TÌM KIẾM KIẾN THỨC (Knowledge Search)**

#### **A. Tìm kiếm RAG (Retrieval Augmented Generation)**
- **Node: `Search Knowledge`**
  - **Loại**: Execute Workflow
  - **Workflow**: "Tool - RAG Knowledge"
  - **Chức năng**: Tìm kiếm trong cơ sở kiến thức đã học
  - **Input**: `query`, `action: "search"`

#### **B. Tìm kiếm Web (nếu cần)**
- **Node: `If`**: Kiểm tra `needWebSearch === true`
- **Node: `Search Tavily`**:
  - **Loại**: Tavily Search Tool
  - **Chức năng**: Tìm kiếm thông tin từ web
  - **Options**: `search_depth: basic`, `max_results: 5`, `include_answer: advanced`
- **Node: `Check Tavily Quality`**: Đánh giá chất lượng kết quả
- **Node: `If Good Result`**: Nếu kết quả tốt → `Auto Save Web Knowledge` (tự động lưu vào RAG)

#### **C. Merge Context**
- **Node: `Merge Context`**
  - **Loại**: Code (JavaScript)
  - **Chức năng**: Gộp kết quả RAG + Web search vào context
  - **Output**: `learningContext` (kiến thức đã học + thông tin từ web)

---

### **6. AI AGENT CHÍNH (Main AI Agent)**

#### **Node: `Tro ly chinh`**
- **Loại**: LangChain Agent
- **Model**: Google Gemini 2.0 Flash (qua OpenRouter)
- **Memory**: MongoDB Chat Memory (lưu lịch sử hội thoại)
- **Tools** (các công cụ có thể gọi):
  1. **`Tro ly ke toan`**: Trợ lý kế toán (báo giá, tính toán, sản phẩm)
  2. **`Tro ly Email`**: Trợ lý email
  3. **`Tro ly lich`**: Trợ lý lịch (Google Calendar)
  4. **`Tro ly ky thuat`**: Trợ lý kỹ thuật (bản vẽ, CAD)
  5. **`Think`**: Tool suy nghĩ (không thay đổi DB, chỉ ghi log)
  6. **`Search in Tavily`**: Tìm kiếm web (Tavily Tool)

#### **System Prompt chính**:
- **Vai trò**: DISPATCHER (Điều phối viên), KHÔNG tự trả lời
- **Quy tắc**: Luôn gọi tool phù hợp thay vì tự trả lời
- **Bảng gọi tool bắt buộc**:
  - Báo giá, tính giá → `Tro ly ke toan`
  - Tồn kho → `Tro ly kho`
  - Tiến độ, thi công → `Tro ly thi cong`
  - Email → `Tro ly Email`
  - Lịch hẹn → `Tro ly lich`
  - Bản vẽ, kỹ thuật → `Tro ly ky thuat`

#### **Output**: 
- `output`: Câu trả lời từ AI
- `intermediateSteps`: Các bước trung gian (tools đã gọi)

---

### **7. XỬ LÝ KẾT QUẢ (Result Processing)**

#### **A. Clean Up & Logging**
- **Node: `Clean Up`**
  - **Loại**: Code (JavaScript)
  - **Chức năng**: Trích xuất thông tin từ `intermediateSteps`
  - **Output**: 
    - `steps`: Danh sách tools đã gọi
    - `tokens`: Thống kê token usage
    - `total_tokens`: Tổng số token
- **Node: `Agent Log`**
  - **Loại**: Google Sheets (Append)
  - **Chức năng**: Ghi log vào Google Sheets
  - **Fields**: timestamp, user_id, input, output, tools, tokens, etc.

#### **B. Phát hiện kiến thức mới**
- **Node: `Detect New Knowledge`**
  - **Loại**: Code (JavaScript)
  - **Chức năng**: Phát hiện khi người dùng muốn dạy kiến thức mới
  - **Patterns**: "nhớ là", "ghi nhớ", "từ giờ", "quy định mới", "sai rồi, đúng là..."
  - **Output**: `shouldLearn`, `contentToLearn`, `category`

- **Node: `If Should Learn`**: Nếu `shouldLearn === true`
  - **Node: `Execute Save to RAG`**
    - **Loại**: Execute Workflow
    - **Workflow**: "Tool - RAG Knowledge"
    - **Action**: `save`
    - **Chức năng**: Lưu kiến thức mới vào RAG database

#### **C. Phân tích Response Type**
- **Node: `Analyze and Get link`**
  - **Loại**: Code (JavaScript)
  - **Chức năng**: 
    - Trích xuất URLs (ảnh, PDF) từ output
    - Tìm mã báo giá (BG-xxxxx-xxx)
    - Xác định `response_mode`: `all` | `image` | `pdf` | `text`
    - Làm sạch text (xóa RESPONSE_TYPE tag, xóa links đã gửi riêng)

---

### **8. GỬI PHẢN HỒI (Send Response)**

#### **Node: `Has Image?`**
- **Loại**: If (điều kiện)
- **Chức năng**: Kiểm tra có ảnh cần gửi không
- **Điều kiện**: `imageUrl` exists AND `response_mode !== "pdf"` AND `response_mode !== "text"`

#### **Node: `Has PDF?`**
- **Loại**: If (điều kiện)
- **Chức năng**: Kiểm tra có PDF cần gửi không
- **Điều kiện**: `pdfUrl` exists

#### **Các node gửi tin nhắn**:

1. **`Send Photo`**
   - Gửi ảnh với caption: "📋 Báo giá {quoteNumber}"
   - Chỉ gửi khi có `imageUrl` và `response_mode !== "pdf"`

2. **`Send PDF`**
   - Gửi PDF qua Telegram API
   - Chỉ gửi khi có `pdfUrl`

3. **`Split Text`**
   - **Loại**: Code (JavaScript)
   - **Chức năng**: Chia text thành nhiều phần nếu quá dài (>4000 ký tự)
   - **Logic**: Chia theo câu, mỗi phần ~4000 ký tự

4. **`Send Text`**
   - Gửi text message
   - Gửi từng phần nếu đã được split

---

### **9. XỬ LÝ LỖI (Error Handling)**

- **Node: `Error Message1`**: Gửi thông báo lỗi khi Agent lỗi
- **Node: `Error Message`**: Gửi thông báo lỗi chung
- **Node: `Send Processing Message` / `Send Processing Message2`**: Gửi "typing..." indicator

---

## 📊 CÁC NODE CHÍNH VÀ CHỨC NĂNG

### **Input Nodes**
1. **`chat_bot`** - Webhook nhận tin nhắn
2. **`Switch`** - Phân loại loại tin nhắn
3. **`Input`** - Chuẩn hóa dữ liệu đầu vào

### **Processing Nodes**
4. **`Download Voice/Image/Documents`** - Tải file
5. **`Transcribe a recording`** - Voice → Text
6. **`Analyze an image/document`** - Phân tích ảnh/tài liệu
7. **`Prepare Smart Search`** - Phân tích intent
8. **`Search Knowledge`** - Tìm kiếm RAG
9. **`Search Tavily`** - Tìm kiếm web
10. **`Merge Context`** - Gộp context

### **AI Agent Nodes**
11. **`Tro ly chinh`** - AI Agent chính (LangChain)
12. **`MongoDB Chat Memory`** - Lưu lịch sử hội thoại
13. **`Think`** - Tool suy nghĩ
14. **`Tro ly ke toan`** - Tool workflow kế toán
15. **`Tro ly Email`** - Tool workflow email
16. **`Tro ly lich`** - Tool workflow lịch
17. **`Tro ly ky thuat`** - Tool workflow kỹ thuật

### **Output Processing Nodes**
18. **`Clean Up`** - Trích xuất thông tin từ steps
19. **`Agent Log`** - Ghi log vào Google Sheets
20. **`Detect New Knowledge`** - Phát hiện kiến thức mới
21. **`Execute Save to RAG`** - Lưu kiến thức mới
22. **`Analyze and Get link`** - Phân tích response type
23. **`Has Image?` / `Has PDF?`** - Kiểm tra loại response
24. **`Send Photo/PDF/Text`** - Gửi phản hồi

---

## 🔧 LOGIC XỬ LÝ DỮ LIỆU

### **1. Luồng xử lý tin nhắn Text**
```
chat_bot → Switch (Text) → Input → Prepare Smart Search → 
Search Knowledge → [If needWebSearch] Search Tavily → 
Merge Context → Tro ly chinh → Detect New Knowledge → 
[If shouldLearn] Execute Save to RAG → Analyze and Get link → 
Has Image? → Has PDF? → Send Photo/PDF/Text
```

### **2. Luồng xử lý tin nhắn Voice**
```
chat_bot → Switch (Voice) → Download Voice → 
Transcribe a recording → Input → ... (giống Text)
```

### **3. Luồng xử lý tin nhắn Image**
```
chat_bot → Switch (Image) → Download Image → Fix Input Item → 
Analyze an image → Input → ... (giống Text)
```

### **4. Luồng xử lý Documents**
```
chat_bot → Switch (Documents) → Download Documents → 
Edit Fields → Switch2 (theo MIME type) → 
[PDF/Image] Analyze document → 
[CAD] If File Size < 20MB → CAD to PDF → 
Input → ... (giống Text)
```

### **5. Luồng học kiến thức mới**
```
Tro ly chinh → Detect New Knowledge → 
If Should Learn → Execute Save to RAG → 
[Auto] Auto Save Web Knowledge (nếu có kết quả web tốt)
```

---

## 🎯 ĐẶC ĐIỂM NỔI BẬT

1. **Multi-modal Input**: Hỗ trợ text, voice, image, documents
2. **Smart Search**: Tự động quyết định tìm kiếm RAG hoặc Web
3. **Auto Learning**: Tự động phát hiện và lưu kiến thức mới
4. **Tool-based Architecture**: Agent không tự trả lời, luôn gọi tool phù hợp
5. **Context-aware**: Merge RAG + Web search vào context
6. **Rich Response**: Hỗ trợ gửi text, ảnh, PDF, sticker
7. **Logging**: Ghi log đầy đủ vào Google Sheets
8. **Error Handling**: Xử lý lỗi và thông báo người dùng

---

## 📝 GHI CHÚ

- Workflow sử dụng **LangChain Agent** với **Google Gemini 2.0 Flash** làm LLM chính
- Memory được lưu trong **MongoDB** với session key là user ID
- RAG Knowledge được lưu trong workflow riêng: "Tool - RAG Knowledge"
- Web search sử dụng **Tavily API**
- Bot API: Telegram/Zalo (Zalo Platform)

