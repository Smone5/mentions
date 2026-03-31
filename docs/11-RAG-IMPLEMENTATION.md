# RAG Implementation

Complete guide to implementing Retrieval-Augmented Generation for grounding replies in company knowledge.

---

## Architecture

```
User Uploads → Chunking → Embeddings → pgvector Storage → Semantic Search → Context for LLM
```

---

## Implementation

### 1. Document Ingestion

```python
# rag/ingest.py
from langchain.text_splitter import RecursiveCharacterTextSplitter
import uuid

async def ingest_document(
    company_id: str,
    filename: str,
    content: str,
    file_type: str
) -> str:
    """Ingest document and create embeddings."""
    
    # Save document record
    doc_id = str(uuid.uuid4())
    await db.execute(
        """
        INSERT INTO rag_documents (id, company_id, filename, file_type, content, created_at)
        VALUES ($1, $2, $3, $4, $5, NOW())
        """,
        doc_id, company_id, filename, file_type, content
    )
    
    # Split into chunks
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=500,
        chunk_overlap=50
    )
    chunks = splitter.split_text(content)
    
    # Generate embeddings and store
    for i, chunk_text in enumerate(chunks):
        # Get embedding from OpenAI
        embedding = await get_embedding(chunk_text)
        
        # Store in database
        await db.execute(
            """
            INSERT INTO rag_chunks (
                id, document_id, company_id, chunk_index, chunk_text, embedding, created_at
            ) VALUES ($1, $2, $3, $4, $5, $6, NOW())
            """,
            str(uuid.uuid4()),
            doc_id,
            company_id,
            i,
            chunk_text,
            embedding  # pgvector column
        )
    
    logger.info(f"Ingested document {filename} with {len(chunks)} chunks")
    return doc_id


async def get_embedding(text: str) -> list:
    """Get embedding from OpenAI."""
    from openai import OpenAI
    client = OpenAI(api_key=settings.OPENAI_API_KEY)
    
    response = client.embeddings.create(
        model="text-embedding-3-small",
        input=text
    )
    
    return response.data[0].embedding
```

### 2. Semantic Search

```python
# rag/retrieve.py
async def semantic_search(
    company_id: str,
    query: str,
    limit: int = 5
) -> list[dict]:
    """Search for relevant chunks using vector similarity."""
    
    # Get query embedding
    query_embedding = await get_embedding(query)
    
    # Vector similarity search
    results = await db.fetch(
        """
        SELECT
            c.id,
            c.chunk_text,
            d.filename,
            1 - (c.embedding <=> $1::vector) AS similarity
        FROM rag_chunks c
        JOIN rag_documents d ON c.document_id = d.id
        WHERE c.company_id = $2
        ORDER BY c.embedding <=> $1::vector
        LIMIT $3
        """,
        query_embedding,
        company_id,
        limit
    )
    
    return [dict(r) for r in results]
```

### 3. API Endpoints

```python
# api/rag.py
@router.post("/rag/upload")
async def upload_document(
    file: UploadFile,
    user = Depends(get_current_user)
):
    """Upload and ingest document."""
    content = await file.read()
    content_str = content.decode('utf-8')
    
    doc_id = await ingest_document(
        company_id=user.company_id,
        filename=file.filename,
        content=content_str,
        file_type=file.content_type
    )
    
    return {"success": True, "document_id": doc_id}


@router.get("/rag/documents")
async def list_documents(user = Depends(get_current_user)):
    """List company documents."""
    docs = await db.fetch(
        "SELECT * FROM rag_documents WHERE company_id = $1 ORDER BY created_at DESC",
        user.company_id
    )
    return {"documents": [dict(d) for d in docs]}
```

---

## Frontend Component

```tsx
// app/settings/rag/page.tsx
'use client'

export default function RAGPage() {
  const [documents, setDocuments] = useState([])
  const [uploading, setUploading] = useState(false)
  
  const handleUpload = async (file: File) => {
    setUploading(true)
    const formData = new FormData()
    formData.append('file', file)
    
    await fetch('/api/rag/upload', {
      method: 'POST',
      body: formData
    })
    
    await fetchDocuments()
    setUploading(false)
  }
  
  return (
    <div>
      <h1>Company Knowledge</h1>
      <FileUploader onUpload={handleUpload} disabled={uploading} />
      <DocumentList documents={documents} />
    </div>
  )
}
```

---

## Verification

- [ ] Documents ingested and chunked correctly
- [ ] Embeddings stored in pgvector
- [ ] Semantic search returns relevant results
- [ ] Company isolation enforced

**Reference**: [03-DATABASE-SCHEMA.md](./03-DATABASE-SCHEMA.md), [M2-GENERATION-FLOW.md](./M2-GENERATION-FLOW.md)






