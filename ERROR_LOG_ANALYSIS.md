# Error Log Analysis for ggc.akwebs.in

## Critical Issues Found

### 1. **PHP-FPM Error (MOST CRITICAL)**
```
[proxy_fcgi:error] AH01071: Got error 'Primary script unknown'
```
**Meaning**: PHP-FPM cannot find the requested PHP script file. This is likely why your API is not working.

**Possible Causes**:
- Script file doesn't exist at the requested path
- Incorrect DocumentRoot configuration
- Wrong file permissions
- PHP-FPM pool configuration mismatch

### 2. **ModSecurity (CWAF) Blocking Requests**
Multiple ModSecurity blocks are shown, but most appear to be from bots/scanners. However, ModSecurity might also be blocking legitimate API requests.

## Log Breakdown

### Security Blocks (These are GOOD - blocking attackers):
- `.env` file access attempts
- `wp-config.php` access attempts  
- `.git/config` access attempts
- `laravel.log` access attempts
- Configuration file access attempts

**These are normal security blocks** - ModSecurity is doing its job blocking malicious requests.

### The Real Problem:
The `Primary script unknown` error suggests:
1. **API files might not exist** at the expected location
2. **DocumentRoot might be misconfigured**
3. **PHP-FPM pool path doesn't match actual file location**

## What to Check in CWP Panel

### 1. Verify API Files Exist
**Path**: CWP Panel → **File Manager**
- Navigate to: `public_html/api/` (or your domain's document root)
- Check if these files exist:
  - `index.php` or `api.php`
  - Other PHP files for your endpoints

### 2. Check Document Root
**Path**: CWP Panel → **Domains** → `ggc.akwebs.in` → **Edit**
- Verify the Document Root path
- Should typically be: `/home/username/public_html` or `/home/username/domains/ggc.akwebs.in/public_html`

### 3. Check PHP-FPM Configuration
**Path**: CWP Panel → **PHP Settings** or **PHP Selector**
- Verify PHP version is selected
- Check PHP-FPM status

### 4. Check File Permissions
**Path**: CWP Panel → **File Manager**
- API files should have permissions: `644` (files) and `755` (directories)
- Owner should be your user account

### 5. Check ModSecurity Logs for API Requests
**Path**: CWP Panel → **Logs** → **ModSecurity Log**
- Look for blocks on `/api/login`, `/api/dashboard`, etc.
- If you see blocks on legitimate API endpoints, they need to be whitelisted

## Solutions

### Solution 1: Fix PHP-FPM "Primary script unknown" Error

**If you have admin access or can request from admin:**

1. **Check the actual file path**:
   ```bash
   ls -la /home/username/domains/ggc.akwebs.in/public_html/api/
   ```

2. **Check PHP-FPM pool configuration**:
   ```bash
   # Find PHP-FPM pool config
   grep -r "ggc.akwebs.in" /etc/php-fpm.d/
   # Or check CWP PHP-FPM config
   cat /usr/local/cwpsrv/htdocs/resources/scripts/php-fpm-pool.conf
   ```

3. **Verify DocumentRoot in Apache**:
   ```bash
   apache2ctl -S | grep ggc.akwebs.in
   ```

**Common fixes**:
- Ensure DocumentRoot matches actual file location
- Check PHP-FPM pool `chroot` or `chdir` settings
- Verify file ownership matches PHP-FPM user

### Solution 2: Whitelist API Endpoints in ModSecurity

**If ModSecurity is blocking legitimate API requests:**

1. **Check if API requests are being blocked**:
   - Look in ModSecurity logs for `/api/` endpoints
   - If you see blocks, note the rule ID

2. **Whitelist API directory** (requires admin or CWP access):
   - CWP Panel → **Security** → **ModSecurity Rules**
   - Add exception for `/api/*` paths
   - Or disable specific rules for API directory

3. **Temporary test** (admin only):
   ```bash
   # Disable ModSecurity for API directory in .htaccess
   # Add to public_html/api/.htaccess:
   <IfModule mod_security.c>
     SecRuleEngine Off
   </IfModule>
   ```
   **Note**: Only for testing! Re-enable after confirming it works.

### Solution 3: Check API File Structure

Your API should be accessible at:
- `https://ggc.akwebs.in/api/login`
- `https://ggc.akwebs.in/api/dashboard`
- etc.

Verify the file structure matches:
```
public_html/
  └── api/
      ├── index.php (or router file)
      └── [other API files]
```

## Testing Steps

1. **Test if API directory is accessible**:
   ```bash
   curl -I https://ggc.akwebs.in/api/
   ```

2. **Test a specific endpoint**:
   ```bash
   curl -X POST https://ggc.akwebs.in/api/login \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "mobile=test&pass=test"
   ```

3. **Check for ModSecurity blocks**:
   - Look in CWP ModSecurity logs immediately after testing
   - If you see 403 errors, ModSecurity is blocking

## Action Items

### Immediate (You can do):
1. ✅ Check File Manager for API files
2. ✅ Verify file permissions
3. ✅ Check Document Root in domain settings
4. ✅ Look for ModSecurity blocks on `/api/` endpoints

### Requires Admin:
1. ⚠️ Fix PHP-FPM "Primary script unknown" error
2. ⚠️ Verify PHP-FPM pool configuration
3. ⚠️ Whitelist API endpoints in ModSecurity (if needed)
4. ⚠️ Check Apache virtual host configuration

## Contact Admin Template

```
Subject: PHP-FPM Error - Primary script unknown for ggc.akwebs.in

Hi,

The server logs show a critical error:
[proxy_fcgi:error] AH01071: Got error 'Primary script unknown'

This is preventing the API from working. Please check:

1. PHP-FPM pool configuration for ggc.akwebs.in
2. DocumentRoot matches actual file location
3. File permissions and ownership
4. PHP-FPM service status

The API should be accessible at:
https://ggc.akwebs.in/api/

Also, please check if ModSecurity is blocking legitimate API requests
at /api/login, /api/dashboard, etc.

Thank you!
```




