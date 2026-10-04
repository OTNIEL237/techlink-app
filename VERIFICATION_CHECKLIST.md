# ✅ VERIFICATION CHECKLIST

## QUICK STATUS CHECK (5 MIN)

### 🔴 PROBLÈMES ACTUELS
- ❌ Les 5% de commission sont toujours déductibles (ancien code en production)
- ❌ Les abonnements n'apparaissent pas à l'inscription
- ❌ NotchPay toujours utilisé (voir logs: "DEBUG NotchPay")

### ✅ CODE CRÉÉ AUJOURD'HUI
- ✅ Backend payment routes (0% commission)
- ✅ Backend subscription routes (6 endpoints)
- ✅ Mobile subscription selection screen
- ✅ Updated register flow
- ✅ Updated routing in main.dart
- ✅ Database migration SQL
- ✅ Environment variables configured locally

---

## À FAIRE MAINTENANT (Priority Order)

### PRIORITY 1: DATABASE (5 min) 🔴 CRITICAL
```
Status: NOT YET APPLIED
File: supabase/migrations/008_add_subscriptions.sql
Action: 
  1. Go to https://supabase.com/dashboard
  2. SQL Editor > New Query
  3. Copy content of: supabase/migrations/008_add_subscriptions.sql
  4. Run query
  5. Confirm no errors

Verify:
  SELECT column_name FROM information_schema.columns 
  WHERE table_name='technicians' 
  ORDER BY ordinal_position;
  
Expected: Contains subscription_type, trial_end_date, subscription_end_date
```

### PRIORITY 2: BACKEND DEPLOY (10 min) 🔴 CRITICAL
```
Status: .env updated locally, NOT YET DEPLOYED
File: backend/.env
Action:
  1. Go to https://railway.app
  2. Project TechLink > Settings > Variables
  3. Add/Update:
     CAMERPAY_API_KEY=313|V0AUJrh90n2QwxE18SMkLh5h831qpOzqX4kHxwp8fe797d99
     CAMERPAY_SECRET_KEY=313|V0AUJrh90n2QwxE18SMkLh5h831qpOzqX4kHxwp8fe797d99
     BACKEND_URL=https://techlink-backend-production.up.railway.app
  4. Click Deploy or git push

Verify:
  curl https://techlink-backend-production.up.railway.app/health
  Expected: {"status":"OK","message":"TechLink API running"}
```

### PRIORITY 3: TEST CAMERPAY (5 min) 🟡 IMPORTANT
```
Status: Ready to test after backend deploy
Action:
  curl -X POST https://techlink-backend-production.up.railway.app/api/payments/initialize \
    -H "Content-Type: application/json" \
    -d '{
      "missionId": "test",
      "amount": 10000,
      "clientId": "test",
      "clientPhone": "+237600000000",
      "clientEmail": "test@test.com",
      "description": "Test"
    }'

Expected: 
  - "CamerPay" in response (NOT "NotchPay")
  - "success": true
  - "paymentUrl" present
```

### PRIORITY 4: MOBILE RECOMPILE (10 min) 🟡 IMPORTANT
```
Status: Code ready, NOT YET RECOMPILED
Files: 
  - subscription_selection_screen.dart (NEW ✅)
  - register_screen.dart (UPDATED ✅)
  - main.dart (UPDATED ✅)

Action:
  cd c:\Users\Lenovo\techlink-app\mobile
  flutter clean
  flutter pub get
  flutter run

Expected:
  - No errors about missing files
  - App compiles successfully
  - Can see Supabase init message
```

---

## FILE VERIFICATION

### Backend Files (All exist and ready)
- ✅ src/modules/payments/payment.routes.js
- ✅ src/modules/subscriptions.routes.js
- ✅ src/modules/subscriptionController.js
- ✅ src/utils/camerpay.service.js
- ✅ src/config/camerpay.js
- ✅ src/app.js (with CamerPay webhooks)
- ✅ .env (CamerPay keys added)

### Mobile Files (All exist and updated)
- ✅ lib/presentation/auth/subscription_selection_screen.dart (NEW)
- ✅ lib/presentation/auth/register_screen.dart (UPDATED)
- ✅ lib/main.dart (UPDATED - import + route)
- ✅ lib/data/services/camerpay_service.dart (exists)

### Database Files (Ready)
- ✅ supabase/migrations/008_add_subscriptions.sql

### Environment (Locally updated)
- ✅ backend/.env (CamerPay keys added)

---

## DEPLOYMENT VERIFICATION

### Database
```
Status: [ ] NOT APPLIED
Needed: Run migration SQL in Supabase
Result: technicians table will have subscription columns
```

### Backend
```
Status: [ ] NOT DEPLOYED
Current: Uses OLD code (NotchPay + 5% commission)
Needed: Redeploy with new code
Result: Will use CamerPay + 0% commission
```

### Mobile
```
Status: [ ] NOT RECOMPILED
Current: Using old code
Needed: flutter clean && flutter pub get && flutter run
Result: Will show subscription screen after registration
```

---

## TESTING CHECKLIST (After deployment)

### Database Test
```
✓ [ ] Query technicians table
✓ [ ] Columns exist: subscription_type, trial_end_date, subscription_end_date
✓ [ ] Table exists: technician_subscriptions
```

### Backend Test
```
✓ [ ] Health check returns OK
✓ [ ] /api/payments/initialize uses CamerPay (not NotchPay)
✓ [ ] /api/subscriptions endpoints accessible
✓ [ ] commission_percentage = 0 in payment records
```

### Mobile Test
```
✓ [ ] App compiles without errors
✓ [ ] Can register as technician
✓ [ ] Subscription selection screen appears after registration
✓ [ ] Can see 3 plans: Trial, Monthly, Yearly
✓ [ ] "Essai gratuit" badge visible on trial plan
✓ [ ] Clicking trial doesn't require payment
✓ [ ] Monthly/Yearly show CamerPay
```

### Integration Test
```
✓ [ ] New technician has trial_end_date set (30 days from now)
✓ [ ] New technician has subscription_status = 'active'
✓ [ ] Mission payments show commission_percentage = 0
✓ [ ] Mission payments show 100% to technician
```

---

## COMMON ISSUES & FIXES

### Issue: "Still seeing NotchPay in logs"
**Solution:** Backend not redeployed with new code
- Redeploy on Railway
- Wait for deployment to complete
- Clear browser cache and app cache

### Issue: "subscription_selection_screen.dart not found"
**Solution:** Flutter compilation error
```bash
cd mobile
flutter clean
flutter pub get
flutter run
```

### Issue: "Subscription columns don't exist in database"
**Solution:** Migration not applied
- Go to Supabase SQL Editor
- Run: supabase/migrations/008_add_subscriptions.sql
- Verify columns exist

### Issue: "CamerPay payment fails"
**Solution:** API keys not configured
- Check Railway variables
- Ensure CAMERPAY_API_KEY is set correctly
- Ensure CAMERPAY_SECRET_KEY is set correctly

---

## SUCCESS INDICATORS ✅

When everything is working:
1. Database has subscription columns
2. Backend uses CamerPay (logs show "CamerPay", not "NotchPay")
3. Payments show commission_percentage = 0
4. Mobile shows subscription screen after registration
5. Technicians see "30 days free trial" option
6. Free trial starts without requiring payment
7. Paid plans integrate with CamerPay

---

## ROLL-BACK PLAN (If needed)

### Revert Database
```sql
ALTER TABLE technicians DROP COLUMN subscription_type;
ALTER TABLE technicians DROP COLUMN trial_end_date;
ALTER TABLE technicians DROP COLUMN subscription_end_date;
ALTER TABLE technicians DROP COLUMN subscription_status;
DROP TABLE technician_subscriptions;
```

### Revert Backend
```bash
git revert <commit-sha>
git push
# Redeploy on Railway
```

### Revert Mobile
```bash
git checkout -- mobile/
flutter clean
flutter pub get
flutter run
```

---

## NOTES

- Clé CamerPay: `313|V0AUJrh90n2QwxE18SMkLh5h831qpOzqX4kHxwp8fe797d99`
- Tous les fichiers code sont créés et prêts
- Seul le déploiement manque
- Estimation temps total: 30 minutes
- Après déploiement: Le système fonctionnera avec 0% commission et abonnements
