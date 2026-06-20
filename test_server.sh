#!/bin/bash

# Server Diagnostic Test Script for ggc.akwebs.in
# Run this script after server issues are resolved to verify everything works

DOMAIN="ggc.akwebs.in"
BASE_URL="https://${DOMAIN}"
API_BASE_URL="${BASE_URL}/api/"

echo "=========================================="
echo "Server Diagnostic Test for ${DOMAIN}"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: DNS Resolution
echo -n "Test 1: DNS Resolution... "
if nslookup ${DOMAIN} > /dev/null 2>&1; then
    IP=$(nslookup ${DOMAIN} | grep -A 1 "Name:" | tail -1 | awk '{print $2}')
    echo -e "${GREEN}✓${NC} Resolved to ${IP}"
else
    echo -e "${RED}✗${NC} DNS resolution failed"
    exit 1
fi

# Test 2: Ping Test
echo -n "Test 2: Server Reachability (Ping)... "
if ping -c 2 ${DOMAIN} > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Server is reachable"
else
    echo -e "${YELLOW}⚠${NC} Ping failed (may be blocked by firewall, but server might still work)"
fi

# Test 3: Port 443 (HTTPS) Connectivity
echo -n "Test 3: HTTPS Port (443) Connectivity... "
if timeout 5 bash -c "echo > /dev/tcp/${DOMAIN}/443" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Port 443 is open"
else
    echo -e "${RED}✗${NC} Port 443 is not accessible"
fi

# Test 4: Port 80 (HTTP) Connectivity
echo -n "Test 4: HTTP Port (80) Connectivity... "
if timeout 5 bash -c "echo > /dev/tcp/${DOMAIN}/80" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Port 80 is open"
else
    echo -e "${YELLOW}⚠${NC} Port 80 is not accessible"
fi

# Test 5: HTTPS Base URL
echo -n "Test 5: HTTPS Base URL Response... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 ${BASE_URL}/ 2>/dev/null)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    echo -e "${GREEN}✓${NC} HTTP ${HTTP_CODE}"
elif [ "$HTTP_CODE" = "000" ]; then
    echo -e "${RED}✗${NC} Connection failed/timeout"
else
    echo -e "${YELLOW}⚠${NC} HTTP ${HTTP_CODE}"
fi

# Test 6: SSL Certificate
echo -n "Test 6: SSL Certificate Validity... "
CERT_INFO=$(echo | openssl s_client -servername ${DOMAIN} -connect ${DOMAIN}:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
if [ $? -eq 0 ]; then
    CERT_END=$(echo "$CERT_INFO" | grep "notAfter" | cut -d= -f2)
    echo -e "${GREEN}✓${NC} Valid until ${CERT_END}"
else
    echo -e "${RED}✗${NC} SSL certificate check failed"
fi

# Test 7: API Directory
echo -n "Test 7: API Directory Access... "
API_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 ${API_BASE_URL} 2>/dev/null)
if [ "$API_CODE" = "200" ] || [ "$API_CODE" = "403" ] || [ "$API_CODE" = "404" ]; then
    echo -e "${GREEN}✓${NC} API directory accessible (HTTP ${API_CODE})"
elif [ "$API_CODE" = "000" ]; then
    echo -e "${RED}✗${NC} Connection failed"
else
    echo -e "${YELLOW}⚠${NC} HTTP ${API_CODE}"
fi

# Test 8: API Endpoints (without authentication)
echo ""
echo "Test 8: Testing API Endpoints (may fail without auth, but should not timeout)..."
ENDPOINTS=("login" "dashboard" "parking_cost_list" "get_vehicle_type")

for endpoint in "${ENDPOINTS[@]}"; do
    echo -n "  - /api/${endpoint}... "
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -X POST ${API_BASE_URL}${endpoint} 2>/dev/null)
    if [ "$RESPONSE" = "000" ]; then
        echo -e "${RED}✗${NC} Timeout/Connection failed"
    elif [ "$RESPONSE" = "401" ] || [ "$RESPONSE" = "403" ]; then
        echo -e "${GREEN}✓${NC} Endpoint exists (HTTP ${RESPONSE} - auth required)"
    elif [ "$RESPONSE" = "404" ]; then
        echo -e "${YELLOW}⚠${NC} Not found (HTTP 404)"
    elif [ "$RESPONSE" = "200" ]; then
        echo -e "${GREEN}✓${NC} Working (HTTP 200)"
    else
        echo -e "${YELLOW}⚠${NC} HTTP ${RESPONSE}"
    fi
done

# Test 9: Response Time
echo ""
echo -n "Test 9: Response Time... "
RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}" --max-time 10 ${BASE_URL}/ 2>/dev/null)
if [ ! -z "$RESPONSE_TIME" ] && [ "$RESPONSE_TIME" != "0.000" ]; then
    echo -e "${GREEN}✓${NC} ${RESPONSE_TIME}s"
else
    echo -e "${RED}✗${NC} Could not measure"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo "If all tests pass, your server should be working correctly."
echo "If any test fails, refer to SERVER_DIAGNOSTIC_GUIDE.md for troubleshooting steps."
echo ""
echo "API Base URL: ${API_BASE_URL}"
echo "Expected endpoints:"
echo "  - POST ${API_BASE_URL}login"
echo "  - POST ${API_BASE_URL}dashboard"
echo "  - POST ${API_BASE_URL}parking_cost_list"
echo "  - POST ${API_BASE_URL}get_vehicle_type"
echo "  - POST ${API_BASE_URL}get_history"
echo "  - POST ${API_BASE_URL}save"
echo "  - POST ${API_BASE_URL}chekout"
echo ""




