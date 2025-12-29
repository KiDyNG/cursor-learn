-- ============================================
-- SQL Schema cho Message Queue Table
-- ============================================
-- Table này dùng để lưu trữ message từ Zalo webhook
-- và xử lý theo queue pattern (pending -> processing -> completed)

CREATE TABLE IF NOT EXISTS message_queue (
  id BIGSERIAL PRIMARY KEY,
  
  -- Thông tin message từ Zalo
  message_id TEXT,
  chat_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  user_name TEXT,
  
  -- Nội dung message
  text TEXT,
  caption TEXT,
  photo_url TEXT,
  voice_file_id TEXT,
  document JSONB, -- Lưu thông tin document (file_id, file_name, file_size, mime_type)
  
  -- Raw data từ webhook (để backup và debug)
  raw_data JSONB,
  
  -- Status tracking
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  processing_started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  
  -- Error tracking (nếu xử lý lỗi)
  error_message TEXT,
  retry_count INTEGER DEFAULT 0
);

-- ============================================
-- INDEXES để tối ưu query
-- ============================================

-- Index cho status (dùng để query pending messages)
CREATE INDEX IF NOT EXISTS idx_message_queue_status ON message_queue(status);

-- Index cho created_at (dùng để order by)
CREATE INDEX IF NOT EXISTS idx_message_queue_created_at ON message_queue(created_at);

-- Index composite cho query pending messages (status + created_at)
CREATE INDEX IF NOT EXISTS idx_message_queue_status_created ON message_queue(status, created_at);

-- Index cho chat_id (nếu cần query theo chat)
CREATE INDEX IF NOT EXISTS idx_message_queue_chat_id ON message_queue(chat_id);

-- Index cho user_id (nếu cần query theo user)
CREATE INDEX IF NOT EXISTS idx_message_queue_user_id ON message_queue(user_id);

-- ============================================
-- RLS (Row Level Security) - Optional
-- ============================================
-- Nếu bạn muốn bật RLS, uncomment các dòng sau:

-- ALTER TABLE message_queue ENABLE ROW LEVEL SECURITY;

-- -- Policy cho service role (n8n workflow)
-- CREATE POLICY "Service role can do everything" ON message_queue
--   FOR ALL
--   USING (true)
--   WITH CHECK (true);

-- ============================================
-- FUNCTIONS - Optional helpers
-- ============================================

-- Function để lấy pending message (có thể dùng thay vì query trực tiếp)
CREATE OR REPLACE FUNCTION get_next_pending_message()
RETURNS TABLE (
  id BIGINT,
  message_id TEXT,
  chat_id TEXT,
  user_id TEXT,
  user_name TEXT,
  text TEXT,
  caption TEXT,
  photo_url TEXT,
  voice_file_id TEXT,
  document JSONB,
  raw_data JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    mq.id,
    mq.message_id,
    mq.chat_id,
    mq.user_id,
    mq.user_name,
    mq.text,
    mq.caption,
    mq.photo_url,
    mq.voice_file_id,
    mq.document,
    mq.raw_data
  FROM message_queue mq
  WHERE mq.status = 'pending'
  ORDER BY mq.created_at ASC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function để mark message as processing
CREATE OR REPLACE FUNCTION lock_message(message_id_param BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
  updated_count INTEGER;
BEGIN
  UPDATE message_queue
  SET 
    status = 'processing',
    processing_started_at = NOW()
  WHERE id = message_id_param
    AND status = 'pending';
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  
  RETURN updated_count > 0;
END;
$$ LANGUAGE plpgsql;

-- Function để mark message as completed
CREATE OR REPLACE FUNCTION complete_message(message_id_param BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
  updated_count INTEGER;
BEGIN
  UPDATE message_queue
  SET 
    status = 'completed',
    completed_at = NOW()
  WHERE id = message_id_param
    AND status = 'processing';
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  
  RETURN updated_count > 0;
END;
$$ LANGUAGE plpgsql;

-- Function để mark message as failed
CREATE OR REPLACE FUNCTION fail_message(message_id_param BIGINT, error_msg TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  updated_count INTEGER;
BEGIN
  UPDATE message_queue
  SET 
    status = 'failed',
    error_message = error_msg,
    completed_at = NOW()
  WHERE id = message_id_param;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  
  RETURN updated_count > 0;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- COMMENTS
-- ============================================

COMMENT ON TABLE message_queue IS 'Queue table để lưu trữ và xử lý message từ Zalo webhook';
COMMENT ON COLUMN message_queue.status IS 'Trạng thái: pending (chờ xử lý), processing (đang xử lý), completed (hoàn thành), failed (lỗi)';
COMMENT ON COLUMN message_queue.document IS 'JSON object chứa: {file_id, file_name, file_size, mime_type}';
COMMENT ON COLUMN message_queue.raw_data IS 'Toàn bộ dữ liệu gốc từ webhook để backup và debug';


