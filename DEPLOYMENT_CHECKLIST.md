# 🚀 DEPLOYMENT CHECKLIST

## Pre-Deployment

### ✅ Code Review
- [ ] Backend: All routes tested locally
- [ ] Mobile: UI screens implemented
- [ ] Documentation: Updated and accurate
- [ ] Environment: Credentials set correctly

### ✅ Database
- [ ] Backup production database
- [ ] Test migration on staging
- [ ] `008_add_subscriptions.sql` ready
- [ ] All schema changes verified

### ✅ CamerPay Setup
- [ ] API Keys obtained
- [ ] Webhook Secret configured
- [ ] Test environment working
- [ ] Production keys ready (separate from test)

### ✅ Environment Variables
- [ ] `.env` file created with all variables
- [ ] No credentials in source code
- [ ] Staging `.env` ready
- [ ] Production `.env` ready

---

## Database Deployment

### Step 1: Apply Migration
```bash
# Using Supabase Studio:
# 1. Go to SQL Editor
# 2. Copy content of: supabase/migrations/008_add_subscriptions.sql
# 3. Run the migration
# 4. Verify:

SELECT column_name FROM information_schema.columns 
WHERE table_name = 'technicians' AND table_schema = 'public';

# Should include: subscription_type, subscription_status, etc.

# Verify new table:
SELECT table_name FROM information_schema.tables 
WHERE table_name = 'technician_subscriptions';
```

### Step 2: Verify Schema
```sql
-- Check technicians table
\d technicians;

-- Check new subscription table
\d technician_subscriptions;

-- Check indexes
SELECT indexname FROM pg_indexes WHERE tablename = 'technician_subscriptions';
```

---

## Backend Deployment

### Step 1: Install Dependencies
```bash
cd backend

# Check if axios is installed (should be)
npm list axios

# If not:
npm install axios
```

### Step 2: Environment Variables
```bash
# File: backend/.env
PORT=3000
NODE_ENV=production

SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-key

# CamerPay Configuration
CAMERPAY_API_KEY=your-api-key
CAMERPAY_SECRET_KEY=your-secret-key
CAMERPAY_WEBHOOK_SECRET=your-webhook-secret

# Subscription Configuration
SUBSCRIPTION_MONTHLY_AMOUNT=2000
SUBSCRIPTION_YEARLY_AMOUNT=20000
SUBSCRIPTION_TRIAL_DAYS=30
CURRENCY_CODE=XAF

# Optional
BACKEND_URL=https://your-domain.com
```

### Step 3: Test Locally
```bash
cd backend

# Start server
npm start

# Test endpoints
curl http://localhost:3000/health

# Should return: {"status":"OK","message":"TechLink API running"}
```

### Step 4: Deploy to Production
```bash
# Using Railway / Heroku / Your hosting:

# 1. Push to repository
git add .
git commit -m "chore: Add CamerPay integration and subscription system"
git push origin main

# 2. Deploy (automatic or manual depending on platform)
# Your platform will:
# - Install dependencies
# - Apply environment variables
# - Restart backend

# 3. Verify production
curl https://your-domain.com/health
```

---

## CamerPay Webhook Configuration

### Step 1: Get Webhook URL
Your backend URL: `https://your-domain.com/camerpay/webhook`

### Step 2: Configure in CamerPay Dashboard
1. Go to: https://camerpay.biz/client/api
2. Click: "Configuration webhook"
3. Enter URL: `https://your-domain.com/camerpay/webhook`
4. Select events:
   - [ ] payment.success
   - [ ] payment.failed
   - [ ] payment.cancelled
5. Save configuration

### Step 3: Test Webhook
```bash
# Trigger test webhook
curl -X POST https://your-domain.com/camerpay/webhook \
  -H "X-CamerPay-Signature: test" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "payment.success",
    "data": {
      "reference": "TEST_123",
      "amount": 50000,
      "metadata": {
        "payment_type": "mission"
      }
    }
  }'

# Check logs for webhook processing
```

---

## Mobile Deployment

### Step 1: Update Dependencies
```yaml
# File: mobile/pubspec.yaml
dependencies:
  http: ^0.13.0  # Ensure http is in dependencies
  # other packages...
```

### Step 2: Implement UI Screens
- [ ] `subscription_screen.dart` created
- [ ] `payment_screen.dart` updated (no commission)
- [ ] `subscription_status_widget.dart` created
- [ ] `register_screen.dart` integrated
- [ ] `technician_home_screen.dart` integrated

### Step 3: Update CamerPayService URL
```dart
// File: mobile/lib/data/services/camerpay_service.dart

// Update backend URL to production:
static const String _backendUrl = 'https://your-domain.com';

// Not:
static const String _backendUrl = 'http://localhost:3000';
```

### Step 4: Build for Release
```bash
cd mobile

# iOS
flutter build ios --release

# Android
flutter build apk --release

# Or both
flutter build appbundle
```

### Step 5: Deploy to App Stores
- [ ] iOS: Upload to App Store
- [ ] Android: Upload to Play Store
- [ ] Wait for approval (usually 1-3 days)

---

## Post-Deployment Verification

### ✅ Backend Tests
```bash
# 1. Health check
curl https://your-domain.com/health

# 2. Test payment endpoint
curl -X POST https://your-domain.com/api/payments/initialize \
  -H "Content-Type: application/json" \
  -d '{
    "missionId": "test-123",
    "amount": 50000,
    "clientId": "client-123",
    "clientPhone": "+237123456789",
    "clientEmail": "test@test.com",
    "description": "Test"
  }'

# 3. Test subscription endpoint
curl -X POST https://your-domain.com/api/subscriptions/start-trial \
  -H "Content-Type: application/json" \
  -d '{"technicianId": "tech-123"}'

# 4. Test subscription status
curl https://your-domain.com/api/subscriptions/status/tech-123
```

### ✅ Database Verification
```sql
-- Check technician has trial
SELECT id, subscription_type, subscription_status, trial_end_date
FROM technicians
WHERE subscription_type = 'trial'
LIMIT 1;

-- Check subscription history
SELECT * FROM technician_subscriptions
ORDER BY created_at DESC
LIMIT 5;
```

### ✅ Mobile Testing
1. Install app from TestFlight / Internal Testing
2. Register as technician
3. Verify trial starts automatically
4. Complete mission payment
5. Verify technician receives 100%
6. Test subscription renewal

---

## Rollback Plan

### If Backend Deployment Fails
```bash
# Revert to previous version
git revert HEAD
git push origin main

# Or deploy previous commit
git checkout <previous-commit-hash>
git push origin main --force

# Restart backend service
```

### If Database Migration Fails
```sql
-- Rollback migration manually
DROP TABLE IF EXISTS technician_subscriptions;
ALTER TABLE technicians 
DROP COLUMN IF EXISTS subscription_type,
DROP COLUMN IF EXISTS subscription_status,
DROP COLUMN IF EXISTS subscription_start_date,
DROP COLUMN IF EXISTS subscription_end_date,
DROP COLUMN IF EXISTS trial_start_date,
DROP COLUMN IF EXISTS trial_end_date,
DROP COLUMN IF EXISTS subscription_price_paid,
DROP COLUMN IF EXISTS subscription_payment_reference;

ALTER TABLE payments
DROP COLUMN IF EXISTS commission_percentage,
DROP COLUMN IF EXISTS is_mission_payment,
DROP COLUMN IF EXISTS camerpay_reference,
DROP COLUMN IF EXISTS camerpay_transaction_id;
```

### If CamerPay Integration Fails
1. Disable webhook: Go to CamerPay dashboard → Disable
2. Revert to NotchPay (if needed temporarily)
3. Contact CamerPay support
4. Fix configuration and re-enable

---

## Monitoring & Maintenance

### Daily Checks
- [ ] Backend health: `/health` endpoint
- [ ] Payment success rate: Check webhook logs
- [ ] Error logs: Review backend logs
- [ ] User feedback: Monitor support channels

### Weekly Checks
- [ ] Database size: `SELECT pg_database_size(current_database());`
- [ ] Subscription expiration: Check expired subscriptions
- [ ] Trial completions: How many converting to paid?
- [ ] Revenue: Calculate from subscriptions table

### Monthly Tasks
- [ ] Performance review: Response times
- [ ] User retention: Active technicians
- [ ] Revenue analysis: Subscription vs missions
- [ ] Security audit: Check logs for anomalies

---

## Alerts & Notifications

### Setup Monitoring
```bash
# Monitor backend uptime
# Example using UptimeRobot:
# 1. Go to: https://uptimerobot.com
# 2. Add monitor
# 3. URL: https://your-domain.com/health
# 4. Interval: 5 minutes
# 5. Get alerts if down
```

### Setup Log Alerts
```bash
# Example using Sentry (error tracking):
# 1. Install Sentry in backend
# 2. npm install @sentry/node
# 3. Configure in app.js
# 4. Get alerts on errors
```

---

## Communication Plan

### Before Deployment
- [ ] Notify all stakeholders
- [ ] Schedule deployment window
- [ ] Brief support team on changes
- [ ] Prepare rollback procedures

### During Deployment
- [ ] Monitor system health
- [ ] Have team on standby
- [ ] Log any issues
- [ ] Keep stakeholders updated

### After Deployment
- [ ] Announce to users
- [ ] Monitor for issues (24 hours)
- [ ] Collect feedback
- [ ] Document lessons learned

---

## Success Criteria

After deployment:
- ✅ All payments process correctly
- ✅ 0% commission showing in system
- ✅ New technicians get 30-day trial
- ✅ Subscriptions activate correctly
- ✅ Webhook confirmations working
- ✅ Mobile app submits payments
- ✅ No errors in logs
- ✅ Users reporting success

---

## Troubleshooting

### Payment Not Processing
```bash
# 1. Check backend logs
tail -f backend.log | grep -i payment

# 2. Check Supabase for payment record
SELECT * FROM payments WHERE created_at > now() - interval '1 hour';

# 3. Verify CamerPay credentials
# Check .env file has correct API keys

# 4. Test CamerPay API directly
curl -H "Authorization: Bearer $CAMERPAY_API_KEY" \
  https://api.camerpay.com/transactions
```

### Trial Not Starting
```bash
# 1. Check if startFreeTrial was called
SELECT * FROM technician_subscriptions 
WHERE trial_type = 'free_trial' ORDER BY created_at DESC;

# 2. Verify technician record updated
SELECT subscription_type, trial_end_date 
FROM technicians WHERE id = 'tech_id';

# 3. Check if in grace period
SELECT * FROM technician_subscriptions
WHERE status = 'pending';
```

### Subscription Not Activating
```bash
# 1. Check webhook received
# Review backend logs for webhook event

# 2. Verify subscription record
SELECT * FROM technician_subscriptions 
WHERE status = 'active' ORDER BY updated_at DESC;

# 3. Check technician subscription fields
SELECT subscription_status, subscription_end_date 
FROM technicians WHERE id = 'tech_id';
```

---

## Support Contact

For issues:
1. Check logs first
2. Refer to documentation
3. Contact CamerPay support: [dashboard]
4. Contact Supabase support: [dashboard]
5. Internal team: [your team contact]

---

## Final Checklist

Before marking as "Live":
- [ ] All database migrations applied
- [ ] All environment variables set
- [ ] Backend tested and deployed
- [ ] Mobile app updated with new screens
- [ ] CamerPay webhook configured
- [ ] Monitoring setup
- [ ] Support team briefed
- [ ] Rollback plan documented
- [ ] Users notified
- [ ] Success criteria met

---

**✅ Ready for launch!**

Total Deployment Time: ~2-3 hours  
Team: Backend (1) + Mobile (1) + DevOps (1) + Support (1)
