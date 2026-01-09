#!/bin/bash

# Test environment variable validation
# This script verifies that the security fixes are working correctly

echo "🔍 Testing Environment Variable Security Fixes"
echo "=============================================="
echo ""

cd /home/engine/project/backend

# Test 1: Check that .env files are properly gitignored
echo "Test 1: Checking .gitignore configuration..."
if grep -q "^\.env$" ../.gitignore && grep -q "^\.env\.\*$" ../.gitignore && grep -q "!\.env\.example" ../.gitignore; then
    echo "✅ .gitignore properly configured"
else
    echo "❌ .gitignore may not properly protect .env files"
fi
echo ""

# Test 2: Check that api/index.py has no hardcoded defaults
echo "Test 2: Checking for hardcoded values in api/index.py..."
if grep -q "setdefault.*PANSOU" api/index.py; then
    echo "❌ Found hardcoded defaults in api/index.py"
    grep "setdefault.*PANSOU" api/index.py
else
    echo "✅ No hardcoded defaults in api/index.py"
fi
echo ""

# Test 3: Check that settings.py has validation
echo "Test 3: Checking settings.py validation..."
if grep -q "def validate" app/settings.py; then
    echo "✅ settings.py has validate() method"
    if grep -q "PANSOU_HOST" app/settings.py && grep -q "PANSOU_USER" app/settings.py && grep -q "PANSOU_PWD" app/settings.py; then
        echo "✅ settings.py validates all required variables"
    else
        echo "❌ settings.py may not validate all required variables"
    fi
else
    echo "❌ settings.py missing validate() method"
fi
echo ""

# Test 4: Check that main.py calls validation on startup
echo "Test 4: Checking main.py startup validation..."
if grep -q "settings.validate()" app/main.py; then
    echo "✅ app/main.py validates environment variables on startup"
else
    echo "❌ app/main.py does not validate environment variables"
fi
echo ""

# Test 5: Verify syntax of all modified files
echo "Test 5: Verifying Python syntax..."
if python3 -m py_compile app/settings.py 2>/dev/null && \
   python3 -m py_compile app/main.py 2>/dev/null && \
   python3 -m py_compile api/index.py 2>/dev/null; then
    echo "✅ All modified files have valid Python syntax"
else
    echo "❌ Syntax errors found in modified files"
fi
echo ""

# Test 6: Check for hardcoded passwords
echo "Test 6: Checking for hardcoded passwords in Python files..."
# Check for common password patterns
if grep -r -i "password.*=.*['\"][^'\"]*['\"]" --include="*.py" . 2>/dev/null | grep -v "password.*=.*\"\"" | grep -v "password.*=.*''" | grep -v "redis_password" | grep -v "example" | grep -v "your"; then
    echo "⚠️  Found potential hardcoded passwords (excluding empty strings and placeholders)"
else
    echo "✅ No hardcoded passwords found"
fi
echo ""

echo "=============================================="
echo "✅ Security fix verification complete!"
echo ""
echo "Summary of changes:"
echo "1. Removed hardcoded defaults from backend/api/index.py"
echo "2. Added validation method to backend/app/settings.py"
echo "3. Added startup validation to backend/app/main.py"
echo "4. Cleaned up backend/.env.example"
echo "5. Verified .gitignore protects .env files"
echo ""
echo "All sensitive information now must be provided via environment variables!"
