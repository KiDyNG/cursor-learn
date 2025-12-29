/**
 * Migration Script: Supabase pgvector → Pinecone
 * 
 * Chạy script này để migrate dữ liệu từ Supabase knowledge table sang Pinecone
 * 
 * Cách chạy:
 * 1. Export data từ Supabase: SELECT content, category, created_at FROM knowledge;
 * 2. Paste vào array `knowledge` bên dưới
 * 3. Chạy script này trong n8n Code node hoặc Node.js
 */

// ============================================
// STEP 1: Export data từ Supabase
// ============================================
// Chạy query này trong Supabase SQL Editor:
// SELECT content, category, created_at FROM knowledge ORDER BY created_at;

// ============================================
// STEP 2: Paste data vào đây
// ============================================
const knowledge = [
  // Ví dụ:
  // { content: "Giá gỗ sồi là 15 triệu/m3", category: "pricing" },
  // { content: "Khách A thích màu trắng", category: "customer_preference" },
  // ... thêm các rows khác
];

// ============================================
// STEP 3: Migration function
// ============================================
async function migrateToPinecone() {
  const PINECONE_API_KEY = 'pcsk_cj2MU_Hv6o3ZKzx7ikncKrYr6cRGvq6w8Z88uCrNEs8unwbBtthEYmmvCWa5cUBxdZYgH';
  const PINECONE_HOST = 'minhkhoa-knowledge-db0pu9l.svc.aped-4627-b74a.pinecone.io';
  const GEMINI_API_KEY = 'AIzaSyBhRj9xQkHGoNC8SwMK3EtXSVJ8xYRxol0';
  
  let successCount = 0;
  let errorCount = 0;
  
  console.log(`Bắt đầu migration ${knowledge.length} items...`);
  
  for (let i = 0; i < knowledge.length; i++) {
    const item = knowledge[i];
    
    try {
      // Step 1: Generate embedding
      const embeddingResponse = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            model: 'models/text-embedding-004',
            content: { parts: [{ text: item.content }] }
          })
        }
      );
      
      const embeddingData = await embeddingResponse.json();
      const embedding = embeddingData.embedding?.values || [];
      
      if (embedding.length !== 768) {
        throw new Error(`Invalid embedding dimensions: ${embedding.length}`);
      }
      
      // Step 2: Prepare Pinecone vector
      const vectorId = `kb_migrated_${Date.now()}_${i}_${Math.random().toString(36).substr(2, 9)}`;
      const vector = {
        id: vectorId,
        values: embedding,
        metadata: {
          content: item.content,
          category: item.category || 'general',
          created_at: item.created_at || new Date().toISOString(),
          migrated: true
        }
      };
      
      // Step 3: Upsert to Pinecone
      const pineconeResponse = await fetch(
        `https://${PINECONE_HOST}/vectors/upsert`,
        {
          method: 'POST',
          headers: {
            'Api-Key': PINECONE_API_KEY,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            vectors: [vector],
            namespace: 'minhkhoa'
          })
        }
      );
      
      if (!pineconeResponse.ok) {
        const error = await pineconeResponse.text();
        throw new Error(`Pinecone error: ${error}`);
      }
      
      successCount++;
      console.log(`✅ [${i + 1}/${knowledge.length}] Migrated: "${item.content.substring(0, 50)}..."`);
      
      // Rate limiting: wait 100ms between requests
      await new Promise(resolve => setTimeout(resolve, 100));
      
    } catch (error) {
      errorCount++;
      console.error(`❌ [${i + 1}/${knowledge.length}] Error: ${error.message}`);
      console.error(`   Content: "${item.content.substring(0, 100)}..."`);
    }
  }
  
  console.log('\n========================================');
  console.log(`Migration hoàn thành!`);
  console.log(`✅ Success: ${successCount}`);
  console.log(`❌ Errors: ${errorCount}`);
  console.log(`📊 Total: ${knowledge.length}`);
  console.log('========================================');
}

// ============================================
// STEP 4: Chạy migration
// ============================================
// Uncomment dòng dưới để chạy:
// migrateToPinecone();

// ============================================
// N8N CODE NODE VERSION
// ============================================
// Nếu chạy trong n8n Code node, dùng code này:

/*
const knowledge = [
  // Paste data từ Supabase vào đây
];

const PINECONE_API_KEY = 'pcsk_cj2MU_Hv6o3ZKzx7ikncKrYr6cRGvq6w8Z88uCrNEs8unwbBtthEYmmvCWa5cUBxdZYgH';
const PINECONE_HOST = 'minhkhoa-knowledge-db0pu9l.svc.aped-4627-b74a.pinecone.io';
const GEMINI_API_KEY = 'AIzaSyBhRj9xQkHGoNC8SwMK3EtXSVJ8xYRxol0';

const results = [];

for (let i = 0; i < knowledge.length; i++) {
  const item = knowledge[i];
  
  try {
    // Generate embedding
    const embeddingRes = await $http.request({
      method: 'POST',
      url: `https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}`,
      headers: { 'Content-Type': 'application/json' },
      body: {
        model: 'models/text-embedding-004',
        content: { parts: [{ text: item.content }] }
      }
    });
    
    const embedding = embeddingRes.embedding?.values || [];
    
    if (embedding.length !== 768) {
      throw new Error(`Invalid dimensions: ${embedding.length}`);
    }
    
    // Upsert to Pinecone
    const vectorId = `kb_migrated_${Date.now()}_${i}`;
    const pineconeRes = await $http.request({
      method: 'POST',
      url: `https://${PINECONE_HOST}/vectors/upsert`,
      headers: {
        'Api-Key': PINECONE_API_KEY,
        'Content-Type': 'application/json'
      },
      body: {
        vectors: [{
          id: vectorId,
          values: embedding,
          metadata: {
            content: item.content,
            category: item.category || 'general',
            created_at: item.created_at || new Date().toISOString()
          }
        }],
        namespace: 'minhkhoa'
      }
    });
    
    results.push({
      success: true,
      id: vectorId,
      content: item.content.substring(0, 50)
    });
    
  } catch (error) {
    results.push({
      success: false,
      error: error.message,
      content: item.content.substring(0, 50)
    });
  }
}

return results.map(r => ({ json: r }));
*/

