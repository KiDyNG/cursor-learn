# 🔧 HƯỚNG DẪN CẬP NHẬT WORKFLOW 2: MESSAGE PROCESSOR

## 📋 TỔNG QUAN THAY ĐỔI

### Nodes cần XÓA:
- ❌ `chat_bot` (Webhook trigger - không cần nữa)
- ❌ `Send Processing Message` (old, ở đầu workflow)
- ❌ `Respond to Webhook`
- ❌ `Get Pending Message` (old HTTP)
- ❌ `Has message?` (old If node)
- ❌ `Lock message` (old HTTP)
- ❌ `Convert Queue Data` (old Code)
- ❌ `Extract Quote Data`
- ❌ `Response Type` (Switch)
- ❌ `SendPhoto (Quote)`
- ❌ `SendMessage (After Photo)`
- ❌ `SendSticker (Success)`
- ❌ `SendMessage (PDF Only)`
- ❌ `SendPhoto (Image Only)`
- ❌ `SendMessage (Text Only)`
- ❌ `Split Response`
- ❌ `Xử lý Response Type`
- ❌ Tất cả nodes liên quan đến Supabase RAG (thay bằng Pinecone workflow)

### Nodes cần THÊM:

#### 1. Schedule Trigger
```json
{
  "parameters": {
    "rule": {
      "interval": [
        {
          "field": "seconds",
          "secondsInterval": 2
        }
      ]
    }
  },
  "type": "n8n-nodes-base.scheduleTrigger",
  "typeVersion": 1.2,
  "position": [-9000, 300],
  "id": "schedule-trigger",
  "name": "Schedule Trigger"
}
```

#### 2. Get Ready Buffers
```json
{
  "parameters": {
    "method": "POST",
    "url": "https://zamexodnbxgmazdnajtd.supabase.co/rest/v1/rpc/get_ready_buffers",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "apikey",
          "value": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InphbWV4b2RuYnhnbWF6ZG5hanRkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NjU5ODM1MiwiZXhwIjoyMDgyMTc0MzUyfQ.mAC3J7FD9ZY3RJL3hf7QSly_QoelpVmhERIe0NPnQHA"
        },
        {
          "name": "Authorization",
          "value": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InphbWV4b2RuYnhnbWF6ZG5hanRkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NjU5ODM1MiwiZXhwIjoyMDgyMTc0MzUyfQ.mAC3J7FD9ZY3RJL3hf7QSly_QoelpVmhERIe0NPnQHA"
        },
        {
          "name": "Content-Type",
          "value": "application/json"
        }
      ]
    },
    "sendBody": true,
    "specifyBody": "json",
    "jsonBody": "={\n  \"p_wait_seconds\": 2,\n  \"p_limit\": 1\n}",
    "options": {}
  },
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.3,
  "position": [-8800, 300],
  "id": "get-ready-buffers",
  "name": "Get Ready Buffers"
}
```

#### 3. Has Buffer?
```json
{
  "parameters": {
    "conditions": {
      "options": {
        "caseSensitive": true,
        "leftValue": "",
        "typeValidation": "strict",
        "version": 2
      },
      "conditions": [
        {
          "id": "has-buffer-check",
          "leftValue": "={{ $json.id }}",
          "rightValue": "",
          "operator": {
            "type": "string",
            "operation": "exists",
            "singleValue": true
          }
        }
      ],
      "combinator": "and"
    },
    "options": {}
  },
  "type": "n8n-nodes-base.if",
  "typeVersion": 2.2,
  "position": [-8600, 300],
  "id": "has-buffer",
  "name": "Has Buffer?"
}
```

#### 4. Extract First Buffer
```json
{
  "parameters": {
    "jsCode": "// Extract first buffer from array\nconst buffers = $input.all();\nif (buffers.length === 0) {\n  return [{ json: { skip: true } }];\n}\n\nreturn [buffers[0]];"
  },
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [-8400, 300],
  "id": "extract-first-buffer",
  "name": "Extract First Buffer"
}
```

#### 5. Lock Buffer
```json
{
  "parameters": {
    "method": "POST",
    "url": "=https://zamexodnbxgmazdnajtd.supabase.co/rest/v1/rpc/lock_buffer",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "apikey",
          "value": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InphbWV4b2RuYnhnbWF6ZG5hanRkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NjU5ODM1MiwiZXhwIjoyMDgyMTc0MzUyfQ.mAC3J7FD9ZY3RJL3hf7QSly_QoelpVmhERIe0NPnQHA"
        },
        {
          "name": "Authorization",
          "value": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InphbWV4b2RuYnhnbWF6ZG5hanRkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NjU5ODM1MiwiZXhwIjoyMDgyMTc0MzUyfQ.mAC3J7FD9ZY3RJL3hf7QSly_QoelpVmhERIe0NPnQHA"
        },
        {
          "name": "Content-Type",
          "value": "application/json"
        }
      ]
    },
    "sendBody": true,
    "specifyBody": "json",
    "jsonBody": "={\n  \"p_buffer_id\": {{ JSON.stringify($json.id) }}\n}",
    "options": {}
  },
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.3,
  "position": [-8200, 300],
  "id": "lock-buffer",
  "name": "Lock Buffer"
}
```

#### 6. Merge Messages (Code node)
```javascript
// Merge Messages - Gộp tất cả tin nhắn trong buffer
const buffer = $input.first().json;
const messages = buffer.messages || [];

// Gộp text từ tất cả messages
const mergedText = messages
  .map(m => m.text || '')
  .filter(t => t.trim() !== '')
  .join(' ');

// Lấy caption từ message có ảnh
const caption = messages.find(m => m.photo_url && m.text)?.text || '';

// Reconstruct message structure tương tự webhook format
return [{
  json: {
    body: {
      message: {
        text: mergedText || caption,
        caption: caption,
        photo_url: buffer.photo_url || '',
        voice: buffer.voice_file_id ? { file_id: buffer.voice_file_id } : null,
        document: buffer.document || null,
        from: {
          id: buffer.user_id,
          first_name: buffer.user_name || ''
        },
        chat: {
          id: buffer.chat_id
        }
      }
    },
    buffer_id: buffer.id,
    chat_id: buffer.chat_id,
    user_id: buffer.user_id,
    user_name: buffer.user_name || '',
    message_type: buffer.message_type || 'text',
    merged_count: messages.length
  }
}];
```

#### 7. Send Processing Message
```json
{
  "parameters": {
    "method": "POST",
    "url": "https://bot-api.zaloplatforms.com/bot3560693075024509922:IRydnWGAAtlekyTBevNhCHkSOOsuCWvBMphBNeSurWcpTbkMgRSRTpvKJbWMWbYX/sendMessage",
    "sendBody": true,
    "bodyParameters": {
      "parameters": [
        {
          "name": "chat_id",
          "value": "={{ $json.chat_id }}"
        },
        {
          "name": "text",
          "value": "⏳ Đang xử lý..."
        }
      ]
    },
    "options": {}
  },
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.3,
  "position": [-8000, 300],
  "id": "send-processing",
  "name": "Send Processing Message"
}
```

#### 8. Update Search Knowledge node
Thay đổi workflow ID để gọi "RAG Knowledge - Pinecone" workflow:

```json
{
  "parameters": {
    "workflowId": {
      "__rl": true,
      "value": "[RAG-KNOWLEDGE-PINECONE-WORKFLOW-ID]",
      "mode": "id"
    },
    "workflowInputs": {
      "mappingMode": "defineBelow",
      "value": {
        "query": "={{ $json.ragQuery || $json.content || $json.prompt || '' }}",
        "action": "search"
      },
      "matchingColumns": ["query"],
      "schema": [
        {
          "id": "query",
          "displayName": "query",
          "required": false,
          "defaultMatch": false,
          "display": true,
          "canBeUsedToMatch": true
        },
        {
          "id": "action",
          "displayName": "action",
          "required": false,
          "defaultMatch": false,
          "display": true,
          "canBeUsedToMatch": true
        }
      ]
    }
  },
  "type": "n8n-nodes-base.executeWorkflow",
  "typeVersion": 1.3,
  "name": "Search Knowledge"
}
```

#### 9. Update Execute Save to RAG node
```json
{
  "parameters": {
    "workflowId": {
      "__rl": true,
      "value": "[RAG-KNOWLEDGE-PINECONE-WORKFLOW-ID]",
      "mode": "id"
    },
    "workflowInputs": {
      "mappingMode": "defineBelow",
      "value": {
        "query": "={{ $json.contentToSave || $json.query }}",
        "action": "save",
        "category": "={{ $json.category || 'general' }}"
      }
    }
  },
  "type": "n8n-nodes-base.executeWorkflow",
  "typeVersion": 1.3,
  "name": "Execute Save to RAG"
}
```

#### 10. Update Auto Save Web Knowledge node
```json
{
  "parameters": {
    "workflowId": {
      "__rl": true,
      "value": "[RAG-KNOWLEDGE-PINECONE-WORKFLOW-ID]",
      "mode": "id"
    },
    "workflowInputs": {
      "mappingMode": "defineBelow",
      "value": {
        "query": "={{ $json.contentToSave }}",
        "action": "save",
        "category": "={{ $json.category }}"
      }
    }
  },
  "type": "n8n-nodes-base.executeWorkflow",
  "typeVersion": 1.3,
  "name": "Auto Save Web Knowledge"
}
```

#### 11. Parse Response (Code node)
```javascript
// Parse Response - Trích xuất URLs và làm sạch output
const agentItem = $('Tro ly chinh').first().json;
let output = agentItem.output || '';
const chatId = $('Merge Messages').first().json.chat_id;
const bufferId = $('Merge Messages').first().json.buffer_id;

// Tìm URLs
const imageMatch = output.match(/(https?:\/\/[^\s"<>)]+?\.(?:png|jpg|jpeg|webp))/i);
const pdfMatch = output.match(/(https?:\/\/[^\s"<>)]+?\.pdf)/i);
const quoteMatch = output.match(/(BG-\d{8}-\d{3})/i);

// Làm sạch output
output = output
  .replace(/RESPONSE_TYPE:\s*["']?[a-zA-Z_]+["']?/gi, '')
  .replace(/```json[\s\S]*?```/gi, '')
  .replace(/\{[\s\S]*?"action"[\s\S]*?\}/gi, '')
  .trim();

// Xóa links nếu đã gửi riêng
if (imageMatch) output = output.replace(imageMatch[1], '').trim();
if (pdfMatch) output = output.replace(pdfMatch[1], '').trim();

// Clean up
output = output.replace(/\n\s*\n\s*\n/g, '\n\n').trim();
if (output.length > 1900) output = output.substring(0, 1900) + '...';

return [{
  json: {
    chat_id: chatId,
    buffer_id: bufferId,
    output: output,
    image_url: imageMatch ? imageMatch[1] : null,
    pdf_url: pdfMatch ? pdfMatch[1] : null,
    quote_number: quoteMatch ? quoteMatch[1] : null,
    has_image: !!imageMatch,
    has_pdf: !!pdfMatch
  }
}];
```

#### 12. Has Image? (If node)
```json
{
  "parameters": {
    "conditions": {
      "options": {
        "caseSensitive": true,
        "leftValue": "",
        "typeValidation": "strict",
        "version": 2
      },
      "conditions": [
        {
          "id": "check-image",
          "leftValue": "={{ $json.image_url }}",
          "rightValue": "",
          "operator": {
            "type": "string",
            "operation": "exists",
            "singleValue": true
          }
        }
      ],
      "combinator": "and"
    },
    "options": {}
  },
  "type": "n8n-nodes-base.if",
  "typeVersion": 2.2,
  "position": [-2000, 300],
  "id": "has-image",
  "name": "Has Image?"
}
```

#### 13. Send Photo
```json
{
  "parameters": {
    "method": "POST",
    "url": "https://bot-api.zaloplatforms.com/bot3560693075024509922:IRydnWGAAtlekyTBevNhCHkSOOsuCWvBMphBNeSurWcpTbkMgRSRTpvKJbWMWbYX/sendPhoto",
    "sendBody": true,
    "bodyParameters": {
      "parameters": [
        {
          "name": "chat_id",
          "value": "={{ $json.chat_id }}"
        },
        {
          "name": "photo",
          "value": "={{ $json.image_url }}"
        },
        {
          "name": "caption",
          "value": "=📋 Báo giá {{ $json.quote_number || '' }}"
        }
      ]
    },
    "options": {}
  },
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.3,
  "position": [-1800, 200],
  "id": "send-photo",
  "name": "Send Photo"
}
```

#### 14. Has PDF? (If node)
```json
{
  "parameters": {
    "conditions": {
      "options": {
        "caseSensitive": true,
        "leftValue": "",
        "typeValidation": "strict",
        "version": 2
      },
      "conditions": [
        {
          "id": "check-pdf",
          "leftValue": "={{ $json.pdf_url }}",
          "rightValue": "",
          "operator": {
            "type": "string",
            "operation": "exists",
            "singleValue": true
          }
        }
      ],
      "combinator": "and"
    },
    "options": {}
  },
  "type": "n8n-nodes-base.if",
  "typeVersion": 2.2,
  "position": [-1600, 300],
  "id": "has-pdf",
  "name": "Has PDF?"
}
```

#### 15. Send PDF Message
```json
{
  "parameters": {
    "method": "POST",
    "url": "https://bot-api.zaloplatforms.com/bot3560693075024509922:IRydnWGAAtlekyTBevNhCHkSOOsuCWvBMphBNeSurWcpTbkMgRSRTpvKJbWMWbYX/sendMessage",
    "sendBody": true,
    "bodyParameters": {
      "parameters": [
        {
          "name": "chat_id",
          "value": "={{ $json.chat_id }}"
        },
        {
          "name": "text",
          "value": "=📄 File PDF báo giá {{ $json.quote_number || '' }}:\n{{ $json.pdf_url }}"
        }
      ]
    },
    "options": {}
  },
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.3,
  "position": [-1400, 200],
  "id": "send-pdf",
  "name": "Send PDF Message"
}
```

#### 16. Send Text Message
```json
{
  "parameters": {
    "method": "POST",
    "url": "https://bot-api.zaloplatforms.com/bot3560693075024509922:IRydnWGAAtlekyTBevNhCHkSOOsuCWvBMphBNeSurWcpTbkMgRSRTpvKJbWMWbYX/sendMessage",
    "sendBody": true,
    "bodyParameters": {
      "parameters": [
        {
          "name": "chat_id",
          "value": "={{ $json.chat_id }}"
        },
        {
          "name": "text",
          "value": "={{ $json.output }}"
        }
      ]
    },
    "options": {}
  },
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.3,
  "position": [-1200, 300],
  "id": "send-text",
  "name": "Send Text Message"
}
```

#### 17. Mark Completed
```json
{
  "parameters": {
    "method": "POST",
    "url": "=https://zamexodnbxgmazdnajtd.supabase.co/rest/v1/rpc/complete_buffer",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "apikey",
          "value": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InphbWV4b2RuYnhnbWF6ZG5hanRkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NjU5ODM1MiwiZXhwIjoyMDgyMTc0MzUyfQ.mAC3J7FD9ZY3RJL3hf7QSly_QoelpVmhERIe0NPnQHA"
        },
        {
          "name": "Authorization",
          "value": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InphbWV4b2RuYnhnbWF6ZG5hanRkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NjU5ODM1MiwiZXhwIjoyMDgyMTc0MzUyfQ.mAC3J7FD9ZY3RJL3hf7QSly_QoelpVmhERIe0NPnQHA"
        },
        {
          "name": "Content-Type",
          "value": "application/json"
        }
      ]
    },
    "sendBody": true,
    "specifyBody": "json",
    "jsonBody": "={\n  \"p_buffer_id\": {{ JSON.stringify($('Merge Messages').first().json.buffer_id) }}\n}",
    "options": {}
  },
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.3,
  "position": [-1000, 300],
  "id": "mark-completed",
  "name": "Mark Completed"
}
```

## 🔗 CONNECTIONS

```
Schedule Trigger → Get Ready Buffers → Has Buffer?
  ↓ (Yes)
Extract First Buffer → Lock Buffer → Merge Messages → Send Processing Message
  ↓
Switch (Voice/Text/Image/Document) → [Existing processing flow]
  ↓
Tro ly chinh (Agent) → Parse Response
  ↓
Has Image? → Send Photo
  ↓
Has PDF? → Send PDF Message
  ↓
Send Text Message → Mark Completed
```

## 📝 LƯU Ý

1. **Update MongoDB Chat Memory sessionKey**: Đổi từ `$('chat_bot')` sang `$('Merge Messages')`
2. **Update tất cả references**: Thay `$('chat_bot')` bằng `$('Merge Messages')` hoặc `$json`
3. **Update Input node**: Sử dụng data từ `Merge Messages` thay vì `chat_bot`
4. **Test kỹ**: Đảm bảo message batching hoạt động đúng

