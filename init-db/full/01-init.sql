-- Enable pgvector extension in the application database (auto-created via POSTGRES_DB)
CREATE EXTENSION IF NOT EXISTS vector;

-- Create database for LiteLLM proxy internal use (users, keys, spend tracking)
CREATE DATABASE litellm;