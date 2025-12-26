-- Hàm RPC để tìm kiếm vector trong Supabase
-- Table: knowledge
-- Cột: id, content, category, embedding (vector), metadata

CREATE OR REPLACE FUNCTION match_knowledge(
  query_embedding vector(768),  -- Độ dài vector phụ thuộc vào model embedding (text-embedding-004 = 768)
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
    1 - (knowledge.embedding <=> query_embedding) as similarity,  -- Cosine distance -> similarity
    knowledge.metadata
  FROM knowledge
  WHERE 1 - (knowledge.embedding <=> query_embedding) > match_threshold
  ORDER BY knowledge.embedding <=> query_embedding  -- Sắp xếp theo độ tương đồng (tăng dần)
  LIMIT match_count;
END;
$$;

-- Ghi chú:
-- 1. Operator <=> là cosine distance trong pgvector
-- 2. similarity = 1 - distance (để có giá trị từ 0-1, càng cao càng giống)
-- 3. Nếu model embedding khác 768, cần thay đổi vector(768) thành độ dài phù hợp
-- 4. Đảm bảo extension pgvector đã được enable: CREATE EXTENSION IF NOT EXISTS vector;

