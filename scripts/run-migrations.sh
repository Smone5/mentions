#!/bin/bash
# Run database migrations against Supabase

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "=========================================="
echo "  Database Migration Runner"
echo "=========================================="
echo ""

# Check if DB_CONN is set
if [ -z "$DB_CONN" ]; then
    echo -e "${YELLOW}DB_CONN environment variable not set${NC}"
    echo ""
    echo "Please provide your database connection string:"
    echo "Format: postgresql://postgres:password@db.xxxxx.supabase.co:5432/postgres"
    echo ""
    read -p "Enter database connection string: " DB_CONN
    
    if [ -z "$DB_CONN" ]; then
        echo -e "${RED}Error: Database connection string is required${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}Testing database connection...${NC}"

# Test connection
if psql "$DB_CONN" -c "SELECT version();" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Database connection successful${NC}"
else
    echo -e "${RED}✗ Database connection failed${NC}"
    echo "Please check your connection string and try again"
    exit 1
fi

echo ""
echo -e "${BLUE}Checking extensions...${NC}"

# Check if extensions are enabled
VECTOR_EXISTS=$(psql "$DB_CONN" -t -c "SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'vector');" | tr -d ' ')
UUID_EXISTS=$(psql "$DB_CONN" -t -c "SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'uuid-ossp');" | tr -d ' ')

if [ "$VECTOR_EXISTS" = "t" ]; then
    echo -e "${GREEN}✓ vector extension enabled${NC}"
else
    echo -e "${YELLOW}⚠ vector extension not found, enabling...${NC}"
    psql "$DB_CONN" -c "CREATE EXTENSION IF NOT EXISTS vector;" || {
        echo -e "${RED}✗ Failed to enable vector extension${NC}"
        exit 1
    }
    echo -e "${GREEN}✓ vector extension enabled${NC}"
fi

if [ "$UUID_EXISTS" = "t" ]; then
    echo -e "${GREEN}✓ uuid-ossp extension enabled${NC}"
else
    echo -e "${YELLOW}⚠ uuid-ossp extension not found, enabling...${NC}"
    psql "$DB_CONN" -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";' || {
        echo -e "${RED}✗ Failed to enable uuid-ossp extension${NC}"
        exit 1
    }
    echo -e "${GREEN}✓ uuid-ossp extension enabled${NC}"
fi

echo ""
echo -e "${BLUE}Running migrations...${NC}"

MIGRATION_DIR="mentions_backend/db/migrations"

if [ ! -d "$MIGRATION_DIR" ]; then
    echo -e "${RED}Error: Migration directory not found: $MIGRATION_DIR${NC}"
    exit 1
fi

# Run migrations in order
for migration in $(ls "$MIGRATION_DIR"/*.sql | sort); do
    echo ""
    echo -e "${BLUE}Running: $(basename $migration)${NC}"
    
    if psql "$DB_CONN" -f "$migration" 2>&1; then
        echo -e "${GREEN}✓ Migration completed: $(basename $migration)${NC}"
    else
        echo -e "${RED}✗ Migration failed: $(basename $migration)${NC}"
        echo "Please check the error above and fix it before continuing"
        exit 1
    fi
done

echo ""
echo "=========================================="
echo -e "${GREEN}All migrations completed successfully!${NC}"
echo "=========================================="
echo ""

# Verify tables were created
echo -e "${BLUE}Verifying tables...${NC}"
TABLE_COUNT=$(psql "$DB_CONN" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" | tr -d ' ')
echo -e "${GREEN}✓ Found $TABLE_COUNT tables${NC}"

# List some key tables
echo ""
echo "Key tables created:"
psql "$DB_CONN" -t -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE' ORDER BY table_name LIMIT 10;" | sed 's/^/  - /'

echo ""
echo -e "${GREEN}Database setup complete!${NC}"

