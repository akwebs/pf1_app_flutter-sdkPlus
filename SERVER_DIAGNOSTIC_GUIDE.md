# Server Diagnostic Guide for ggc.akwebs.in

## Current Issue
- **Domain**: `ggc.akwebs.in`
- **IP**: `89.117.74.148`
- **Status**: Server is reachable but web services are not responding
- **Port 80 (HTTP)**: Open but timing out
- **Port 443 (HTTPS)**: Blocked/timing out

## API Endpoints Required
Your Flutter app expects these endpoints at `https://ggc.akwebs.in/api/`:
- `POST /api/login`
- `POST /api/dashboard`
- `POST /api/parking_cost_list`
- `POST /api/get_vehicle_type`
- `POST /api/get_history`
- `POST /api/save` (check-in)
- `POST /api/chekout` (checkout)

## What You Can Check with User-Level CWP Access

### 1. Domain Status
**Path**: CWP Panel → **Domains** → Find `ggc.akwebs.in`
- ✅ Check if domain is listed and active
- ✅ Verify Document Root path exists
- ✅ Check domain status (should be "Active")

### 2. File Manager
**Path**: CWP Panel → **File Manager**
- ✅ Navigate to domain's public_html directory
- ✅ Check if `api/` folder exists
- ✅ Verify PHP files are present
- ✅ Check file permissions (should be 644 for files, 755 for directories)

### 3. Error Logs (User Level)
**Path**: CWP Panel → **Logs** → **Error Logs**
- ✅ Check Apache Error Log for recent errors
- ✅ Look for PHP errors, permission errors, or 500 errors
- ✅ Check access logs for connection attempts

### 4. SSL Certificate Status
**Path**: CWP Panel → **SSL/TLS Status**
- ✅ Check if SSL certificate is installed for `ggc.akwebs.in`
- ✅ Verify certificate expiration date
- ✅ Check if SSL is enabled

### 5. Database Status (if applicable)
**Path**: CWP Panel → **MySQL Databases**
- ✅ Verify database exists and is accessible
- ✅ Check database user permissions

## What Requires Admin/Root Access (Contact Server Admin)

### Critical Issues That Need Admin:
1. **Web Server Service Status**
   - Apache/Nginx service might be stopped
   - Need to restart: `systemctl restart apache2` or `systemctl restart nginx`

2. **Firewall Configuration**
   - Port 443 (HTTPS) appears blocked
   - Need to open: `ufw allow 443` or configure firewall rules

3. **Apache/Nginx Configuration**
   - Virtual host might be misconfigured
   - SSL configuration might be missing
   - Need to check: `/etc/apache2/sites-available/` or `/etc/nginx/sites-available/`

4. **PHP Configuration**
   - PHP might not be running
   - PHP-FPM might be stopped
   - Need to check: `php -v` and `systemctl status php-fpm`

5. **Disk Space**
   - Server might be out of disk space
   - Need to check: `df -h`

## Immediate Actions to Request from Admin

1. **Restart Web Server**
   ```
   systemctl restart apache2
   # OR
   systemctl restart nginx
   ```

2. **Check Firewall Rules**
   ```bash
   # Check if ports are open
   netstat -tulpn | grep -E ':(80|443)'
   # Open ports if needed
   ufw allow 80/tcp
   ufw allow 443/tcp
   ```

3. **Check Apache/Nginx Status**
   ```bash
   systemctl status apache2
   # OR
   systemctl status nginx
   ```

4. **View Recent Error Logs**
   ```bash
   tail -100 /var/log/apache2/error.log
   # OR
   tail -100 /var/log/nginx/error.log
   ```

5. **Test SSL Configuration**
   ```bash
   apache2ctl -S
   # OR
   nginx -t
   ```

## Testing Once Server is Fixed

After the server is fixed, run the test script:
```bash
bash test_server.sh
```

This will test:
- HTTPS connectivity
- API endpoint availability
- SSL certificate validity
- Response times

## Common CWP Issues and Solutions

### Issue: Domain shows "Suspended"
- **Solution**: Contact admin to unsuspend the domain

### Issue: SSL Certificate Expired
- **Solution**: Request admin to renew Let's Encrypt certificate via CWP

### Issue: PHP Errors in Logs
- **Solution**: Check PHP version compatibility, update if needed

### Issue: 500 Internal Server Error
- **Solution**: Check file permissions, .htaccess rules, PHP errors

### Issue: Connection Timeout
- **Solution**: Check firewall, web server status, DNS propagation

## Contact Information Template

When contacting your server admin, use this template:

```
Subject: Server Issue - ggc.akwebs.in Not Responding

Hi,

The domain ggc.akwebs.in (IP: 89.117.74.148) is currently not responding:
- Port 80 connects but times out
- Port 443 is blocked/timing out
- DNS resolves correctly
- Server is pingable

Please check:
1. Apache/Nginx service status
2. Firewall rules for ports 80 and 443
3. SSL certificate status
4. Recent error logs
5. Disk space availability

The application requires these API endpoints:
- https://ggc.akwebs.in/api/login
- https://ggc.akwebs.in/api/dashboard
- https://ggc.akwebs.in/api/parking_cost_list
- And other endpoints in /api/ directory

Thank you!
```




