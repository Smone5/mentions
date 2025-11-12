#!/bin/bash
# Test database connection to Supabase

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "=========================================="
echo "  Database Connection Test"
echo "=========================================="
echo ""

# Check if DB_CONN is set
if [ -z "$DB_CONN" ]; then
    echo -e "${YELLOW}DB_CONN environment variable not set${NC}"
    echo ""
    read -p "Enter database connection string: " DB_CONN
    
    if [ -z "$DB_CONN" ]; then
        echo -e "${RED}Error: Database connection string is required${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}Testing connection...${NC}"

# Test basic connection
if psql "$DB_CONN" -c "SELECT version();" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Connection successful${NC}"
else
    echo -e "${RED}✗ Connection failed${NC}"
    echo "Please check your connection string"
    exit 1
fi

echo ""
echo -e "${BLUE}Checking PostgreSQL version...${NC}"
psql "$DB_CONN" -c "SELECT version();" | head -3

echo ""
echo -e "${BLUE}Checking extensions...${NC}"

# Check extensions
VECTOR=$(psql "$DB_CONN" -t -c "SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'vector');" | tr -d ' ')
UUID=$(psql "$DB_CONN" -t -c "SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'uuid-ossp');" | tr -d ' ')

if [ "$VECTOR" = "t" ]; then
    echo -e "${GREEN}✓ vector extension enabled${NC}"
else
    echo -e "${RED}✗ vector extension not enabled${NC}"
fi

if [ "$UUID" = "t" ]; then
    echo -e "${GREEN}✓ uuid-ossp extension enabled${NC}"
else
    echo -e "${RED}✗ uuid-ossp extension not enabled${NC}"
fi

echo ""
echo -e "${BLUE}Checking tables...${NC}"
TABLE_COUNT=$(psql "$DB_CONN" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" | tr -d ' ')

if [ "$TABLE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $TABLE_COUNT tables${NC}"
    echo ""
    echo "Tables:"
    psql "$DB_CONN" -t -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE' ORDER BY table_name;" | sed 's/^/  - /'
else
    echo -e "${YELLOW}⚠ No tables found (migrations may not have been run)${NC}"
fi

echo ""
echo -e "${GREEN}Connection test complete!${NC}"

