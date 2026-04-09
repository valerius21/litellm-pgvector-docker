# LiteLLM + pgvector Docker Compose

Two Docker Compose configurations for running [LiteLLM](https://github.com/BerriAI/litellm) with [pgvector](https://github.com/pgvector/pgvector) and the [litellm-pgvector](https://github.com/BerriAI/litellm-pgvector) vector store API.

## Quick Start

### Option 1: Full Stack (Recommended for new setups)

Includes PostgreSQL with pgvector, LiteLLM proxy, and the vector store API.

```bash
# Copy and configure environment
cp .env.example .env
# Edit .env with your API keys

# Start all services
docker compose -f docker-compose.full.yml up -d
```

Services:
- **pgvector** (port 5432): PostgreSQL with pgvector extension
- **litellm** (port 4000): LLM proxy with built-in embedding support
- **litellm-pgvector** (port 8000): OpenAI-compatible vector store API

### Option 2: Standalone (Use with external LiteLLM)

Only PostgreSQL with pgvector and the vector store API. Connects to an external LiteLLM proxy.

```bash
# Copy and configure environment
cp .env.example .env
# Edit .env with your external LiteLLM URL and API keys

# Start services
docker compose -f docker-compose.standalone.yml up -d
```

Services:
- **pgvector** (port 5432): PostgreSQL with pgvector extension
- **litellm-pgvector** (port 8000): OpenAI-compatible vector store API

## Configuration

### Required Environment Variables

Copy `.env.example` to `.env` and set:

| Variable | Description | Full Stack | Standalone |
|----------|-------------|------------|------------|
| `POSTGRES_PASSWORD` | PostgreSQL password | Required | Required |
| `LITELLM_MASTER_KEY` | Master key for LiteLLM proxy | Required | - |
| `SERVER_API_KEY` | API key for vector store API | Required | Required |
| `EMBEDDING__BASE_URL` | External LiteLLM URL | - | Required |
| `EMBEDDING__API_KEY` | API key for external LiteLLM | - | Optional |
| `OPENAI_API_KEY` | OpenAI API key | Required | If using OpenAI |

### Database Initialization

**Important**: PostgreSQL init scripts only run on the first container start when the data volume is empty.

If you need to reset the database:
```bash
docker compose -f docker-compose.full.yml down -v
docker compose -f docker-compose.full.yml up -d
```

### Customizing the Embedding Model

The default embedding model is `text-embedding-ada-002`. To use a different model:

1. Add the model to `config/litellm-config.yaml` (full stack)
2. Set `EMBEDDING__MODEL` in your `.env` to match the model name

Example for Cohere embeddings:
```yaml
# config/litellm-config.yaml
model_list:
  - model_name: embed-english-v3.0
    litellm_params:
      model: cohere/embed-english-v3.0
      api_key: os.environ/COHERE_API_KEY
```

```bash
# .env
EMBEDDING__MODEL=embed-english-v3.0
```

## API Usage

### Create a Vector Store

```bash
curl -X POST http://localhost:8000/v1/vector_stores \
  -H "Authorization: Bearer $SERVER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "My Documents"}'
```

### Add Embeddings

```bash
curl -X POST http://localhost:8000/v1/vector_stores/vs_xxx/embeddings \
  -H "Authorization: Bearer $SERVER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Your text here",
    "embedding": [0.1, 0.2, ...],
    "metadata": {"source": "doc1"}
  }'
```

### Search

```bash
curl -X POST http://localhost:8000/v1/vector_stores/vs_xxx/search \
  -H "Authorization: Bearer $SERVER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "search query",
    "limit": 10
  }'
```

See the [litellm-pgvector documentation](https://github.com/BerriAI/litellm-pgvector) for complete API reference.

## Architecture

```
Full Stack:
┌─────────────┐     ┌─────────────┐     ┌─────────────────┐
│   pgvector  │────▶│   litellm   │────▶│ litellm-pgvector│
│  (vectors)  │     │   (proxy)   │     │   (port 8000)   │
└─────────────┘     └─────────────┘     └─────────────────┘
       │
       └────▶ (litellm internal DB)

Standalone:
┌─────────────┐                          ┌─────────────────┐
│   pgvector  │                          │ litellm-pgvector│
│  (vectors)  │                          │   (port 8000)   │
└─────────────┘                          └─────────────────┘
                                                │
                                                ▼
                                       (external LiteLLM)
```

## Troubleshooting

### Database not initializing
If you see errors about missing databases or extensions, the init scripts may have been skipped. Ensure the volume is empty on first start:
```bash
docker compose down -v
docker compose up -d
```

### Embedding requests failing
Check that the model name in `EMBEDDING__MODEL` matches a model defined in `config/litellm-config.yaml` (full stack) or is supported by your external LiteLLM proxy (standalone).

### Health check failures
The services use health checks to ensure proper startup order. If a service fails to start, check logs:
```bash
docker compose logs -f pgvector
docker compose logs -f litellm
docker compose logs -f litellm-pgvector
```

## License

MIT