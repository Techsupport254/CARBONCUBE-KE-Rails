# Backend Security Guide

## GitGuardian Compliance

### ✅ **Current Status:**
- **Environment Files**: Properly managed
- **Credentials**: Encrypted and secure
- **API Keys**: Not hardcoded
- **Secrets**: Using Rails credentials system

## Environment File Management

### **Backend Environment Files:**
```bash
# Local development (NOT tracked by git)
.env
.env.local

# Template file (tracked by git)
.env.example
```

### **Rails Credentials System:**
```bash
# Encrypted credentials (safe to track)
config/credentials.yml.enc

# Master key (NOT tracked by git)
config/master.key
```

## Security Best Practices

### **1. Rails Credentials**
```bash
# Edit encrypted credentials
rails credentials:edit

# View encrypted credentials
rails credentials:show

# Set environment-specific credentials
rails credentials:edit --environment production
```

### **2. Environment Variables**
```ruby
# ✅ Good - Use environment variables
api_key = ENV['CLOUDINARY_API_KEY']

# ❌ Bad - Hardcode credentials
api_key = "sk-1234567890abcdef"
```

### **3. Database Configuration**
```yaml
# config/database.yml
production:
  url: <%= ENV['DATABASE_URL'] %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
```

## Deployment Security

### **Production Deployment:**
1. Set `config/master.key` on your server
2. Use Rails credentials for sensitive data
3. Set environment variables for external services
4. Never commit `.env` files

### **Environment Variables Required:**
```bash
# Database
DATABASE_URL=postgresql://user:password@host:port/database

# External Services
CLOUDINARY_API_KEY=your_cloudinary_key
CLOUDINARY_API_SECRET=your_cloudinary_secret

# Rails
RAILS_ENV=production
RAILS_MASTER_KEY=your_master_key
```

## Monitoring and Prevention

### **Pre-commit Security Checks:**
```bash
# Check for hardcoded credentials
grep -r -i "api_key\|secret\|password\|token" app/ --include="*.rb"

# Check for tracked sensitive files
git ls-files | grep -E "\.(env|key|pem|secret|credential)"
```

### **Regular Security Audits:**
1. Review all environment variables
2. Check for hardcoded credentials
3. Verify Rails credentials encryption
4. Monitor GitGuardian alerts

## Emergency Response

### **If Credentials Are Exposed:**
1. **Immediately rotate all exposed credentials**
2. **Update Rails credentials**: `rails credentials:edit`
3. **Update environment variables on server**
4. **Monitor for unauthorized access**

### **Credential Rotation Checklist:**
- [ ] Database passwords
- [ ] Cloudinary credentials
- [ ] JWT secrets
- [ ] OAuth tokens
- [ ] API keys
- [ ] SSL certificates

## Summary

✅ **Backend is GitGuardian compliant**
✅ **Environment files are properly managed**
✅ **Rails credentials system is secure**
✅ **No hardcoded credentials found**

Your backend repository is secure and follows best practices.
