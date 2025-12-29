# 🚀 MINHKHOA AI - FULL OPTIMIZATION IMPLEMENTATION GUIDE

## 📦 FILES ĐÃ TẠO

1. ✅ `message_buffer_schema.sql` - SQL schema cho message buffer
2. ✅ `Zalo Gateway.json` - Workflow 1: Nhận webhook và buffer
3. ✅ `RAG Knowledge - Pinecone.json` - Workflow 3: RAG với Pinecone
4. ✅ `Message Processor - Update Guide.md` - Hướng dẫn cập nhật Workflow 2
5. ✅ `migrate_supabase_to_pinecone.js` - Script migration dữ liệu

---

## 🎯 IMPLEMENTATION ORDER

### BƯỚC 1: Setup Pinecone (10 phút)

1. **Tạo Pinecone account**
   - Truy cập: https://www.pinecone.io
   - Sign up (free tier available)

2. **Tạo Index**
   ```
   - Index Name: minhkhoa-knowledge
   - Dimensions: 768
   - Metric: cosine
   - Cloud: AWS
   - Region: us-east-1 (hoặc gần nhất)
   ```

3. **Lấy API Key**
   - Dashboard → API Keys
   - Copy API Key và Host

4. **Verify credentials trong prompt đã cung cấp**
   - API Key: `pcsk_cj2MU_Hv6o3ZKzx7ikncKrYr6cRGvq6w8Z88uCrNEs8unwbBtthEYmmvCWa5cUBxdZYgH`
   - Host: `minhkhoa-knowledge-db0pu9l.svc.aped-4627-b74a.pinecone.io`

---

### BƯỚC 2: Setup Supabase (5 phút)

1. **Mở Supabase Dashboard**
   - Truy cập: https://supabase.com/dashboard
   - Chọn project: `zamexodnbxgmazdnajtd`

2. **Chạy SQL Schema**
   - Vào SQL Editor
   - Copy toàn bộ nội dung từ `message_buffer_schema.sql`
   - Paste và chạy (Run)

3. **Verify functions đã tạo**
   ```sql
   SELECT proname FROM pg_proc 
   WHERE proname IN ('upsert_message_buffer', 'get_ready_buffers', 'lock_buffer', 'complete_buffer');
   ```

---

### BƯỚC 3: Import Workflows vào n8n (20 phút)

#### 3.1. Import Workflow 1: Zalo Gateway
1. Mở n8n
2. Workflows → Import from File
3. Chọn `Zalo Gateway.json`
4. **Lưu ý**: Webhook path vẫn giữ nguyên: `2c429418-efa2-4357-ba0a-c02758bbd000`
5. Activate workflow

#### 3.2. Import Workflow 3: RAG Knowledge - Pinecone
1. Workflows → Import from File
2. Chọn `RAG Knowledge - Pinecone.json`
3. **Lưu ý**: Verify Pinecone credentials trong nodes
4. Activate workflow
5. **Copy Workflow ID** (cần cho Workflow 2)

#### 3.3. Update Workflow 2: Message Processor
1. Mở workflow "Message Processor" hiện tại
2. Follow hướng dẫn trong `Message Processor - Update Guide.md`
3. **Quan trọng**: Update workflow ID của RAG Knowledge trong các nodes:
   - `Search Knowledge`
   - `Execute Save to RAG`
   - `Auto Save Web Knowledge`

---

### BƯỚC 4: Migration Data (30 phút)

#### 4.1. Export từ Supabase
```sql
SELECT content, category, created_at 
FROM knowledge 
ORDER BY created_at;
```

#### 4.2. Migrate sang Pinecone
1. Mở file `migrate_supabase_to_pinecone.js`
2. Paste data vào array `knowledge`
3. Chạy script (có thể dùng n8n Code node hoặc Node.js)
4. Verify trong Pinecone dashboard

---

### BƯỚC 5: Update Zalo Webhook (5 phút)

1. **Lấy webhook URL từ n8n**
   - Workflow "Zalo Gateway" → Webhook node
   - Copy webhook URL (ví dụ: `https://n8n-home.minhkhoaagent.top/webhook/2c429418-efa2-4357-ba0a-c02758bbd000`)

2. **Update trong Zalo Bot**
   - Zalo Developer Console
   - Bot Settings → Webhook URL
   - Paste URL mới

---

### BƯỚC 6: Testing (30 phút)

#### Test 1: Message Batching ✅
```
1. Gửi: "Tạo báo giá"
2. Gửi: "cho khách A" (trong 3 giây)
3. Gửi: "2 tủ quần áo" (trong 3 giây)
Expected: Tất cả được gộp thành 1 request
```

#### Test 2: Processing Indicator ✅
```
1. Gửi bất kỳ message nào
Expected: 
- Nhận "⏳ Đang xử lý..." ngay lập tức
- Sau đó nhận response thực tế
Total: 2 messages từ bot
```

#### Test 3: RAG Search (Pinecone) ✅
```
1. Trước tiên, save knowledge: "Giá gỗ sồi là 15 triệu/m3"
2. Sau đó search: "Giá gỗ sồi bao nhiêu?"
Expected: Trả về knowledge đã lưu với similarity score
```

#### Test 4: RAG Save (Pinecone) ✅
```
1. Gửi: "Nhớ là khách A thích màu trắng"
Expected: Knowledge được lưu vào Pinecone
Verify: Check Pinecone dashboard
```

#### Test 5: Full Quote Flow ✅
```
1. Gửi: "Tạo báo giá cho khách Nguyễn Văn A, 2 tủ quần áo 3 cánh"
Expected:
- "⏳ Đang xử lý..."
- [Quote Image]
- "📄 File PDF: ..."
- Summary text
```

---

## 🔧 TROUBLESHOOTING

### ❌ Pinecone Connection Error
```
Error: "Connection refused" hoặc "401 Unauthorized"
Solution:
1. Check PINECONE_API_KEY đúng chưa
2. Check PINECONE_HOST format (không có https://)
3. Verify index name và namespace match
```

### ❌ Embedding Dimension Mismatch
```
Error: "Vector dimension mismatch"
Solution:
1. Verify Pinecone index có dimension=768
2. Check Gemini embedding model = text-embedding-004
```

### ❌ Buffer Not Processing
```
Problem: Messages không được xử lý
Solution:
1. Check Supabase function get_ready_buffers
2. Verify status = 'buffering'
3. Check last_message_at timing (phải > 2 giây)
4. Check Schedule Trigger chạy mỗi 2 giây
```

### ❌ Empty RAG Results
```
Problem: RAG search không trả về kết quả
Solution:
1. Check data có trong Pinecone dashboard không
2. Lower score threshold từ 0.7 xuống 0.5 (trong Format Search Result node)
3. Verify namespace = 'minhkhoa'
4. Check embedding dimensions = 768
```

### ❌ Webhook Not Receiving
```
Problem: Zalo không gửi webhook
Solution:
1. Verify webhook URL đúng
2. Check n8n workflow "Zalo Gateway" đã activate chưa
3. Test webhook bằng curl:
   curl -X POST https://your-webhook-url \
     -H "Content-Type: application/json" \
     -d '{"body":{"message":{"text":"test"}}}'
```

---

## 📊 MONITORING

### Check Buffer Status
```sql
SELECT 
  status,
  COUNT(*) as count,
  AVG(EXTRACT(EPOCH FROM (last_message_at - first_message_at))) as avg_buffer_time
FROM message_buffer
WHERE created_at > NOW() - INTERVAL '1 hour'
GROUP BY status;
```

### Check Processing Time
```sql
SELECT 
  id,
  chat_id,
  merged_count,
  EXTRACT(EPOCH FROM (completed_at - first_message_at)) as total_seconds
FROM message_buffer
WHERE status = 'completed'
ORDER BY completed_at DESC
LIMIT 10;
```

### Check Pinecone Stats
- Vào Pinecone Dashboard
- Index → Statistics
- Check: Vector count, Query count, Upsert count

---

## 🎉 KẾT QUẢ MONG ĐỢI

Sau khi hoàn thành:

✅ **Workflow giảm từ ~60 nodes xuống ~40 nodes**
✅ **Message batching hoạt động** (gộp tin nhắn trong 3 giây)
✅ **Processing indicator hiển thị** ("⏳ Đang xử lý...")
✅ **RAG dùng Pinecone** (ổn định hơn Supabase pgvector)
✅ **Response flow đơn giản hơn** (dễ debug)
✅ **Performance tốt hơn** (Pinecone nhanh hơn)

---

## 📞 SUPPORT

Nếu gặp vấn đề:
1. Check logs trong n8n execution history
2. Check Supabase logs
3. Check Pinecone dashboard
4. Review troubleshooting section ở trên

---

## 🔄 ROLLBACK PLAN

Nếu cần rollback về version cũ:

1. **Deactivate workflows mới**
2. **Reactivate workflow cũ** (Tro ly chinh.json)
3. **Update Zalo webhook** về URL cũ
4. **RAG vẫn dùng Supabase** (không cần rollback Pinecone)

---

**Chúc bạn implementation thành công! 🚀**

