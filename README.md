# Mentions - AI-Powered Reddit Engagement Platform

An intelligent system that discovers relevant Reddit discussions and generates authentic, helpful responses to promote products naturally.

## Repository Structure

This is a monorepo containing:

- **`/docs`** - Comprehensive project documentation
- **`/mentions_backend`** - FastAPI backend with LangGraph workflows (separate git repo)
- **`/mentions_frontend`** - Next.js frontend application (separate git repo)
- **`/mentions_terraform`** - Infrastructure as Code for AWS deployment

## Quick Start

See [docs/00-QUICK-START.md](docs/00-QUICK-START.md) for detailed setup instructions.

### Prerequisites

- Python 3.11+
- Node.js 18+
- PostgreSQL
- Redis

### Local Development

1. **Backend Setup**:
   ```bash
   cd mentions_backend
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. **Frontend Setup**:
   ```bash
   cd mentions_frontend
   npm install
   npm run dev
   ```

3. **Environment Variables**:
   - Copy `.env.example` files in both backend and frontend
   - Configure your API keys and database credentials

## Documentation

See the `/docs` directory for comprehensive documentation:
- [00-INDEX.md](docs/00-INDEX.md) - Documentation index
- [01-TECH-STACK.md](docs/01-TECH-STACK.md) - Technology stack overview
- [10-LANGGRAPH-FLOW.md](docs/10-LANGGRAPH-FLOW.md) - AI workflow architecture

## Git Repository Structure

This project uses a hybrid approach:

- **Main Repository**: Contains all code and documentation for development
- **Backend Submodule**: Can be deployed independently
- **Frontend Submodule**: Can be deployed independently

This allows Cursor AI to work with the entire codebase while maintaining deployment flexibility.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.






