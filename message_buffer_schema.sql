-- ============================================
-- SQL Schema cho Message Buffer Table
-- ============================================
-- Table này dùng để buffer và gộp nhiều tin nhắn trong 3 giây
-- RAG giờ dùng Pinecone, Supabase chỉ dùng cho buffer

DROP TABLE IF EXISTS message_buffer CASCADE;

CREATE TABLE message_buffer (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  chat_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  user_name TEXT DEFAULT '',
  messages JSONB DEFAULT '[]',
  message_type TEXT DEFAULT 'text',
  photo_url TEXT,
  voice_file_id TEXT,
  document JSONB,
  first_message_at TIMESTAMP DEFAULT NOW(),
  last_message_at TIMESTAMP DEFAULT NOW(),
  status TEXT DEFAULT 'buffering' CHECK (status IN ('buffering', 'processing', 'completed', 'failed')),
  processing_message_id TEXT,
  error_message TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX idx_buffer_status_chat ON message_buffer(status, chat_id);
CREATE INDEX idx_buffer_last_message ON message_buffer(status, last_message_at);
CREATE INDEX idx_buffer_created_at ON message_buffer(created_at);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function: Upsert message to buffer (gộp tin nhắn trong 3 giây)
CREATE OR REPLACE FUNCTION upsert_message_buffer(
  p_chat_id TEXT,
  p_user_id TEXT,
  p_user_name TEXT,
  p_message_text TEXT,
  p_message_type TEXT DEFAULT 'text',
  p_photo_url TEXT DEFAULT NULL,
  p_voice_file_id TEXT DEFAULT NULL,
  p_document JSONB DEFAULT NULL,
  p_buffer_window_seconds INT DEFAULT 3
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
  v_buffer_id UUID;
  v_existing_messages JSONB;
BEGIN
  -- Tìm buffer đang buffering trong window time
  SELECT id, messages INTO v_buffer_id, v_existing_messages
  FROM message_buffer
  WHERE chat_id = p_chat_id
    AND status = 'buffering'
    AND last_message_at > NOW() - (p_buffer_window_seconds || ' seconds')::INTERVAL
  ORDER BY last_message_at DESC
  LIMIT 1;

  IF v_buffer_id IS NOT NULL THEN
    -- Update existing buffer: thêm message mới vào array
    UPDATE message_buffer
    SET 
      messages = v_existing_messages || jsonb_build_array(jsonb_build_object(
        'text', COALESCE(p_message_text, ''),
        'type', p_message_type,
        'timestamp', NOW()
      )),
      last_message_at = NOW(),
      updated_at = NOW(),
      message_type = CASE 
        WHEN p_photo_url IS NOT NULL THEN 'image'
        WHEN p_voice_file_id IS NOT NULL THEN 'voice'
        WHEN p_document IS NOT NULL THEN 'document'
        ELSE message_type
      END,
      photo_url = COALESCE(p_photo_url, photo_url),
      voice_file_id = COALESCE(p_voice_file_id, voice_file_id),
      document = COALESCE(p_document, document)
    WHERE id = v_buffer_id;
  ELSE
    -- Create new buffer
    INSERT INTO message_buffer (
      chat_id, user_id, user_name, messages, message_type,
      photo_url, voice_file_id, document, first_message_at, last_message_at
    )
    VALUES (
      p_chat_id, p_user_id, COALESCE(p_user_name, ''),
      jsonb_build_array(jsonb_build_object(
        'text', COALESCE(p_message_text, ''),
        'type', p_message_type,
        'timestamp', NOW()
      )),
      p_message_type,
      p_photo_url, p_voice_file_id, p_document, NOW(), NOW()
    )
    RETURNING id INTO v_buffer_id;
  END IF;

  RETURN v_buffer_id;
END;
$$;

-- Function: Get ready buffers (đã qua 2 giây không có tin nhắn mới)
CREATE OR REPLACE FUNCTION get_ready_buffers(
  p_wait_seconds INT DEFAULT 2,
  p_limit INT DEFAULT 1
)
RETURNS TABLE (
  id UUID,
  chat_id TEXT,
  user_id TEXT,
  user_name TEXT,
  messages JSONB,
  message_type TEXT,
  photo_url TEXT,
  voice_file_id TEXT,
  document JSONB,
  first_message_at TIMESTAMP,
  last_message_at TIMESTAMP,
  created_at TIMESTAMP
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    mb.id, mb.chat_id, mb.user_id, mb.user_name, mb.messages,
    mb.message_type, mb.photo_url, mb.voice_file_id, mb.document,
    mb.first_message_at, mb.last_message_at, mb.created_at
  FROM message_buffer mb
  WHERE mb.status = 'buffering'
    AND mb.last_message_at < NOW() - (p_wait_seconds || ' seconds')::INTERVAL
  ORDER BY mb.created_at ASC
  LIMIT p_limit;
END;
$$;

-- Function: Lock buffer (mark as processing)
CREATE OR REPLACE FUNCTION lock_buffer(
  p_buffer_id UUID,
  p_processing_message_id TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  updated_count INTEGER;
BEGIN
  UPDATE message_buffer
  SET 
    status = 'processing',
    processing_message_id = COALESCE(p_processing_message_id, processing_message_id),
    updated_at = NOW()
  WHERE id = p_buffer_id
    AND status = 'buffering';
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  
  RETURN updated_count > 0;
END;
$$;

-- Function: Mark buffer as completed
CREATE OR REPLACE FUNCTION complete_buffer(
  p_buffer_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  updated_count INTEGER;
BEGIN
  UPDATE message_buffer
  SET 
    status = 'completed',
    updated_at = NOW()
  WHERE id = p_buffer_id
    AND status = 'processing';
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  
  RETURN updated_count > 0;
END;
$$;

-- Function: Mark buffer as failed
CREATE OR REPLACE FUNCTION fail_buffer(
  p_buffer_id UUID,
  p_error_message TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  updated_count INTEGER;
BEGIN
  UPDATE message_buffer
  SET 
    status = 'failed',
    error_message = p_error_message,
    updated_at = NOW()
  WHERE id = p_buffer_id;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  
  RETURN updated_count > 0;
END;
$$;

-- ============================================
-- COMMENTS
-- ============================================

COMMENT ON TABLE message_buffer IS 'Buffer table để gộp nhiều tin nhắn trong 3 giây trước khi xử lý';
COMMENT ON COLUMN message_buffer.status IS 'Trạng thái: buffering (đang gộp), processing (đang xử lý), completed (hoàn thành), failed (lỗi)';
COMMENT ON COLUMN message_buffer.messages IS 'Array JSON chứa tất cả tin nhắn đã gộp: [{"text": "...", "type": "text", "timestamp": "..."}]';
COMMENT ON COLUMN message_buffer.document IS 'JSON object chứa: {file_id, file_name, file_size, mime_type}';

