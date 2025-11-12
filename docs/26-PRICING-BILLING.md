# Pricing & Billing

## Overview
Subscription-based pricing model with Stripe integration for payment processing and subscription management.

**Payment Provider**: Stripe  
**Plans**: Starter ($99/mo), Growth ($399/mo), Enterprise (Custom)

---

## Pricing Plans

### Starter Plan
**$99/month**

**Target**: Small companies starting with Reddit marketing

**Limits:**
- 1 company
- 2 team members
- 50 posts/month
- 3 Reddit accounts
- 2 keywords tracked
- Email support

**Stripe Price ID**: `price_starter_monthly`

---

### Growth Plan (Most Popular)
**$399/month**

**Target**: Growing companies scaling Reddit presence

**Limits:**
- 1 company
- 10 team members
- 200 posts/month
- 10 Reddit accounts
- 10 keywords tracked
- Priority email support
- Fine-tuning (1 model/quarter)

**Stripe Price ID**: `price_growth_monthly`

---

### Enterprise Plan
**Custom Pricing**

**Target**: Large companies and agencies

**Features:**
- Multiple companies
- Unlimited team members
- Custom post volume
- Unlimited Reddit accounts
- Unlimited keywords
- Dedicated Slack support
- Custom fine-tuning
- SSO/SAML
- SOC2 compliance
- Dedicated account manager

**Contact**: Sales team for custom quote

---

## Database Schema

### Subscriptions Table

```sql
create table subscriptions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  stripe_subscription_id text unique not null,
  stripe_customer_id text not null,
  stripe_price_id text not null,
  plan_name text not null check (plan_name in ('starter', 'growth', 'enterprise')),
  status text not null check (
    status in (
      'active',
      'trialing',
      'past_due',
      'canceled',
      'unpaid',
      'incomplete',
      'incomplete_expired'
    )
  ),
  current_period_start timestamptz not null,
  current_period_end timestamptz not null,
  cancel_at_period_end boolean default false,
  canceled_at timestamptz,
  trial_start timestamptz,
  trial_end timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_subscriptions_company on subscriptions(company_id);
create index idx_subscriptions_stripe_customer on subscriptions(stripe_customer_id);
create index idx_subscriptions_status on subscriptions(status);
```

### Plan Limits Table

```sql
create table plan_limits (
  plan_name text primary key check (plan_name in ('starter', 'growth', 'enterprise')),
  max_team_members int not null,
  max_posts_per_month int not null,
  max_reddit_accounts int not null,
  max_keywords int not null,
  fine_tuning_enabled boolean default false,
  priority_support boolean default false,
  updated_at timestamptz default now()
);

-- Insert default limits
insert into plan_limits (
  plan_name, 
  max_team_members, 
  max_posts_per_month, 
  max_reddit_accounts, 
  max_keywords,
  fine_tuning_enabled,
  priority_support
) values
  ('starter', 2, 50, 3, 2, false, false),
  ('growth', 10, 200, 10, 10, true, true),
  ('enterprise', -1, -1, -1, -1, true, true); -- -1 = unlimited
```

### Usage Tracking Table

```sql
create table subscription_usage (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  period_start timestamptz not null,
  period_end timestamptz not null,
  posts_count int default 0,
  team_members_count int default 0,
  reddit_accounts_count int default 0,
  keywords_count int default 0,
  created_at timestamptz default now(),
  unique (company_id, period_start, period_end)
);

create index idx_subscription_usage_company on subscription_usage(company_id);
create index idx_subscription_usage_period on subscription_usage(period_start, period_end);
```

### Invoices Table

```sql
create table invoices (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  stripe_invoice_id text unique not null,
  stripe_subscription_id text not null,
  amount_due int not null,          -- in cents
  amount_paid int not null,         -- in cents
  currency text default 'usd',
  status text not null check (
    status in ('draft', 'open', 'paid', 'uncollectible', 'void')
  ),
  invoice_pdf text,                 -- URL to PDF
  hosted_invoice_url text,          -- Stripe hosted page
  period_start timestamptz not null,
  period_end timestamptz not null,
  due_date timestamptz,
  paid_at timestamptz,
  created_at timestamptz default now()
);

create index idx_invoices_company on invoices(company_id);
create index idx_invoices_stripe_subscription on invoices(stripe_subscription_id);
```

---

## Pricing Page

### Landing Page Pricing Section

```tsx
// app/page.tsx - Pricing Section
export function PricingSection() {
  return (
    <section id="pricing" className="py-20 bg-gray-50">
      <div className="max-w-7xl mx-auto px-4">
        <div className="text-center mb-16">
          <h2 className="text-4xl font-bold mb-4">
            Flexible plans for every marketing team
          </h2>
          <p className="text-xl text-gray-600">
            From bootstrapped startups to global enterprises, Mentions delivers
            the tools you need to succeed on Reddit.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          {/* Starter Plan */}
          <PricingCard
            name="Starter"
            price="$99"
            period="/month"
            description="For small companies who want to start engaging on Reddit"
            features={[
              '50 posts per month',
              '2 team members',
              '3 Reddit accounts',
              '2 keywords tracked',
              'Email support',
            ]}
            cta="Get Started"
            ctaLink="/signup?plan=starter"
          />

          {/* Growth Plan */}
          <PricingCard
            name="Growth"
            price="$399"
            period="/month"
            description="For growing companies who want to scale their Reddit presence"
            features={[
              '200 posts per month',
              '10 team members',
              '10 Reddit accounts',
              '10 keywords tracked',
              'Model fine-tuning',
              'Priority email support',
            ]}
            cta="Get Started"
            ctaLink="/signup?plan=growth"
            popular={true}
          />

          {/* Enterprise Plan */}
          <PricingCard
            name="Enterprise"
            price="Custom"
            period=""
            description="Tailored packages for large companies and agencies"
            features={[
              'Multiple companies tracked',
              'Unlimited team members',
              'Custom post volume',
              'Unlimited Reddit accounts',
              'Custom fine-tuning',
              'Dedicated Slack support',
              'SSO/SAML + SOC2 compliance',
            ]}
            cta="Contact Sales"
            ctaLink="/contact-sales"
          />
        </div>

        {/* FAQ */}
        <div className="mt-20">
          <h3 className="text-2xl font-bold text-center mb-8">
            Frequently Asked Questions
          </h3>
          <div className="max-w-3xl mx-auto space-y-6">
            <FAQItem
              question="Can I change plans later?"
              answer="Yes! You can upgrade or downgrade your plan at any time. Changes take effect at the start of your next billing cycle."
            />
            <FAQItem
              question="What happens if I exceed my plan limits?"
              answer="You'll receive a notification when approaching your limits. To continue posting, you can upgrade your plan or wait until your next billing cycle."
            />
            <FAQItem
              question="Do you offer annual billing?"
              answer="Yes! Annual billing is available with a 20% discount. Contact us to set this up."
            />
            <FAQItem
              question="What payment methods do you accept?"
              answer="We accept all major credit cards (Visa, Mastercard, Amex) through Stripe. Enterprise customers can also pay via invoice."
            />
          </div>
        </div>
      </div>
    </section>
  )
}

// components/pricing/PricingCard.tsx
export function PricingCard({
  name,
  price,
  period,
  description,
  features,
  cta,
  ctaLink,
  popular = false,
}: PricingCardProps) {
  return (
    <div
      className={`relative bg-white rounded-lg shadow-lg p-8 ${
        popular ? 'border-2 border-blue-500' : 'border border-gray-200'
      }`}
    >
      {popular && (
        <div className="absolute top-0 right-0 bg-blue-500 text-white px-3 py-1 rounded-bl-lg rounded-tr-lg text-sm font-medium">
          Popular
        </div>
      )}

      <div className="mb-6">
        <h3 className="text-2xl font-bold mb-2">{name}</h3>
        <div className="flex items-baseline mb-4">
          <span className="text-4xl font-bold">{price}</span>
          {period && <span className="text-gray-600 ml-1">{period}</span>}
        </div>
        <p className="text-gray-600">{description}</p>
      </div>

      <ul className="space-y-3 mb-8">
        {features.map((feature, i) => (
          <li key={i} className="flex items-start">
            <CheckIcon className="w-5 h-5 text-green-500 mr-2 flex-shrink-0 mt-0.5" />
            <span>{feature}</span>
          </li>
        ))}
      </ul>

      <Link
        href={ctaLink}
        className={`block w-full py-3 px-6 text-center rounded-md font-medium ${
          popular
            ? 'bg-blue-600 text-white hover:bg-blue-700'
            : 'bg-gray-100 text-gray-900 hover:bg-gray-200'
        }`}
      >
        {cta}
      </Link>
    </div>
  )
}
```

---

## Stripe Integration

### Backend Setup

```python
# core/stripe_client.py
import stripe
from core.config import settings

stripe.api_key = settings.stripe_secret_key

class StripeClient:
    """Wrapper for Stripe API operations."""
    
    @staticmethod
    async def create_customer(email: str, company_name: str) -> str:
        """Create a Stripe customer."""
        customer = stripe.Customer.create(
            email=email,
            name=company_name,
            metadata={"company_name": company_name}
        )
        return customer.id
    
    @staticmethod
    async def create_checkout_session(
        customer_id: str,
        price_id: str,
        success_url: str,
        cancel_url: str,
        company_id: str
    ):
        """Create a Stripe Checkout session."""
        session = stripe.checkout.Session.create(
            customer=customer_id,
            payment_method_types=['card'],
            line_items=[{
                'price': price_id,
                'quantity': 1,
            }],
            mode='subscription',
            success_url=success_url,
            cancel_url=cancel_url,
            metadata={
                'company_id': company_id
            },
            subscription_data={
                'metadata': {
                    'company_id': company_id
                }
            }
        )
        return session
    
    @staticmethod
    async def create_portal_session(customer_id: str, return_url: str):
        """Create a Stripe Customer Portal session."""
        session = stripe.billing_portal.Session.create(
            customer=customer_id,
            return_url=return_url,
        )
        return session
    
    @staticmethod
    async def cancel_subscription(subscription_id: str):
        """Cancel a subscription at period end."""
        subscription = stripe.Subscription.modify(
            subscription_id,
            cancel_at_period_end=True
        )
        return subscription
    
    @staticmethod
    async def update_subscription(subscription_id: str, new_price_id: str):
        """Update subscription to new plan."""
        subscription = stripe.Subscription.retrieve(subscription_id)
        
        stripe.Subscription.modify(
            subscription_id,
            items=[{
                'id': subscription['items']['data'][0].id,
                'price': new_price_id,
            }],
            proration_behavior='always_invoice'
        )
```

### API Endpoints

```python
# api/billing.py
from fastapi import APIRouter, Depends, HTTPException
from core.stripe_client import StripeClient
from core.deps import get_current_user

router = APIRouter()

@router.post("/billing/checkout")
async def create_checkout_session(
    plan: str,
    user = Depends(get_current_user)
):
    """Create Stripe checkout session for plan selection."""
    
    # Map plan names to Stripe price IDs
    price_ids = {
        'starter': settings.stripe_price_starter,
        'growth': settings.stripe_price_growth,
    }
    
    if plan not in price_ids:
        raise HTTPException(status_code=400, detail="Invalid plan")
    
    # Get or create Stripe customer
    customer_id = await get_or_create_stripe_customer(
        user.email,
        user.company_name
    )
    
    # Create checkout session
    session = await StripeClient.create_checkout_session(
        customer_id=customer_id,
        price_id=price_ids[plan],
        success_url=f"{settings.frontend_url}/settings/billing?success=true",
        cancel_url=f"{settings.frontend_url}/settings/billing?canceled=true",
        company_id=user.company_id
    )
    
    return {"checkout_url": session.url}

@router.post("/billing/portal")
async def create_portal_session(
    user = Depends(get_current_user)
):
    """Create Stripe Customer Portal session."""
    
    # Get Stripe customer ID
    subscription = await db.fetchone(
        "select stripe_customer_id from subscriptions where company_id = $1",
        user.company_id
    )
    
    if not subscription:
        raise HTTPException(status_code=404, detail="No subscription found")
    
    # Create portal session
    session = await StripeClient.create_portal_session(
        customer_id=subscription['stripe_customer_id'],
        return_url=f"{settings.frontend_url}/settings/billing"
    )
    
    return {"portal_url": session.url}

@router.get("/billing/subscription")
async def get_subscription(
    user = Depends(get_current_user)
):
    """Get current subscription details."""
    
    subscription = await db.fetchone(
        """
        select 
            s.*,
            pl.max_team_members,
            pl.max_posts_per_month,
            pl.max_reddit_accounts,
            pl.max_keywords
        from subscriptions s
        join plan_limits pl on pl.plan_name = s.plan_name
        where s.company_id = $1
        """,
        user.company_id
    )
    
    if not subscription:
        return {"has_subscription": False}
    
    return {
        "has_subscription": True,
        "plan": subscription['plan_name'],
        "status": subscription['status'],
        "current_period_end": subscription['current_period_end'],
        "cancel_at_period_end": subscription['cancel_at_period_end'],
        "limits": {
            "team_members": subscription['max_team_members'],
            "posts_per_month": subscription['max_posts_per_month'],
            "reddit_accounts": subscription['max_reddit_accounts'],
            "keywords": subscription['max_keywords'],
        }
    }

@router.get("/billing/usage")
async def get_usage(
    user = Depends(get_current_user)
):
    """Get current billing period usage."""
    
    # Get current subscription period
    subscription = await db.fetchone(
        """
        select current_period_start, current_period_end
        from subscriptions
        where company_id = $1
        """,
        user.company_id
    )
    
    if not subscription:
        raise HTTPException(status_code=404, detail="No subscription found")
    
    # Get usage counts
    usage = await db.fetchone(
        """
        select
            (select count(*) from posts 
             where company_id = $1 
             and posted_at between $2 and $3) as posts_count,
            (select count(*) from user_profiles 
             where company_id = $1) as team_members_count,
            (select count(*) from reddit_connections 
             where company_id = $1 and is_active = true) as reddit_accounts_count
        """,
        user.company_id,
        subscription['current_period_start'],
        subscription['current_period_end']
    )
    
    return {
        "period_start": subscription['current_period_start'],
        "period_end": subscription['current_period_end'],
        "usage": dict(usage)
    }
```

---

## Stripe Webhooks

### Webhook Handler

```python
# api/webhooks.py
from fastapi import APIRouter, Request, HTTPException
import stripe
from core.config import settings

router = APIRouter()

@router.post("/webhooks/stripe")
async def stripe_webhook(request: Request):
    """Handle Stripe webhook events."""
    
    payload = await request.body()
    sig_header = request.headers.get('stripe-signature')
    
    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, settings.stripe_webhook_secret
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid payload")
    except stripe.error.SignatureVerificationError:
        raise HTTPException(status_code=400, detail="Invalid signature")
    
    # Handle different event types
    handlers = {
        'customer.subscription.created': handle_subscription_created,
        'customer.subscription.updated': handle_subscription_updated,
        'customer.subscription.deleted': handle_subscription_deleted,
        'invoice.paid': handle_invoice_paid,
        'invoice.payment_failed': handle_invoice_payment_failed,
    }
    
    handler = handlers.get(event['type'])
    if handler:
        await handler(event['data']['object'])
    
    return {"status": "success"}

async def handle_subscription_created(subscription):
    """Handle new subscription creation."""
    company_id = subscription['metadata'].get('company_id')
    
    await db.execute(
        """
        insert into subscriptions (
            company_id, stripe_subscription_id, stripe_customer_id,
            stripe_price_id, plan_name, status, current_period_start,
            current_period_end, trial_start, trial_end
        ) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        """,
        company_id,
        subscription['id'],
        subscription['customer'],
        subscription['items']['data'][0]['price']['id'],
        get_plan_name_from_price_id(subscription['items']['data'][0]['price']['id']),
        subscription['status'],
        datetime.fromtimestamp(subscription['current_period_start']),
        datetime.fromtimestamp(subscription['current_period_end']),
        datetime.fromtimestamp(subscription['trial_start']) if subscription.get('trial_start') else None,
        datetime.fromtimestamp(subscription['trial_end']) if subscription.get('trial_end') else None
    )

async def handle_subscription_updated(subscription):
    """Handle subscription updates."""
    await db.execute(
        """
        update subscriptions set
            status = $1,
            stripe_price_id = $2,
            plan_name = $3,
            current_period_start = $4,
            current_period_end = $5,
            cancel_at_period_end = $6,
            canceled_at = $7,
            updated_at = now()
        where stripe_subscription_id = $8
        """,
        subscription['status'],
        subscription['items']['data'][0]['price']['id'],
        get_plan_name_from_price_id(subscription['items']['data'][0]['price']['id']),
        datetime.fromtimestamp(subscription['current_period_start']),
        datetime.fromtimestamp(subscription['current_period_end']),
        subscription['cancel_at_period_end'],
        datetime.fromtimestamp(subscription['canceled_at']) if subscription.get('canceled_at') else None,
        subscription['id']
    )

async def handle_subscription_deleted(subscription):
    """Handle subscription cancellation."""
    await db.execute(
        """
        update subscriptions set
            status = 'canceled',
            canceled_at = now(),
            updated_at = now()
        where stripe_subscription_id = $1
        """,
        subscription['id']
    )

async def handle_invoice_paid(invoice):
    """Handle successful invoice payment."""
    await db.execute(
        """
        insert into invoices (
            company_id, stripe_invoice_id, stripe_subscription_id,
            amount_due, amount_paid, currency, status, invoice_pdf,
            hosted_invoice_url, period_start, period_end, paid_at
        ) values (
            (select company_id from subscriptions where stripe_subscription_id = $1),
            $2, $1, $3, $4, $5, 'paid', $6, $7, $8, $9, now()
        )
        on conflict (stripe_invoice_id) do update set
            amount_paid = excluded.amount_paid,
            status = 'paid',
            paid_at = now()
        """,
        invoice['subscription'],
        invoice['id'],
        invoice['amount_due'],
        invoice['amount_paid'],
        invoice['currency'],
        invoice['invoice_pdf'],
        invoice['hosted_invoice_url'],
        datetime.fromtimestamp(invoice['period_start']),
        datetime.fromtimestamp(invoice['period_end'])
    )
```

---

## Billing Settings Page

```tsx
// app/settings/billing/page.tsx
'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function BillingPage() {
  const [subscription, setSubscription] = useState(null)
  const [usage, setUsage] = useState(null)
  const [loading, setLoading] = useState(true)
  const router = useRouter()

  useEffect(() => {
    fetchSubscription()
    fetchUsage()
  }, [])

  const fetchSubscription = async () => {
    const res = await fetch('/api/billing/subscription')
    const data = await res.json()
    setSubscription(data)
    setLoading(false)
  }

  const fetchUsage = async () => {
    const res = await fetch('/api/billing/usage')
    const data = await res.json()
    setUsage(data)
  }

  const handleManageBilling = async () => {
    const res = await fetch('/api/billing/portal', { method: 'POST' })
    const data = await res.json()
    window.location.href = data.portal_url
  }

  const handleUpgrade = async (plan: string) => {
    const res = await fetch('/api/billing/checkout', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ plan })
    })
    const data = await res.json()
    window.location.href = data.checkout_url
  }

  if (loading) return <div>Loading...</div>

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold">Billing & Subscription</h1>
        <p className="text-gray-600">Manage your plan and billing information</p>
      </div>

      {/* Current Plan */}
      {subscription?.has_subscription ? (
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-xl font-bold mb-4">Current Plan</h2>
          <div className="flex justify-between items-start">
            <div>
              <p className="text-2xl font-bold capitalize mb-2">
                {subscription.plan}
              </p>
              <p className="text-gray-600">
                Status: <span className="capitalize">{subscription.status}</span>
              </p>
              <p className="text-gray-600">
                Renews: {new Date(subscription.current_period_end).toLocaleDateString()}
              </p>
              {subscription.cancel_at_period_end && (
                <p className="text-yellow-600 mt-2">
                  ⚠️ Subscription will cancel at period end
                </p>
              )}
            </div>
            <button
              onClick={handleManageBilling}
              className="px-4 py-2 bg-gray-100 hover:bg-gray-200 rounded-md"
            >
              Manage Billing
            </button>
          </div>

          {/* Plan Limits */}
          <div className="mt-6 grid grid-cols-2 md:grid-cols-4 gap-4">
            <LimitCard
              label="Team Members"
              limit={subscription.limits.team_members}
              used={usage?.usage.team_members_count || 0}
            />
            <LimitCard
              label="Posts/Month"
              limit={subscription.limits.posts_per_month}
              used={usage?.usage.posts_count || 0}
            />
            <LimitCard
              label="Reddit Accounts"
              limit={subscription.limits.reddit_accounts}
              used={usage?.usage.reddit_accounts_count || 0}
            />
            <LimitCard
              label="Keywords"
              limit={subscription.limits.keywords}
              used={0}
            />
          </div>
        </div>
      ) : (
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-xl font-bold mb-4">No Active Subscription</h2>
          <p className="text-gray-600 mb-6">
            Choose a plan to start using Mentions
          </p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <PlanCard
              name="Starter"
              price="$99/month"
              onSelect={() => handleUpgrade('starter')}
            />
            <PlanCard
              name="Growth"
              price="$399/month"
              onSelect={() => handleUpgrade('growth')}
              popular
            />
          </div>
        </div>
      )}
    </div>
  )
}

function LimitCard({ label, limit, used }) {
  const percentage = limit === -1 ? 0 : (used / limit) * 100
  const isNearLimit = percentage > 80

  return (
    <div className="border rounded-lg p-4">
      <p className="text-sm text-gray-600 mb-1">{label}</p>
      <p className="text-2xl font-bold">
        {used}
        {limit !== -1 && <span className="text-gray-400">/{limit}</span>}
      </p>
      {limit !== -1 && (
        <div className="mt-2 h-2 bg-gray-200 rounded-full overflow-hidden">
          <div
            className={`h-full ${isNearLimit ? 'bg-yellow-500' : 'bg-blue-500'}`}
            style={{ width: `${Math.min(percentage, 100)}%` }}
          />
        </div>
      )}
    </div>
  )
}
```

---

## Environment Variables

Add to `.env`:

```bash
# Stripe
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Stripe Price IDs
STRIPE_PRICE_STARTER=price_starter_monthly
STRIPE_PRICE_GROWTH=price_growth_monthly
```

---

## Testing

### Test Mode

Use Stripe test mode with test card:
- Card: `4242 4242 4242 4242`
- Expiry: Any future date
- CVC: Any 3 digits

### Webhook Testing

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Login
stripe login

# Forward webhooks to local server
stripe listen --forward-to localhost:8000/webhooks/stripe
```

---

## Next Steps

1. **M1**: Set up Stripe account and get API keys
2. **M1**: Create price objects in Stripe Dashboard
3. **M2**: Implement database schema
4. **M2**: Implement API endpoints
5. **M3**: Build billing settings page
6. **M3**: Set up webhook endpoint
7. **M4**: Add plan enforcement logic
8. **M5**: Test checkout and webhook flows



