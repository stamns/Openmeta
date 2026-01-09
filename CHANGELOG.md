# Changelog

## [v1.1.0] PanSou Token Authentication Improvements - 2025-01-09

### 🎯 Critical Bug Fixes

Fixed critical issues with PanSou authentication:
1. **Token Expiry Management**: Token expiration now handled gracefully with auto-refresh
2. **Concurrent Request Race Condition**: Multiple concurrent requests no longer cause duplicate logins
3. **Search Timeout Configuration**: Search timeout now configurable via environment variable

### Changes

#### Token Management
- **backend/app/services/pansou.py**: Complete rewrite with TokenManager class
  - Reads dynamic `expires_in` from PanSou response
  - Implements "refresh 60 seconds early" mechanism (token valid for 59 minutes)
  - Clears token on login failure for automatic retry
  - Returns user-friendly error messages instead of crashing

#### Concurrency Control
- **backend/app/services/pansou.py**: Added `asyncio.Lock()` for thread-safe login
  - Implements Double-check locking pattern
  - 10 concurrent search requests now only login once
  - Reduces API call overhead and prevents rate limiting

#### Configuration
- **backend/app/services/pansou.py**: Uses `SEARCH_TIMEOUT` environment variable (default 15 seconds)
  - Removed hardcoded 10-second timeout
  - Configurable per deployment environment
  - Better timeout error handling with clear messages

#### Error Handling
- Friendly error messages for all failure scenarios
- Login failures return empty results with explanation
- Token expiry automatically triggers refresh
- Network errors don't crash the application
- All errors logged with emoji indicators for easy debugging

### Verification

Test script provided to verify all improvements:
```bash
python3 scripts/test-concurrent-search.py
```

**Success Criteria:**
- ✅ Single search returns results normally
- ✅ 10 concurrent searches only login once (verified via logs)
- ✅ Token expiry triggers auto-refresh without errors
- ✅ Network disconnection returns empty list instead of crashing
- ✅ Search timeout errors handled correctly

### Performance Impact

**Before:**
- 10 concurrent requests = 10 logins + 10 searches (~1-2 seconds overhead)

**After:**
- 10 concurrent requests = 1 login + 10 searches (~0.1-0.2 seconds overhead)
- Token cached for 59 minutes
- All requests within 59 minutes reuse same token

### Files Modified
- backend/app/services/pansou.py (complete rewrite)

### Files Added
- scripts/test-concurrent-search.py (concurrent testing script)
- docs/PANSOU-TOKEN-IMPROVEMENTS.md (detailed documentation)

### Related
- See [PANSOU-TOKEN-IMPROVEMENTS.md](docs/PANSOU-TOKEN-IMPROVEMENTS.md) for detailed technical documentation

---

## [SECURITY] Remove Hardcoded Sensitive Information - 2025-01-09

### 🚨 Critical Security Fix

Removed hardcoded PanSou credentials from the codebase to prevent potential security exposure.

### Changes

#### Fixed Security Vulnerabilities
- **backend/api/index.py**: Removed hardcoded default values for PANSOU_HOST, PANSOU_USER, and PANSOU_PWD
- **backend/app/settings.py**: Added `validate()` method to enforce required environment variables
- **backend/app/main.py**: Added environment variable validation on application startup
- **backend/.env.example**: Cleaned up duplicate entries

#### Security Improvements
- All sensitive information now must be provided via environment variables
- Application will fail to start with clear error messages if required environment variables are missing
- .env files are properly protected by .gitignore
- No hardcoded credentials in Python source files

### Verification

All security fixes have been verified:
- ✅ No hardcoded defaults in api/index.py
- ✅ settings.py validates all required variables
- ✅ app/main.py validates environment variables on startup
- ✅ .gitignore properly configured
- ✅ No hardcoded passwords found
- ✅ No hardcoded IP addresses found
- ✅ All Python files have valid syntax

### Breaking Changes

**This is a breaking change for deployments** - you must now explicitly set the following environment variables:

**Required:**
- `PANSOU_HOST` - PanSou server URL
- `PANSOU_USER` - PanSou username
- `PANSOU_PWD` - PanSou password

### Migration Guide

#### Local Development
```bash
cp backend/.env.example backend/.env
# Edit backend/.env with your actual credentials
uvicorn main:app --reload
```

#### Docker
```bash
export PANSOU_HOST=http://your-server.com
export PANSOU_USER=your-username
export PANSOU_PWD=your-password
docker-compose up --build
```

#### Vercel
1. Go to Project Settings → Environment Variables
2. Add: PANSOU_HOST, PANSOU_USER, PANSOU_PWD
3. Redeploy

### Testing

Run the security verification script:
```bash
bash scripts/test-env-validation.sh
```

### Files Modified
- backend/api/index.py
- backend/app/settings.py
- backend/app/main.py
- backend/.env.example

### Files Added
- SECURITY-FIXES.md (detailed documentation)
- scripts/test-env-validation.sh (verification script)
- CHANGELOG.md (this file)
