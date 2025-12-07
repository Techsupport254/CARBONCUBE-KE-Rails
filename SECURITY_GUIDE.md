# 🔒 Carbon Security Protection Guide

## 🚨 Incident Summary
**Date:** December 6, 2025
**Attack Type:** Container Malware Infection
**Affected:** Frontend Container (`carbon_frontend`)
**Impact:** Service downtime, potential data exposure
**Resolution:** Container rebuilt from clean image

## 🛡️ Protection Strategy

### 1. **Container Security Hardening**

#### Secure Dockerfile Implementation
- ✅ Use minimal base images (`node:*-alpine`)
- ✅ Create non-root users
- ✅ Implement proper file permissions
- ✅ Add health checks
- ✅ Use `dumb-init` for signal handling

**Files Created:**
- `frontend-carbon/Dockerfile.secure` - Hardened container configuration
- `frontend-carbon/.dockerignore` - Security exclusions

#### Vulnerability Scanning
```bash
# Install Trivy scanner
sudo apt install -y trivy

# Scan your images
trivy image carbon_frontend:latest

# Scan running containers
trivy container carbon_frontend_1

# CI/CD integration
trivy image --exit-code 1 --no-progress your-image:tag
```

### 2. **Host System Security**

#### Automated Security Setup
Run the provided `security-setup.sh` script to implement:
- ✅ SSH hardening (key-only authentication)
- ✅ Firewall configuration (UFW)
- ✅ Automatic security updates
- ✅ Fail2Ban intrusion prevention
- ✅ Antivirus scanning (ClamAV)
- ✅ Rootkit detection (rkhunter, chkrootkit)
- ✅ System auditing

```bash
# Make executable and run
chmod +x security-setup.sh
sudo ./security-setup.sh
```

### 3. **Monitoring & Alerting**

#### Comprehensive Monitoring Setup
Run the `monitoring-setup.sh` script for:
- ✅ Prometheus metrics collection
- ✅ Grafana dashboards
- ✅ Alertmanager notifications
- ✅ Container security monitoring
- ✅ Real-time threat detection

```bash
chmod +x monitoring-setup.sh
sudo ./monitoring-setup.sh
```

#### Key Metrics to Monitor
- CPU/Memory usage spikes
- Unusual network connections
- Failed authentication attempts
- Suspicious processes
- Container health status

### 4. **CI/CD Security Pipeline**

#### GitHub Actions Security Workflow
```yaml
# .github/workflows/security.yml
name: Security Checks
on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Dependency Check
        uses: dependency-check/Dependency-Check_Action@main
        with:
          project: 'Carbon'
          path: '.'
          format: 'ALL'

      - name: CodeQL Analysis
        uses: github/codeql-action/init@v3
        with:
          languages: javascript, typescript
```

#### Dependency Security
```bash
# Audit npm dependencies
npm audit
npm audit fix

# Use npm ci for reproducible builds
npm ci

# Check for outdated packages
npm outdated

# Use Snyk for additional scanning
npx snyk test
npx snyk monitor
```

### 5. **Runtime Security**

#### Docker Security Best Practices
```yaml
# docker-compose.prod.yml (security additions)
services:
  frontend:
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp:noexec,nosuid,size=100m
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    ulimits:
      nofile: 1024:1024
```

#### Container Scanning in Production
```bash
# Regular container vulnerability scans
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock
  aquasec/trivy:latest image --exit-code 1 carbon_frontend:latest

# Runtime security monitoring
docker run -d --name falco \
  --privileged \
  -v /var/run/docker.sock:/host/var/run/docker.sock \
  -v /proc:/host/proc:ro \
  falcosecurity/falco:latest
```

### 6. **Incident Response Plan**

#### Automated Response Script
The `incident-response.sh` script provides:
- ✅ Automatic evidence collection
- ✅ Suspicious process termination
- ✅ System state backup
- ✅ Malware scanning

#### Response Checklist
1. **Detection**: Alert triggered
2. **Containment**: Isolate affected systems
3. **Eradication**: Remove malicious code
4. **Recovery**: Restore from clean backups
5. **Lessons Learned**: Update security measures

### 7. **Backup & Recovery**

#### Secure Backup Strategy
```bash
# Database backup script
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/secure/backups"

# Create encrypted backup
docker exec carbon_postgres_1 pg_dump -U postgres carbon_prod | \
  gpg -e -r backup@carboncube-ke.com > $BACKUP_DIR/db_$TIMESTAMP.sql.gpg

# Backup configurations
tar -czf $BACKUP_DIR/config_$TIMESTAMP.tar.gz \
  /etc/nginx/sites-available/carboncube \
  /etc/prometheus/ \
  --exclude='*.log'

# Test backup integrity
gpg -d $BACKUP_DIR/db_$TIMESTAMP.sql.gpg | head -5
```

#### Recovery Testing
- Monthly recovery drills
- Backup integrity verification
- Recovery time objective (RTO) monitoring

### 8. **Access Control**

#### Principle of Least Privilege
- ✅ Non-root container users
- ✅ Minimal Docker capabilities
- ✅ Read-only filesystems where possible
- ✅ Network segmentation

#### Secrets Management
```yaml
# Use Docker secrets or external vaults
services:
  backend:
    secrets:
      - db_password
      - api_keys

secrets:
  db_password:
    file: ./secrets/db_password.txt
  api_keys:
    file: ./secrets/api_keys.json
```

### 9. **Network Security**

#### Web Application Firewall (WAF)
```nginx
# nginx.conf - Add to server block
location / {
    # ModSecurity WAF
    modsecurity on;
    modsecurity_rules_file /etc/nginx/modsec/main.conf;

    # Rate limiting
    limit_req zone=api burst=10 nodelay;
    limit_req_status 429;

    proxy_pass http://frontend:3000;
}
```

#### Network Policies
```yaml
# Kubernetes NetworkPolicy (if migrating to K8s)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: carbon-frontend-policy
spec:
  podSelector:
    matchLabels:
      app: carbon-frontend
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: carbon-backend
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: carbon-backend
        - podSelector:
            matchLabels:
              app: carbon-redis
```

### 10. **Compliance & Auditing**

#### Security Audits
- Monthly vulnerability assessments
- Quarterly penetration testing
- Annual security audits
- Dependency license compliance

#### Logging & Monitoring
```bash
# Centralized logging
docker run -d \
  --name elk-stack \
  -p 5601:5601 -p 9200:9200 -p 5044:5044 \
  sebp/elk

# Log aggregation
docker run -d \
  --name fluentd \
  -v /var/log:/fluentd/log \
  fluent/fluentd
```

## 🚀 Implementation Priority

### Immediate (Week 1)
1. Run `security-setup.sh` on VPS
2. Deploy secure Dockerfile
3. Set up basic monitoring
4. Implement vulnerability scanning

### Short-term (Month 1)
1. Configure alerting system
2. Set up CI/CD security pipeline
3. Implement secrets management
4. Create incident response procedures

### Long-term (Quarter 1)
1. Network segmentation
2. Web application firewall
3. Regular penetration testing
4. Compliance certifications

## 📞 Emergency Contacts

- **Security Incidents:** security@carboncube-ke.com
- **Infrastructure:** infra@carboncube-ke.com
- **Development:** dev@carboncube-ke.com

## 📚 Additional Resources

- [Docker Security Best Practices](https://docs.docker.com/develop/dev-best-practices/security/)
- [OWASP Container Security](https://owasp.org/www-project-docker-top-10/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)

---

**Remember:** Security is an ongoing process, not a one-time implementation. Regular updates, monitoring, and testing are crucial for maintaining protection against evolving threats.
