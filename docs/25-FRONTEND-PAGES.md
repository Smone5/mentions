# Frontend Pages & Navigation

## Overview
Complete specification of all frontend pages, navigation structure, and user flows for the Reddit Reply Assistant.

**Framework**: Next.js 14 App Router  
**Authentication**: Supabase Auth  
**Styling**: Tailwind CSS + shadcn/ui

**IMPORTANT**: All pages must be fully responsive (mobile/tablet/desktop) and SEO-optimized. See **[27-RESPONSIVE-SEO.md](./27-RESPONSIVE-SEO.md)** for complete implementation guide covering:
- Mobile-first responsive design patterns
- Next.js Metadata API and structured data
- Performance optimization
- Accessibility requirements
- Testing checklists

---

## Page Structure

### Public Pages (Unauthenticated)

#### 1. Landing Page (`/`)

**Purpose**: Marketing page to attract new users

**Sections:**
```tsx
// app/page.tsx
import { HeroSection } from '@/components/landing/HeroSection'
import { FeaturesSection } from '@/components/landing/FeaturesSection'
import { HowItWorksSection } from '@/components/landing/HowItWorksSection'
import { PricingSection } from '@/components/landing/PricingSection'
import { CTASection } from '@/components/landing/CTASection'
import { Footer } from '@/components/layout/Footer'

export default function LandingPage() {
  return (
    <div className="min-h-screen">
      <HeroSection />
      <FeaturesSection />
      <HowItWorksSection />
      <PricingSection />
      <CTASection />
      <Footer />
    </div>
  )
}
```

**Hero Section:**
- Main headline: "Turn Reddit into Your Customer Acquisition Channel"
- Subheading: "AI-powered Reddit reply assistant that finds relevant conversations and drafts helpful responses grounded in your company knowledge"
- CTA buttons: "Get Started Free" and "Watch Demo"
- Hero image/animation showing the product

**Features:**
- 🔍 Smart Subreddit Discovery - AI finds the best communities for your brand
- 🤖 AI-Powered Drafts - Replies grounded in your company knowledge base
- 👥 Human-in-the-Loop - Review and approve every post before it goes live
- 📊 Performance Tracking - Monitor engagement and optimize over time
- 🔒 Safe Posting - Volume controls and verification to avoid spam flags
- 🎯 Multi-Account Support - Scale to 200+ posts/week across accounts

**How It Works:**
1. Connect your Reddit account and company data
2. Define your keywords and goals
3. AI finds threads and drafts helpful replies
4. Review, edit, and approve posts
5. Track performance and iterate

**Pricing:** (TBD based on your business model)

**Navigation Bar:**
- Logo (links to home)
- Features
- Pricing
- About
- Log In
- Sign Up (CTA button)

---

#### 2. Login Page (`/login`)

**Purpose**: User authentication

```tsx
// app/login/page.tsx
'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase'
import { useRouter } from 'next/navigation'
import Link from 'next/link'

export default function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    })

    if (error) {
      setError(error.message)
      setLoading(false)
    } else {
      router.push('/dashboard')
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="max-w-md w-full space-y-8 p-8 bg-white rounded-lg shadow">
        <div>
          <h2 className="text-3xl font-bold text-center">
            Log in to Mentions
          </h2>
          <p className="mt-2 text-center text-gray-600">
            Or{' '}
            <Link href="/signup" className="text-blue-600 hover:text-blue-500">
              create a new account
            </Link>
          </p>
        </div>

        <form onSubmit={handleLogin} className="space-y-6">
          {error && (
            <div className="bg-red-50 text-red-600 p-3 rounded">
              {error}
            </div>
          )}

          <div>
            <label htmlFor="email" className="block text-sm font-medium">
              Email address
            </label>
            <input
              id="email"
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md"
            />
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-medium">
              Password
            </label>
            <input
              id="password"
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md"
            />
          </div>

          <div className="flex items-center justify-between">
            <div className="text-sm">
              <Link
                href="/forgot-password"
                className="text-blue-600 hover:text-blue-500"
              >
                Forgot your password?
              </Link>
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-2 px-4 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
          >
            {loading ? 'Logging in...' : 'Log in'}
          </button>
        </form>
      </div>
    </div>
  )
}
```

**Features:**
- Email and password inputs
- "Forgot password?" link
- "Create account" link
- Error messages
- Loading state
- Redirects to dashboard on success

---

#### 3. Sign Up Page (`/signup`)

**Purpose**: New user registration

```tsx
// app/signup/page.tsx
'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase'
import { useRouter } from 'next/navigation'
import Link from 'next/link'

export default function SignUpPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [companyName, setCompanyName] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  const handleSignUp = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    // Create auth user
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          company_name: companyName,
        },
      },
    })

    if (authError) {
      setError(authError.message)
      setLoading(false)
      return
    }

    // Redirect to onboarding
    router.push('/onboarding')
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="max-w-md w-full space-y-8 p-8 bg-white rounded-lg shadow">
        <div>
          <h2 className="text-3xl font-bold text-center">
            Create your account
          </h2>
          <p className="mt-2 text-center text-gray-600">
            Or{' '}
            <Link href="/login" className="text-blue-600 hover:text-blue-500">
              log in to existing account
            </Link>
          </p>
        </div>

        <form onSubmit={handleSignUp} className="space-y-6">
          {error && (
            <div className="bg-red-50 text-red-600 p-3 rounded">
              {error}
            </div>
          )}

          <div>
            <label htmlFor="companyName" className="block text-sm font-medium">
              Company Name
            </label>
            <input
              id="companyName"
              type="text"
              required
              value={companyName}
              onChange={(e) => setCompanyName(e.target.value)}
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md"
            />
          </div>

          <div>
            <label htmlFor="email" className="block text-sm font-medium">
              Work Email
            </label>
            <input
              id="email"
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md"
            />
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-medium">
              Password
            </label>
            <input
              id="password"
              type="password"
              required
              minLength={8}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md"
            />
            <p className="mt-1 text-sm text-gray-500">
              Must be at least 8 characters
            </p>
          </div>

          <div className="text-xs text-gray-600">
            By signing up, you agree to our{' '}
            <Link href="/terms" className="text-blue-600 hover:text-blue-500">
              Terms of Service
            </Link>{' '}
            and{' '}
            <Link href="/privacy" className="text-blue-600 hover:text-blue-500">
              Privacy Policy
            </Link>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-2 px-4 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
          >
            {loading ? 'Creating account...' : 'Create account'}
          </button>
        </form>
      </div>
    </div>
  )
}
```

**Features:**
- Company name input
- Email and password inputs
- Password strength requirements
- Terms and Privacy Policy links
- Redirects to onboarding

---

#### 4. Forgot Password Page (`/forgot-password`)

**Purpose**: Password recovery

```tsx
// app/forgot-password/page.tsx
'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase'
import Link from 'next/link'

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('')
  const [sent, setSent] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const supabase = createClient()

  const handleReset = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`,
    })

    if (error) {
      setError(error.message)
      setLoading(false)
    } else {
      setSent(true)
      setLoading(false)
    }
  }

  if (sent) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="max-w-md w-full p-8 bg-white rounded-lg shadow">
          <h2 className="text-2xl font-bold text-center mb-4">
            Check your email
          </h2>
          <p className="text-center text-gray-600 mb-6">
            We've sent a password reset link to {email}
          </p>
          <Link
            href="/login"
            className="block text-center text-blue-600 hover:text-blue-500"
          >
            Back to login
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="max-w-md w-full p-8 bg-white rounded-lg shadow">
        <h2 className="text-2xl font-bold text-center mb-2">
          Reset your password
        </h2>
        <p className="text-center text-gray-600 mb-6">
          Enter your email and we'll send you a reset link
        </p>

        <form onSubmit={handleReset} className="space-y-6">
          {error && (
            <div className="bg-red-50 text-red-600 p-3 rounded">
              {error}
            </div>
          )}

          <div>
            <label htmlFor="email" className="block text-sm font-medium">
              Email address
            </label>
            <input
              id="email"
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-2 px-4 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
          >
            {loading ? 'Sending...' : 'Send reset link'}
          </button>

          <div className="text-center">
            <Link
              href="/login"
              className="text-sm text-blue-600 hover:text-blue-500"
            >
              Back to login
            </Link>
          </div>
        </form>
      </div>
    </div>
  )
}
```

---

#### 5. Reset Password Page (`/reset-password`)

**Purpose**: Set new password after reset

```tsx
// app/reset-password/page.tsx
'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase'
import { useRouter } from 'next/navigation'

export default function ResetPasswordPage() {
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  const handleReset = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')

    if (password !== confirmPassword) {
      setError('Passwords do not match')
      return
    }

    if (password.length < 8) {
      setError('Password must be at least 8 characters')
      return
    }

    setLoading(true)

    const { error } = await supabase.auth.updateUser({
      password: password,
    })

    if (error) {
      setError(error.message)
      setLoading(false)
    } else {
      router.push('/login?reset=success')
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="max-w-md w-full p-8 bg-white rounded-lg shadow">
        <h2 className="text-2xl font-bold text-center mb-6">
          Set new password
        </h2>

        <form onSubmit={handleReset} className="space-y-6">
          {error && (
            <div className="bg-red-50 text-red-600 p-3 rounded">
              {error}
            </div>
          )}

          <div>
            <label htmlFor="password" className="block text-sm font-medium">
              New Password
            </label>
            <input
              id="password"
              type="password"
              required
              minLength={8}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md"
            />
          </div>

          <div>
            <label htmlFor="confirmPassword" className="block text-sm font-medium">
              Confirm Password
            </label>
            <input
              id="confirmPassword"
              type="password"
              required
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-2 px-4 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
          >
            {loading ? 'Updating...' : 'Update password'}
          </button>
        </form>
      </div>
    </div>
  )
}
```

---

#### 6. About Page (`/about`)

**Purpose**: Company information and mission

```tsx
// app/about/page.tsx
import { Footer } from '@/components/layout/Footer'

export default function AboutPage() {
  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white border-b">
        <div className="max-w-7xl mx-auto px-4 py-4">
          <Link href="/" className="text-xl font-bold">
            Mentions
          </Link>
        </div>
      </nav>

      <div className="max-w-4xl mx-auto px-4 py-16">
        <h1 className="text-4xl font-bold mb-8">About Mentions</h1>

        <div className="prose prose-lg">
          <h2>Our Mission</h2>
          <p>
            We believe Reddit is one of the most valuable channels for authentic customer
            acquisition, but it's time-consuming and requires genuine expertise to do well.
          </p>

          <p>
            Mentions combines AI with human oversight to help companies participate
            authentically in Reddit conversations at scale, providing real value to
            communities while building brand awareness.
          </p>

          <h2>How It Works</h2>
          <p>
            Our AI finds relevant conversations, drafts helpful replies grounded in your
            company's knowledge base, and presents them for human review. Every post is
            approved by a real person before going live, ensuring quality and authenticity.
          </p>

          <h2>Why We Built This</h2>
          <p>
            We saw too many companies either ignoring Reddit entirely or spamming it with
            low-quality promotional content. We built Mentions to enable a better approach:
            helpful, genuine participation that benefits both communities and businesses.
          </p>

          <h2>Our Values</h2>
          <ul>
            <li><strong>Authenticity First</strong> - Never spam, always provide value</li>
            <li><strong>Human Oversight</strong> - AI assists, humans decide</li>
            <li><strong>Community Respect</strong> - Follow rules, respect moderators</li>
            <li><strong>Transparency</strong> - Clear about what we do and how</li>
          </ul>

          <h2>Contact Us</h2>
          <p>
            Questions? Feedback? We'd love to hear from you at{' '}
            <a href="mailto:hello@mentions.ai">hello@mentions.ai</a>
          </p>
        </div>
      </div>

      <Footer />
    </div>
  )
}
```

---

#### 7. Terms of Service (`/terms`)

**Purpose**: Legal terms and conditions

```tsx
// app/terms/page.tsx
export default function TermsPage() {
  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white border-b">
        <div className="max-w-7xl mx-auto px-4 py-4">
          <Link href="/" className="text-xl font-bold">
            Mentions
          </Link>
        </div>
      </nav>

      <div className="max-w-4xl mx-auto px-4 py-16">
        <h1 className="text-4xl font-bold mb-8">Terms of Service</h1>
        <p className="text-sm text-gray-600 mb-8">
          Last updated: November 5, 2025
        </p>

        <div className="prose prose-lg">
          <h2>1. Acceptance of Terms</h2>
          <p>
            By accessing and using Mentions ("the Service"), you accept and agree to be
            bound by these Terms of Service...
          </p>

          <h2>2. Description of Service</h2>
          <p>
            Mentions provides an AI-powered platform to help businesses participate in
            Reddit conversations. The Service includes...
          </p>

          <h2>3. User Responsibilities</h2>
          <p>You agree to:</p>
          <ul>
            <li>Provide accurate company and contact information</li>
            <li>Use the Service in compliance with Reddit's Terms of Service</li>
            <li>Review and approve all content before posting</li>
            <li>Not use the Service for spam or manipulation</li>
            <li>Respect subreddit rules and moderator decisions</li>
          </ul>

          <h2>4. Reddit Integration</h2>
          <p>
            The Service connects to Reddit via OAuth. You are responsible for maintaining
            the security of your Reddit account credentials...
          </p>

          <h2>5. Content and Intellectual Property</h2>
          <p>
            You retain ownership of all content you provide. By using the Service, you grant
            us a license to process this content...
          </p>

          <h2>6. Prohibited Uses</h2>
          <p>You may not use the Service to:</p>
          <ul>
            <li>Spam or manipulate Reddit communities</li>
            <li>Violate Reddit's Terms of Service or Content Policy</li>
            <li>Impersonate others or misrepresent affiliations</li>
            <li>Post illegal, harmful, or offensive content</li>
          </ul>

          <h2>7. Account Termination</h2>
          <p>
            We reserve the right to suspend or terminate accounts that violate these terms...
          </p>

          <h2>8. Limitation of Liability</h2>
          <p>
            The Service is provided "as is" without warranties. We are not liable for...
          </p>

          <h2>9. Changes to Terms</h2>
          <p>
            We may update these terms from time to time. Continued use constitutes
            acceptance...
          </p>

          <h2>10. Contact</h2>
          <p>
            Questions about these terms? Contact us at{' '}
            <a href="mailto:legal@mentions.ai">legal@mentions.ai</a>
          </p>
        </div>
      </div>
    </div>
  )
}
```

---

#### 8. Privacy Policy (`/privacy`)

**Purpose**: Data collection and usage policy

```tsx
// app/privacy/page.tsx
export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white border-b">
        <div className="max-w-7xl mx-auto px-4 py-4">
          <Link href="/" className="text-xl font-bold">
            Mentions
          </Link>
        </div>
      </nav>

      <div className="max-w-4xl mx-auto px-4 py-16">
        <h1 className="text-4xl font-bold mb-8">Privacy Policy</h1>
        <p className="text-sm text-gray-600 mb-8">
          Last updated: November 5, 2025
        </p>

        <div className="prose prose-lg">
          <h2>1. Information We Collect</h2>
          
          <h3>Account Information</h3>
          <ul>
            <li>Email address</li>
            <li>Company name</li>
            <li>Reddit account information (via OAuth)</li>
          </ul>

          <h3>Company Data</h3>
          <ul>
            <li>Company knowledge base documents</li>
            <li>Brand guidelines and prompts</li>
            <li>Keywords and goals</li>
          </ul>

          <h3>Usage Data</h3>
          <ul>
            <li>Generated drafts and edits</li>
            <li>Approval/rejection decisions</li>
            <li>Posted comments and engagement metrics</li>
            <li>System logs and analytics</li>
          </ul>

          <h2>2. How We Use Your Information</h2>
          <p>We use collected data to:</p>
          <ul>
            <li>Provide and improve the Service</li>
            <li>Generate relevant draft replies</li>
            <li>Train and fine-tune models (company-specific)</li>
            <li>Analyze performance and engagement</li>
            <li>Provide customer support</li>
          </ul>

          <h2>3. Data Storage and Security</h2>
          <p>
            Data is stored in Supabase (PostgreSQL) and Google Cloud Platform. Reddit
            credentials are encrypted using Google Cloud KMS...
          </p>

          <h2>4. Third-Party Services</h2>
          <p>We use the following third-party services:</p>
          <ul>
            <li><strong>Supabase</strong> - Database and authentication</li>
            <li><strong>OpenAI</strong> - AI model API</li>
            <li><strong>Google Cloud</strong> - Infrastructure</li>
            <li><strong>Reddit</strong> - API for posting</li>
          </ul>

          <h2>5. Data Retention</h2>
          <p>
            We retain data for as long as your account is active. You can request data
            deletion at any time...
          </p>

          <h2>6. Your Rights</h2>
          <p>You have the right to:</p>
          <ul>
            <li>Access your data</li>
            <li>Correct inaccurate data</li>
            <li>Request data deletion</li>
            <li>Export your data</li>
            <li>Opt out of certain data processing</li>
          </ul>

          <h2>7. Cookies and Tracking</h2>
          <p>
            We use cookies for authentication and analytics. You can control cookie
            preferences in your browser...
          </p>

          <h2>8. Changes to Privacy Policy</h2>
          <p>
            We may update this policy. Material changes will be notified via email...
          </p>

          <h2>9. Contact</h2>
          <p>
            Privacy questions? Contact{' '}
            <a href="mailto:privacy@mentions.ai">privacy@mentions.ai</a>
          </p>
        </div>
      </div>
    </div>
  )
}
```

---

### Authenticated Pages

#### 9. Dashboard (`/dashboard`)

**Purpose**: Main overview after login

```tsx
// app/dashboard/page.tsx
export default async function DashboardPage() {
  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold">Dashboard</h1>
          <p className="text-gray-600">Welcome back! Here's your overview.</p>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <StatCard
            title="Pending Review"
            value="12"
            icon={InboxIcon}
            link="/inbox"
          />
          <StatCard
            title="Posts This Week"
            value="45"
            change="+12%"
            icon={TrendingUpIcon}
          />
          <StatCard
            title="Avg. Engagement"
            value="8.5"
            change="+2.3"
            icon={HeartIcon}
          />
          <StatCard
            title="Active Subreddits"
            value="23"
            icon={UsersIcon}
          />
        </div>

        {/* Recent Activity */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <RecentDrafts />
          <RecentPosts />
        </div>

        {/* Quick Actions */}
        <QuickActions />
      </div>
    </DashboardLayout>
  )
}
```

---

#### 10. Inbox / Content Review (`/inbox`)

**Purpose**: Review and approve drafts (PRIMARY WORKFLOW)

See **14-UI-SPECIFICATIONS.md** for complete specification.

**Key Features:**
- Filterable table of pending drafts
- Sort by date, risk, subreddit, keyword
- Click to open detail view
- Status indicators (New, Edited, Approved, Posted)

---

#### 11. Draft Detail (`/drafts/[id]`)

**Purpose**: Review and edit individual draft

See **14-UI-SPECIFICATIONS.md** for complete specification.

**Key Features:**
- Thread context
- Rules summary
- RAG context
- Draft variants
- Edit functionality
- Approve & Post button

---

#### 12. Settings (`/settings`)

**Purpose**: Account and company configuration

```tsx
// app/settings/layout.tsx
export default function SettingsLayout({ children }) {
  return (
    <DashboardLayout>
      <div className="flex gap-8">
        {/* Sidebar Navigation */}
        <nav className="w-64 space-y-2">
          <SettingsLink href="/settings/profile" icon={UserIcon}>
            Profile
          </SettingsLink>
          <SettingsLink href="/settings/company" icon={BuildingIcon}>
            Company
          </SettingsLink>
          <SettingsLink href="/settings/reddit" icon={RedditIcon}>
            Reddit Accounts
          </SettingsLink>
          <SettingsLink href="/settings/prompts" icon={SparklesIcon}>
            Prompts
          </SettingsLink>
          <SettingsLink href="/settings/company-data" icon={DocumentIcon}>
            Company Data
          </SettingsLink>
          <SettingsLink href="/settings/posting" icon={SendIcon}>
            Posting Settings
          </SettingsLink>
          <SettingsLink href="/settings/team" icon={UsersIcon}>
            Team Members
          </SettingsLink>
          <SettingsLink href="/settings/billing" icon={CreditCardIcon}>
            Billing
          </SettingsLink>
        </nav>

        {/* Content */}
        <div className="flex-1">
          {children}
        </div>
      </div>
    </DashboardLayout>
  )
}
```

**Sub-pages:**
- `/settings/profile` - User profile and password
- `/settings/company` - Company details and goals
- `/settings/reddit` - Connect/manage Reddit accounts
- `/settings/prompts` - Manage company prompts
- `/settings/company-data` - Upload knowledge base docs
- `/settings/posting` - Volume controls and eligibility
- `/settings/team` - Invite/manage team members
- `/settings/billing` - Subscription and payment

---

#### 13. Analytics (`/analytics`)

**Purpose**: Performance metrics and insights

```tsx
// app/analytics/page.tsx
export default function AnalyticsPage() {
  return (
    <DashboardLayout>
      <div className="space-y-6">
        <h1 className="text-3xl font-bold">Analytics</h1>

        {/* Date Range Selector */}
        <DateRangePicker />

        {/* Key Metrics */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <MetricCard title="Total Posts" value="342" />
          <MetricCard title="Approval Rate" value="87%" />
          <MetricCard title="Avg. Score" value="12.5" />
          <MetricCard title="Removal Rate" value="2.1%" />
        </div>

        {/* Charts */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <PostsOverTimeChart />
          <EngagementBySubredditChart />
        </div>

        {/* Tables */}
        <TopPerformingPostsTable />
        <SubredditPerformanceTable />
      </div>
    </DashboardLayout>
  )
}
```

---

#### 14. Onboarding (`/onboarding`)

**Purpose**: Guide new users through setup

```tsx
// app/onboarding/page.tsx
'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'

export default function OnboardingPage() {
  const [step, setStep] = useState(1)
  const router = useRouter()

  const steps = [
    {
      title: 'Configure Reddit App',
      description: 'Create a Reddit app for your company',
      component: <RedditAppSetup />,
    },
    {
      title: 'Connect Reddit Account',
      description: 'Link your Reddit account for posting',
      component: <RedditAccountConnect />,
    },
    {
      title: 'Set Company Goal',
      description: 'Tell us about your business',
      component: <CompanyGoalSetup />,
    },
    {
      title: 'Add Company Data',
      description: 'Upload knowledge base documents',
      component: <CompanyDataUpload />,
    },
    {
      title: 'Create Prompt',
      description: 'Define your brand voice',
      component: <PromptSetup />,
    },
  ]

  const currentStep = steps[step - 1]

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-3xl mx-auto py-12 px-4">
        {/* Progress Bar */}
        <div className="mb-8">
          <div className="flex justify-between mb-2">
            <span className="text-sm font-medium">
              Step {step} of {steps.length}
            </span>
            <span className="text-sm text-gray-600">
              {Math.round((step / steps.length) * 100)}% complete
            </span>
          </div>
          <div className="h-2 bg-gray-200 rounded-full">
            <div
              className="h-2 bg-blue-600 rounded-full transition-all"
              style={{ width: `${(step / steps.length) * 100}%` }}
            />
          </div>
        </div>

        {/* Current Step */}
        <div className="bg-white rounded-lg shadow p-8">
          <h2 className="text-2xl font-bold mb-2">{currentStep.title}</h2>
          <p className="text-gray-600 mb-8">{currentStep.description}</p>

          {currentStep.component}

          {/* Navigation */}
          <div className="flex justify-between mt-8">
            <button
              onClick={() => setStep(step - 1)}
              disabled={step === 1}
              className="px-4 py-2 text-gray-600 disabled:opacity-50"
            >
              Back
            </button>
            <button
              onClick={() => {
                if (step === steps.length) {
                  router.push('/dashboard')
                } else {
                  setStep(step + 1)
                }
              }}
              className="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
            >
              {step === steps.length ? 'Finish' : 'Continue'}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
```

---

## Navigation Component

### Main Navigation Bar

```tsx
// components/layout/DashboardLayout.tsx
'use client'

import { useState } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { createClient } from '@/lib/supabase'
import { useRouter } from 'next/navigation'

export function DashboardLayout({ children }: { children: React.Node }) {
  const pathname = usePathname()
  const router = useRouter()
  const supabase = createClient()

  const handleLogout = async () => {
    await supabase.auth.signOut()
    router.push('/login')
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Top Navigation */}
      <nav className="bg-white border-b">
        <div className="max-w-7xl mx-auto px-4">
          <div className="flex justify-between h-16">
            <div className="flex items-center gap-8">
              <Link href="/dashboard" className="text-xl font-bold">
                Mentions
              </Link>

              <div className="flex gap-1">
                <NavLink href="/dashboard" active={pathname === '/dashboard'}>
                  Dashboard
                </NavLink>
                <NavLink href="/inbox" active={pathname.startsWith('/inbox')}>
                  Inbox
                  <Badge count={12} />
                </NavLink>
                <NavLink href="/analytics" active={pathname === '/analytics'}>
                  Analytics
                </NavLink>
                <NavLink href="/settings" active={pathname.startsWith('/settings')}>
                  Settings
                </NavLink>
              </div>
            </div>

            <div className="flex items-center gap-4">
              {/* User Menu */}
              <UserMenu onLogout={handleLogout} />
            </div>
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 py-8">
        {children}
      </main>
    </div>
  )
}
```

---

## Route Protection

### Middleware for Auth

```tsx
// middleware.ts
import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function middleware(request: NextRequest) {
  const response = NextResponse.next()

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) {
          return request.cookies.get(name)?.value
        },
        set(name: string, value: string, options: any) {
          response.cookies.set({ name, value, ...options })
        },
        remove(name: string, options: any) {
          response.cookies.set({ name, value: '', ...options })
        },
      },
    }
  )

  const { data: { user } } = await supabase.auth.getUser()

  // Protected routes
  const protectedPaths = ['/dashboard', '/inbox', '/settings', '/analytics', '/drafts']
  const isProtectedPath = protectedPaths.some(path => 
    request.nextUrl.pathname.startsWith(path)
  )

  // Redirect to login if not authenticated
  if (isProtectedPath && !user) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  // Redirect to dashboard if authenticated and trying to access auth pages
  const authPaths = ['/login', '/signup']
  const isAuthPath = authPaths.some(path => 
    request.nextUrl.pathname.startsWith(path)
  )

  if (isAuthPath && user) {
    return NextResponse.redirect(new URL('/dashboard', request.url))
  }

  return response
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
```

---

## Complete Page List

### Public Pages
- ✅ `/` - Landing page
- ✅ `/login` - Login
- ✅ `/signup` - Sign up
- ✅ `/forgot-password` - Password recovery
- ✅ `/reset-password` - Set new password
- ✅ `/about` - About page
- ✅ `/terms` - Terms of Service
- ✅ `/privacy` - Privacy Policy
- `/pricing` - Pricing (if separate from landing)
- `/demo` - Product demo/tour

### Authenticated Pages
- ✅ `/dashboard` - Main dashboard
- ✅ `/inbox` - Content review (MAIN WORKFLOW)
- ✅ `/drafts/[id]` - Draft detail view
- ✅ `/analytics` - Performance analytics
- ✅ `/onboarding` - Setup wizard
- ✅ `/settings` - Settings hub
- ✅ `/settings/profile` - User profile
- ✅ `/settings/company` - Company settings
- ✅ `/settings/reddit` - Reddit accounts
- ✅ `/settings/prompts` - Prompt management
- ✅ `/settings/company-data` - Knowledge base
- ✅ `/settings/posting` - Posting controls
- ✅ `/settings/team` - Team management
- ✅ `/settings/billing` - Billing

### API Routes
- `/api/auth/callback` - Supabase auth callback
- `/api/reddit/callback` - Reddit OAuth callback

---

## Next Steps

1. **M1**: Implement public pages (landing, login, signup, terms, privacy)
2. **M2**: Implement onboarding flow
3. **M3**: Implement main dashboard and inbox
4. **M4**: Implement settings pages
5. **M5**: Implement analytics

All pages should be mobile-responsive and follow Tailwind/shadcn design system.

