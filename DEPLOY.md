Backend Docker deployment

Build and run the backend with Docker (from repository root):

```bash
docker-compose build backend
docker-compose up -d
```

This exposes the backend at http://localhost:8000. The SQLite DB `vitalshield.db` is mounted into the container for persistence.

Notes:
- Adjust production settings (secrets, CORS origins, DB choice) before public deployment.
- Consider switching from SQLite to Postgres for multi-instance deployments.
