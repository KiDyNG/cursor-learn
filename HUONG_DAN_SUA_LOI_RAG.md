# HƯỚNG DẪN SỬA LỖI WORKFLOW "TOOL - RAG KNOWLEDGE"

## 📋 TỔNG QUAN

Đã thực hiện 3 thay đổi chính:
1. ✅ Tạo hàm SQL RPC `match_knowledge` cho Supabase
2. ✅ Sửa node "Search Supabase" - đổi URL endpoint
3. ✅ Sửa node "Format Search Result" - thêm xử lý lỗi an toàn

---

## 🔧 BƯỚC 1: TẠO HÀM RPC TRONG SUPABASE

### **Cách thực hiện:**

1. **Mở Supabase Dashboard** → Vào project của bạn
2. **Vào SQL Editor** (menu bên trái)
3. **Copy toàn bộ code** từ file `supabase_match_knowledge_function.sql`
4. **Paste vào SQL Editor** và chạy (Run)

### **Code SQL đã tạo:**

```sql
CREATE OR REPLACE FUNCTION match_knowledge(
  query_embedding vector(768),
  match_threshold float DEFAULT 0.6,
  match_count int DEFAULT 5
)
RETURNS TABLE (
  id bigint,
  content text,
  category text,
  similarity float,
  metadata jsonb
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    knowledge.id,
    knowledge.content,
    knowledge.category,
    1 - (knowledge.embedding <=> query_embedding) as similarity,
    knowledge.metadata
  FROM knowledge
  WHERE 1 - (knowledge.embedding <=> query_embedding) > match_threshold
  ORDER BY knowledge.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
```

### **Lưu ý quan trọng:**

- **Vector dimension**: Code mặc định là `vector(768)` cho model `text-embedding-004` của Google
- Nếu bạn dùng model khác, cần thay đổi:
  - `text-embedding-004` = 768 dimensions
  - `text-embedding-3-small` = 512 dimensions
  - `text-embedding-3-large` = 1024 dimensions
- **Đảm bảo extension pgvector đã được enable**:
  ```sql
  CREATE EXTENSION IF NOT EXISTS vector;
  ```

### **Kiểm tra hàm đã tạo:**

```sql
-- Kiểm tra hàm có tồn tại không
SELECT proname, proargnames, prorettype 
FROM pg_proc 
WHERE proname = 'match_knowledge';
```

---

## 🔧 BƯỚC 2: KIỂM TRA NODE "SEARCH SUPABASE"

### **Thay đổi đã thực hiện:**

✅ **URL endpoint** đã được đổi từ:
```
https://zamexodnbxgmazdnajtd.supabase.co/rest/v1/rpc/search_knowledge
```

Thành:
```
https://zamexodnbxgmazdnajtd.supabase.co/rest/v1/rpc/match_knowledge
```

### **Body parameters** (đã đúng, không cần sửa):
```json
{
  "query_embedding": [...],  // Array embedding từ Google
  "match_threshold": 0.6,     // Ngưỡng độ tương đồng (0-1)
  "match_count": 5            // Số kết quả tối đa
}
```

### **Kiểm tra trong n8n:**

1. Mở workflow "Tool - RAG Knowledge"
2. Click vào node **"Search Supabase"**
3. Kiểm tra:
   - ✅ URL: `.../rest/v1/rpc/match_knowledge`
   - ✅ Method: `POST`
   - ✅ Headers: có `apikey`, `Authorization`, `Content-Type`
   - ✅ Body: có `query_embedding`, `match_threshold`, `match_count`

---

## 🔧 BƯỚC 3: KIỂM TRA NODE "FORMAT SEARCH RESULT"

### **Cải tiến đã thực hiện:**

✅ **Thêm try-catch toàn bộ** để xử lý lỗi an toàn
✅ **Xử lý các trường hợp:**
- Supabase trả về lỗi (error object)
- Supabase trả về null/undefined
- Kết quả rỗng (empty array)
- Lỗi khi parse dữ liệu
- Lỗi không mong đợi

✅ **Output luôn có format chuẩn:**
```json
{
  "success": true/false,
  "action": "search",
  "message": "Text tóm tắt kết quả",
  "query": "Câu query gốc",
  "results": [...],
  "error": "Chi tiết lỗi (nếu có)"
}
```

### **Logic xử lý:**

1. **Try-catch bọc toàn bộ code**
2. **Kiểm tra lỗi từ Supabase**: Nếu có `error` property → trả về `success: false`
3. **Kiểm tra null/undefined**: Nếu không có kết quả → trả về `success: false`
4. **Parse kết quả linh hoạt**: Xử lý nhiều định dạng có thể:
   - Array trực tiếp
   - Object có property `data`
   - Object đơn
5. **Format từng item an toàn**: Try-catch cho từng item, bỏ qua item lỗi
6. **Tạo text tóm tắt**: Format thành chuỗi text dễ đọc

### **Ví dụ output:**

**Khi thành công:**
```json
{
  "success": true,
  "action": "search",
  "message": "Tìm thấy 3 thông tin liên quan:\n\n1. [pricing] Giá gỗ sồi là 500.000 VNĐ/m2 (độ khớp: 85.2%)\n2. [material] Gỗ sồi có độ bền cao (độ khớp: 78.5%)\n3. [product] Tủ quần áo gỗ sồi (độ khớp: 72.1%)",
  "query": "giá gỗ sồi",
  "results": [...]
}
```

**Khi lỗi:**
```json
{
  "success": false,
  "action": "search",
  "message": "Lỗi khi tìm kiếm: connection timeout",
  "query": "giá gỗ sồi",
  "results": [],
  "error": "connection timeout"
}
```

**Khi không có kết quả:**
```json
{
  "success": false,
  "action": "search",
  "message": "Không tìm thấy thông tin liên quan đến: \"giá gỗ sồi\"",
  "query": "giá gỗ sồi",
  "results": []
}
```

---

## 🧪 KIỂM TRA VÀ TEST

### **Test 1: Kiểm tra hàm SQL**

```sql
-- Test với vector giả (768 dimensions)
SELECT * FROM match_knowledge(
  query_embedding := ARRAY[0.1, 0.2, ...]::vector(768),  -- Thay bằng vector thật
  match_threshold := 0.6,
  match_count := 5
);
```

### **Test 2: Test workflow trong n8n**

1. **Test với action = "search"**:
   ```json
   {
     "query": "giá gỗ sồi",
     "action": "search"
   }
   ```

2. **Kiểm tra output**:
   - Node "Search Supabase" có trả về kết quả không?
   - Node "Format Search Result" có xử lý đúng không?
   - Output có format `{ success: true/false, ... }` không?

3. **Test với trường hợp lỗi**:
   - Tạm thời đổi URL sai → Kiểm tra "Format Search Result" có bắt lỗi không?
   - Kiểm tra output có `success: false` và message lỗi không?

---

## ⚠️ LƯU Ý QUAN TRỌNG

1. **Vector dimension**: Đảm bảo khớp với model embedding bạn dùng
2. **Supabase API Key**: Đảm bảo API key còn hợp lệ
3. **Table structure**: Đảm bảo table `knowledge` có đúng cấu trúc:
   - `id` (bigint)
   - `content` (text)
   - `category` (text)
   - `embedding` (vector)
   - `metadata` (jsonb)
4. **Extension pgvector**: Phải enable trong Supabase
5. **Index vector**: Nên tạo index cho cột `embedding` để tìm kiếm nhanh:
   ```sql
   CREATE INDEX ON knowledge USING ivfflat (embedding vector_cosine_ops);
   ```

---

## 📝 TÓM TẮT THAY ĐỔI

| Thành phần | Trước | Sau |
|------------|-------|-----|
| **Hàm SQL** | `search_knowledge` (không tồn tại) | `match_knowledge` (đã tạo) |
| **URL endpoint** | `/rpc/search_knowledge` | `/rpc/match_knowledge` |
| **Format Search Result** | Không có try-catch, dễ crash | Có try-catch đầy đủ, xử lý lỗi an toàn |
| **Output khi lỗi** | Crash workflow | Trả về `{ success: false, ... }` |

---

## ✅ HOÀN TẤT

Sau khi thực hiện các bước trên:
1. ✅ Hàm SQL đã được tạo trong Supabase
2. ✅ Node "Search Supabase" đã được sửa
3. ✅ Node "Format Search Result" đã được cải thiện

Workflow sẽ hoạt động ổn định và không bị crash khi gặp lỗi!

