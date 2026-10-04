# 📚 API Documentation - TechLink CamerPay Integration

## ✅ Backend Infrastructure Completed

### Database Migrations
- ✅ `008_add_subscriptions.sql` - Added subscription fields to technicians table
- ✅ Created `technician_subscriptions` table for subscription history

### Environment Variables
**File**: `.env`
```env
# CamerPay Configuration
CAMERPAY_API_KEY=PASTE_YOUR_API_KEY_HERE
CAMERPAY_SECRET_KEY=PASTE_YOUR_SECRET_KEY_HERE
CAMERPAY_WEBHOOK_SECRET=PASTE_YOUR_WEBHOOK_SECRET_HERE

# Subscription Configuration
SUBSCRIPTION_MONTHLY_AMOUNT=2000
SUBSCRIPTION_YEARLY_AMOUNT=20000
SUBSCRIPTION_TRIAL_DAYS=30
CURRENCY_CODE=XAF
```

### Configuration Files
- ✅ `src/config/camerpay.js` - CamerPay config with pricing
- ✅ `src/utils/camerpay.service.js` - CamerPay API client

---

## 🔌 API Endpoints

### 1️⃣ PAYMENT ENDPOINTS

#### **POST** `/api/payments/initialize`
Initialize mission payment (client pays technician)

**Request:**
```json
{
  "missionId": "uuid",
  "amount": 50000,
  "clientId": "uuid",
  "clientPhone": "+237123456789",
  "clientEmail": "client@example.com",
  "description": "Optional description"
}
```

**Response (Success):**
```json
{
  "success": true,
  "data": {
    "paymentUrl": "https://camerpay.com/pay/xxxxx",
    "paymentId": "uuid",
    "reference": "MISSION_uuid_timestamp_random",
    "amount": 50000
  }
}
```

**Key Points:**
- Amount = 100% (no commission deducted)
- Technician receives full amount
- Payment recorded in `payments` table with:
  - `commission_percentage`: 0
  - `is_mission_payment`: true
  - `camerpay_reference`: reference
  - `camerpay_transaction_id`: transaction ID

---

#### **POST** `/api/payments/verify/:reference`
Verify payment completion

**Parameters:**
- `reference` (path): Payment reference from initialization

**Response:**
```json
{
  "success": true,
  "data": {
    "status": "success|failed",
    "payment": { ... payment object ... }
  }
}
```

**Actions on Success:**
- Mission status → `paid`
- Wallet transaction created for technician
- Technician wallet balance updated (+100% of amount)

---

### 2️⃣ SUBSCRIPTION ENDPOINTS

#### **POST** `/api/subscriptions/start-trial`
Start 1-month free trial (called during technician registration)

**Request:**
```json
{
  "technicianId": "uuid"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "trial_start_date": "2026-06-10T14:31:33Z",
    "trial_end_date": "2026-07-10T14:31:33Z",
    "trial_days_remaining": 30
  }
}
```

**Database Changes:**
```
technicians table:
- subscription_type = 'trial'
- subscription_status = 'active'
- trial_start_date = now()
- trial_end_date = now() + 30 days
```

---

#### **POST** `/api/subscriptions/initialize`
Initialize subscription payment (monthly or yearly)

**Request:**
```json
{
  "technicianId": "uuid",
  "subscriptionType": "monthly|yearly",
  "technicianData": {
    "name": "John Doe",
    "phone": "+237123456789",
    "email": "technician@example.com"
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "paymentUrl": "https://camerpay.com/pay/xxxxx",
    "subscriptionId": "uuid",
    "reference": "SUB_uuid_timestamp_random",
    "amount": 2000,
    "duration": "30 days",
    "subscriptionType": "monthly"
  }
}
```

**Pricing:**
- Monthly: 2,000 FCFA
- Yearly: 20,000 FCFA

---

#### **POST** `/api/subscriptions/verify/:reference`
Verify subscription payment

**Parameters:**
- `reference` (path): Subscription reference

**Response:**
```json
{
  "success": true,
  "data": {
    "subscriptionType": "monthly|yearly",
    "status": "active",
    "startDate": "2026-06-10T14:31:33Z",
    "endDate": "2026-07-10T14:31:33Z",
    "amountPaid": 2000
  }
}
```

---

#### **GET** `/api/subscriptions/status/:technicianId`
Get subscription status for technician

**Parameters:**
- `technicianId` (path): Technician UUID

**Response:**
```json
{
  "success": true,
  "data": {
    "hasActiveSubscription": false,
    "hasActiveTrial": true,
    "daysRemaining": 15,
    "type": "trial"
  }
}
```

---

#### **POST** `/api/subscriptions/renew/:technicianId`
Renew subscription (after trial or expiration)

**Request:**
```json
{
  "technicianData": {
    "name": "John Doe",
    "phone": "+237123456789",
    "email": "technician@example.com"
  }
}
```

**Response:** Same as initialize (payment URL returned)

---

#### **POST** `/api/subscriptions/cancel/:technicianId`
Cancel active subscription

**Response:**
```json
{
  "success": true,
  "data": {
    "message": "Subscription cancelled"
  }
}
```

**Database Changes:**
- subscription_status → 'cancelled'
- subscription_end_date → now()

---

### 3️⃣ WEBHOOK ENDPOINTS

#### **POST** `/camerpay/webhook`
Receive payment notifications from CamerPay

**Headers:**
```
X-CamerPay-Signature: sha256_hash
Content-Type: application/json
```

**Request Body:**
```json
{
  "event": "payment.success|payment.failed|payment.cancelled",
  "data": {
    "reference": "MISSION_uuid_timestamp_random",
    "amount": 50000,
    "metadata": {
      "client_id": "uuid",
      "payment_type": "mission|subscription",
      "mission_id": "uuid",
      "subscription_type": "monthly|yearly"
    }
  }
}
```

**Validation:**
- Verifies `X-CamerPay-Signature` using `CAMERPAY_WEBHOOK_SECRET`
- Rejects invalid signatures with 403 Forbidden

**Actions:**
1. **Mission Payment Success**:
   - Update `payments` table: status = 'success'
   - Update `missions` table: status = 'paid', paid_at = now()
   - Create wallet transaction
   - Update technician wallet balance

2. **Subscription Payment Success**:
   - Update `technician_subscriptions`: status = 'active'
   - Update `technicians`: subscription_status = 'active'

3. **Payment Failure**:
   - Update status = 'failed' in respective table
   - Log error

---

#### **GET** `/camerpay/callback`
Browser redirect after payment completion

**Parameters:**
- `reference` (query): Payment reference
- `status` (query): 'success' or 'failed'

**Response:** Redirect to `/payment/success` or `/payment/cancel`

---

#### **GET** `/payment/success`
Success page shown after payment

**Returns:** HTML success page

---

#### **GET** `/payment/cancel`
Cancel page shown if payment failed

**Returns:** HTML cancel page

---

## 📊 Database Schema

### Technicians Table (Modified)
```sql
subscription_type: TEXT ('none', 'monthly', 'yearly', 'trial')
subscription_status: TEXT ('active', 'inactive', 'expired', 'cancelled')
subscription_start_date: TIMESTAMP
subscription_end_date: TIMESTAMP
trial_start_date: TIMESTAMP
trial_end_date: TIMESTAMP
subscription_price_paid: NUMERIC (10,2)
subscription_payment_reference: TEXT
```

### Technician Subscriptions Table (New)
```sql
id: UUID PRIMARY KEY
technician_id: UUID (FK → technicians.id)
subscription_type: TEXT ('monthly', 'yearly', 'trial')
amount_paid: NUMERIC (10,2)
period_start: TIMESTAMP
period_end: TIMESTAMP
trial_type: TEXT ('free_trial' or NULL)
status: TEXT ('active', 'expired', 'cancelled')
payment_reference: TEXT (unique)
camerpay_transaction_id: TEXT
created_at: TIMESTAMP
updated_at: TIMESTAMP
cancelled_at: TIMESTAMP
```

### Payments Table (Modified)
```sql
commission_percentage: NUMERIC (5,2) [NEW - default 0]
is_mission_payment: BOOLEAN [NEW - default true]
camerpay_reference: TEXT [NEW]
camerpay_transaction_id: TEXT [NEW]
```

---

## 🔐 Middleware

### `checkSubscriptionStatus`
Middleware to verify active subscription before mission acceptance

**Usage:**
```javascript
router.post('/missions/:missionId/accept',
  checkSubscriptionStatus,
  handleMissionAcceptance
);
```

**Behavior:**
- ✅ Pass if trial active
- ✅ Pass if paid subscription active
- ❌ Block (403) if no active subscription/trial

**Response on Block:**
```json
{
  "success": false,
  "error": "Subscription required",
  "message": "Your subscription has expired. Please renew your subscription to continue.",
  "subscriptionExpired": true
}
```

---

## ⚙️ Configuration

**src/config/camerpay.js:**
```javascript
{
  // API Config
  apiKey: process.env.CAMERPAY_API_KEY,
  secretKey: process.env.CAMERPAY_SECRET_KEY,
  baseUrl: 'https://test-api.camerpay.com', // test env

  // Subscription Pricing
  subscriptions: {
    monthly: { amount: 2000, durationDays: 30 },
    yearly: { amount: 20000, durationDays: 365 }
  },

  // Trial
  trial: { durationDays: 30, enabled: true }
}
```

---

## 🧪 Testing

### Test Case 1: Mission Payment (No Commission)
```
1. Client initiates payment: 50,000 FCFA
2. Backend calls POST /api/payments/initialize
3. Returns CamerPay payment URL
4. Client completes payment on CamerPay
5. CamerPay sends webhook: payment.success
6. Backend:
   - Updates mission: status='paid'
   - Updates payment: status='success'
   - Creates wallet transaction: +50,000 (100%)
   - Updates technician: wallet_balance += 50,000
```

### Test Case 2: Subscription Payment
```
1. Technician trial ending: 2 days left
2. Technician selects: Monthly (2,000 FCFA)
3. Backend calls POST /api/subscriptions/initialize
4. Returns CamerPay payment URL
5. Technician completes payment
6. CamerPay webhook: payment.success
7. Backend:
   - Updates subscription: status='active'
   - Updates technician: subscription_status='active'
   - New period: 30 days from now
```

### Test Case 3: Subscription Validation
```
1. Technician accepts mission
2. Middleware checks: checkSubscriptionStatus
3. GET /api/subscriptions/status/:technicianId
4. Response: { hasActiveTrial: true, daysRemaining: 15 }
5. Request allowed ✅
```

---

## 🚀 Deployment Checklist

- [ ] Supabase migrations applied: `008_add_subscriptions.sql`
- [ ] Environment variables set in production
- [ ] CamerPay API keys configured (production)
- [ ] CamerPay webhook configured in dashboard
- [ ] Backend routes registered in app.js
- [ ] Webhook signature validation working
- [ ] Mobile CamerPayService configured
- [ ] Mobile payment flow tested
- [ ] Subscription flow tested end-to-end
- [ ] Middleware protecting mission endpoints
