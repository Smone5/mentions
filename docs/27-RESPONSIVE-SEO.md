# Responsive Design & SEO Optimization

## Overview
All pages must be fully responsive (mobile/tablet/desktop) and optimized for search engines to maximize organic traffic and user experience.

**Framework**: Next.js 14 App Router (built-in SEO features)  
**Styling**: Tailwind CSS (mobile-first by default)  
**Target Devices**: Mobile (375px+), Tablet (768px+), Desktop (1024px+)

---

## Responsive Design Strategy

### Mobile-First Approach

Tailwind CSS is mobile-first by default. Start with mobile layout and add breakpoints for larger screens.

**Breakpoints:**
```typescript
// Tailwind default breakpoints
sm: '640px'   // Small tablets
md: '768px'   // Tablets
lg: '1024px'  // Laptops
xl: '1280px'  // Desktops
2xl: '1536px' // Large desktops
```

### Responsive Patterns

#### 1. Navigation

```tsx
// components/layout/Navbar.tsx
'use client'

import { useState } from 'react'
import Link from 'next/link'
import { Menu, X } from 'lucide-react'

export function Navbar() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)

  return (
    <nav className="bg-white border-b sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          {/* Logo - Always visible */}
          <div className="flex items-center">
            <Link href="/" className="text-xl font-bold">
              Mentions
            </Link>
          </div>

          {/* Desktop Navigation - Hidden on mobile */}
          <div className="hidden md:flex items-center gap-6">
            <Link href="/#features" className="text-gray-700 hover:text-gray-900">
              Features
            </Link>
            <Link href="/#pricing" className="text-gray-700 hover:text-gray-900">
              Pricing
            </Link>
            <Link href="/about" className="text-gray-700 hover:text-gray-900">
              About
            </Link>
            <Link href="/login" className="text-gray-700 hover:text-gray-900">
              Log In
            </Link>
            <Link
              href="/signup"
              className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
            >
              Sign Up
            </Link>
          </div>

          {/* Mobile Menu Button - Only on mobile */}
          <div className="md:hidden flex items-center">
            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              className="p-2 rounded-md text-gray-700 hover:bg-gray-100"
              aria-label="Toggle menu"
            >
              {mobileMenuOpen ? <X size={24} /> : <Menu size={24} />}
            </button>
          </div>
        </div>
      </div>

      {/* Mobile Menu - Slides down on mobile */}
      {mobileMenuOpen && (
        <div className="md:hidden border-t">
          <div className="px-4 py-2 space-y-1">
            <Link
              href="/#features"
              className="block px-3 py-2 rounded-md hover:bg-gray-100"
              onClick={() => setMobileMenuOpen(false)}
            >
              Features
            </Link>
            <Link
              href="/#pricing"
              className="block px-3 py-2 rounded-md hover:bg-gray-100"
              onClick={() => setMobileMenuOpen(false)}
            >
              Pricing
            </Link>
            <Link
              href="/about"
              className="block px-3 py-2 rounded-md hover:bg-gray-100"
              onClick={() => setMobileMenuOpen(false)}
            >
              About
            </Link>
            <Link
              href="/login"
              className="block px-3 py-2 rounded-md hover:bg-gray-100"
              onClick={() => setMobileMenuOpen(false)}
            >
              Log In
            </Link>
            <Link
              href="/signup"
              className="block px-3 py-2 bg-blue-600 text-white rounded-md text-center"
              onClick={() => setMobileMenuOpen(false)}
            >
              Sign Up
            </Link>
          </div>
        </div>
      )}
    </nav>
  )
}
```

#### 2. Hero Section

```tsx
// components/landing/HeroSection.tsx
export function HeroSection() {
  return (
    <section className="relative overflow-hidden bg-gradient-to-b from-blue-50 to-white">
      {/* Container with responsive padding */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16 lg:py-24">
        {/* Two-column layout - stacks on mobile */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-12 items-center">
          {/* Text Content - Full width on mobile, half on desktop */}
          <div className="text-center lg:text-left">
            {/* Responsive heading sizes */}
            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-bold text-gray-900 mb-4 sm:mb-6">
              Turn Reddit into Your{' '}
              <span className="text-blue-600">Customer Acquisition</span> Channel
            </h1>
            
            {/* Responsive paragraph size */}
            <p className="text-lg sm:text-xl text-gray-600 mb-6 sm:mb-8">
              AI-powered Reddit reply assistant that finds relevant conversations
              and drafts helpful responses grounded in your company knowledge.
            </p>

            {/* CTA Buttons - Stack on mobile, side-by-side on tablet+ */}
            <div className="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start">
              <Link
                href="/signup"
                className="px-6 sm:px-8 py-3 sm:py-4 bg-blue-600 text-white rounded-md text-lg font-medium hover:bg-blue-700 text-center"
              >
                Get Started Free
              </Link>
              <Link
                href="#demo"
                className="px-6 sm:px-8 py-3 sm:py-4 bg-white text-gray-900 border-2 border-gray-300 rounded-md text-lg font-medium hover:bg-gray-50 text-center"
              >
                Watch Demo
              </Link>
            </div>
          </div>

          {/* Hero Image - Hidden on small mobile, shown on larger screens */}
          <div className="hidden sm:block">
            <img
              src="/images/hero-dashboard.png"
              alt="Mentions Dashboard"
              className="rounded-lg shadow-2xl"
              width={600}
              height={400}
            />
          </div>
        </div>
      </div>
    </section>
  )
}
```

#### 3. Feature Cards

```tsx
// components/landing/FeaturesSection.tsx
export function FeaturesSection() {
  const features = [
    {
      icon: SearchIcon,
      title: 'Smart Subreddit Discovery',
      description: 'AI finds the best communities for your brand',
    },
    // ... more features
  ]

  return (
    <section className="py-12 sm:py-16 lg:py-24 bg-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Responsive grid - 1 col mobile, 2 col tablet, 3 col desktop */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 lg:gap-8">
          {features.map((feature, i) => (
            <div
              key={i}
              className="p-6 bg-gray-50 rounded-lg hover:shadow-lg transition-shadow"
            >
              <feature.icon className="w-10 h-10 sm:w-12 sm:h-12 text-blue-600 mb-4" />
              <h3 className="text-xl sm:text-2xl font-bold mb-2">
                {feature.title}
              </h3>
              <p className="text-gray-600 text-base sm:text-lg">
                {feature.description}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
```

#### 4. Pricing Cards

```tsx
// components/pricing/PricingCard.tsx
export function PricingSection() {
  return (
    <section className="py-12 sm:py-16 lg:py-24 bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Responsive grid - 1 col mobile, 3 cols desktop */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 lg:gap-8">
          {plans.map((plan) => (
            <div
              key={plan.name}
              className="bg-white rounded-lg shadow-lg p-6 sm:p-8"
            >
              {/* Card content remains readable on all sizes */}
              <h3 className="text-2xl font-bold mb-4">{plan.name}</h3>
              <div className="flex items-baseline mb-6">
                <span className="text-4xl sm:text-5xl font-bold">
                  {plan.price}
                </span>
                {plan.period && (
                  <span className="text-gray-600 ml-2">{plan.period}</span>
                )}
              </div>
              {/* Features list with proper spacing */}
              <ul className="space-y-3 mb-8">
                {plan.features.map((feature, i) => (
                  <li key={i} className="flex items-start text-sm sm:text-base">
                    <CheckIcon className="w-5 h-5 text-green-500 mr-2 flex-shrink-0 mt-0.5" />
                    <span>{feature}</span>
                  </li>
                ))}
              </ul>
              {/* Full-width CTA button */}
              <Link
                href={plan.ctaLink}
                className="block w-full py-3 text-center rounded-md font-medium"
              >
                {plan.cta}
              </Link>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
```

#### 5. Inbox Table (Mobile-Optimized)

```tsx
// app/inbox/page.tsx
export default function InboxPage() {
  return (
    <div className="space-y-4">
      {/* Desktop Table View - Hidden on mobile */}
      <div className="hidden lg:block">
        <table className="w-full">
          <thead>
            <tr className="border-b">
              <th>Subreddit</th>
              <th>Thread Title</th>
              <th>Keyword</th>
              <th>Risk</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {drafts.map((draft) => (
              <tr key={draft.id} className="border-b hover:bg-gray-50">
                <td className="py-3 px-4">{draft.subreddit}</td>
                <td className="py-3 px-4">{draft.title}</td>
                <td className="py-3 px-4">{draft.keyword}</td>
                <td className="py-3 px-4">
                  <RiskBadge risk={draft.risk} />
                </td>
                <td className="py-3 px-4">{draft.created}</td>
                <td className="py-3 px-4">
                  <Link href={`/drafts/${draft.id}`}>View</Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Mobile Card View - Shown on mobile */}
      <div className="lg:hidden space-y-3">
        {drafts.map((draft) => (
          <Link
            key={draft.id}
            href={`/drafts/${draft.id}`}
            className="block bg-white rounded-lg border p-4 hover:shadow-md"
          >
            <div className="flex justify-between items-start mb-2">
              <span className="font-medium text-blue-600">
                r/{draft.subreddit}
              </span>
              <RiskBadge risk={draft.risk} />
            </div>
            <h3 className="font-medium mb-2 line-clamp-2">
              {draft.title}
            </h3>
            <div className="flex justify-between items-center text-sm text-gray-600">
              <span>{draft.keyword}</span>
              <span>{draft.created}</span>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}
```

---

## SEO Optimization

### Next.js Metadata API

```tsx
// app/layout.tsx
import { Metadata } from 'next'

export const metadata: Metadata = {
  metadataBase: new URL('https://mentions.ai'),
  title: {
    default: 'Mentions - AI-Powered Reddit Marketing Assistant',
    template: '%s | Mentions'
  },
  description: 'Turn Reddit into your customer acquisition channel. AI-powered assistant that finds relevant conversations and drafts helpful, grounded responses.',
  keywords: ['reddit marketing', 'ai assistant', 'customer acquisition', 'reddit automation', 'content marketing'],
  authors: [{ name: 'Mentions' }],
  creator: 'Mentions',
  publisher: 'Mentions',
  formatDetection: {
    email: false,
    address: false,
    telephone: false,
  },
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: 'https://mentions.ai',
    title: 'Mentions - AI-Powered Reddit Marketing Assistant',
    description: 'Turn Reddit into your customer acquisition channel with AI-powered assistance.',
    siteName: 'Mentions',
    images: [
      {
        url: '/og-image.png',
        width: 1200,
        height: 630,
        alt: 'Mentions Dashboard',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Mentions - AI-Powered Reddit Marketing Assistant',
    description: 'Turn Reddit into your customer acquisition channel with AI-powered assistance.',
    images: ['/og-image.png'],
    creator: '@mentions_ai',
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  icons: {
    icon: '/favicon.ico',
    shortcut: '/favicon-16x16.png',
    apple: '/apple-touch-icon.png',
  },
  manifest: '/site.webmanifest',
}
```

### Page-Specific Metadata

```tsx
// app/about/page.tsx
import { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'About Us',
  description: 'Learn about Mentions mission to help companies participate authentically in Reddit conversations at scale.',
  openGraph: {
    title: 'About Mentions',
    description: 'Learn about our mission to help companies participate authentically in Reddit conversations.',
    url: 'https://mentions.ai/about',
  },
}

export default function AboutPage() {
  // ...
}
```

```tsx
// app/pricing/page.tsx
export const metadata: Metadata = {
  title: 'Pricing',
  description: 'Flexible plans for every marketing team. Start at $99/month with Starter plan or scale with Growth at $399/month.',
  openGraph: {
    title: 'Mentions Pricing - Plans from $99/month',
    description: 'Choose the perfect plan for your Reddit marketing needs.',
    url: 'https://mentions.ai/pricing',
  },
}
```

### Structured Data (JSON-LD)

```tsx
// components/seo/StructuredData.tsx
export function OrganizationSchema() {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: 'Mentions',
    url: 'https://mentions.ai',
    logo: 'https://mentions.ai/logo.png',
    description: 'AI-powered Reddit marketing assistant for authentic customer acquisition',
    foundingDate: '2025',
    sameAs: [
      'https://twitter.com/mentions_ai',
      'https://www.linkedin.com/company/mentions-ai',
    ],
    contactPoint: {
      '@type': 'ContactPoint',
      contactType: 'Customer Support',
      email: 'support@mentions.ai',
    },
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  )
}

export function SoftwareSchema() {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'SoftwareApplication',
    name: 'Mentions',
    applicationCategory: 'BusinessApplication',
    operatingSystem: 'Web',
    offers: {
      '@type': 'AggregateOffer',
      lowPrice: '99',
      highPrice: '399',
      priceCurrency: 'USD',
      priceSpecification: {
        '@type': 'UnitPriceSpecification',
        price: '99',
        priceCurrency: 'USD',
        billingDuration: 'P1M',
      },
    },
    aggregateRating: {
      '@type': 'AggregateRating',
      ratingValue: '4.8',
      ratingCount: '127',
    },
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  )
}

// Add to app/layout.tsx
export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <head>
        <OrganizationSchema />
        <SoftwareSchema />
      </head>
      <body>{children}</body>
    </html>
  )
}
```

### Sitemap

```typescript
// app/sitemap.ts
import { MetadataRoute } from 'next'

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = 'https://mentions.ai'
  
  return [
    {
      url: baseUrl,
      lastModified: new Date(),
      changeFrequency: 'weekly',
      priority: 1,
    },
    {
      url: `${baseUrl}/about`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.8,
    },
    {
      url: `${baseUrl}/pricing`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.9,
    },
    {
      url: `${baseUrl}/login`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.5,
    },
    {
      url: `${baseUrl}/signup`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.7,
    },
    {
      url: `${baseUrl}/terms`,
      lastModified: new Date(),
      changeFrequency: 'yearly',
      priority: 0.3,
    },
    {
      url: `${baseUrl}/privacy`,
      lastModified: new Date(),
      changeFrequency: 'yearly',
      priority: 0.3,
    },
  ]
}
```

### Robots.txt

```typescript
// app/robots.ts
import { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: [
          '/dashboard/',
          '/inbox/',
          '/settings/',
          '/drafts/',
          '/analytics/',
          '/api/',
        ],
      },
    ],
    sitemap: 'https://mentions.ai/sitemap.xml',
  }
}
```

---

## Performance Optimization

### Image Optimization

```tsx
// Use Next.js Image component for automatic optimization
import Image from 'next/image'

export function HeroImage() {
  return (
    <Image
      src="/images/hero-dashboard.png"
      alt="Mentions Dashboard showing draft review interface"
      width={1200}
      height={800}
      priority // Load above the fold images first
      placeholder="blur"
      blurDataURL="data:image/jpeg;base64,..." // Low-quality placeholder
      sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
    />
  )
}

// For logos and icons
export function Logo() {
  return (
    <Image
      src="/logo.svg"
      alt="Mentions logo"
      width={120}
      height={40}
      priority
    />
  )
}
```

### Font Optimization

```typescript
// app/layout.tsx
import { Inter } from 'next/font/google'

const inter = Inter({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-inter',
})

export default function RootLayout({ children }) {
  return (
    <html lang="en" className={inter.variable}>
      <body className="font-sans">{children}</body>
    </html>
  )
}
```

### Code Splitting

```tsx
// Dynamic imports for heavy components
import dynamic from 'next/dynamic'

// Load analytics dashboard only when needed
const AnalyticsChart = dynamic(
  () => import('@/components/analytics/Chart'),
  { loading: () => <ChartSkeleton /> }
)

// Load draft editor only when viewing a draft
const DraftEditor = dynamic(
  () => import('@/components/drafts/Editor'),
  { ssr: false } // Don't server-render
)
```

---

## Accessibility

### Semantic HTML

```tsx
// Use proper HTML elements
export function LandingPage() {
  return (
    <>
      <header>
        <Navbar />
      </header>
      
      <main>
        <section aria-labelledby="hero-heading">
          <h1 id="hero-heading">Turn Reddit into Your Customer Acquisition Channel</h1>
          {/* ... */}
        </section>
        
        <section aria-labelledby="features-heading">
          <h2 id="features-heading">Features</h2>
          {/* ... */}
        </section>
      </main>
      
      <footer>
        <Footer />
      </footer>
    </>
  )
}
```

### ARIA Labels

```tsx
// Add labels for screen readers
<button
  onClick={handleMenuToggle}
  aria-label="Toggle navigation menu"
  aria-expanded={isOpen}
>
  <MenuIcon />
</button>

// Skip to main content link
<a
  href="#main-content"
  className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 bg-blue-600 text-white px-4 py-2 rounded"
>
  Skip to main content
</a>

<main id="main-content">
  {/* Page content */}
</main>
```

### Keyboard Navigation

```tsx
// Ensure all interactive elements are keyboard accessible
<div
  role="button"
  tabIndex={0}
  onClick={handleClick}
  onKeyDown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      handleClick()
    }
  }}
>
  Click me
</div>
```

---

## Mobile-Specific Optimizations

### Touch Targets

```tsx
// Ensure minimum 44x44px touch targets on mobile
<button className="min-h-[44px] min-w-[44px] flex items-center justify-center">
  <Icon size={20} />
</button>
```

### Viewport Meta Tag

```tsx
// app/layout.tsx
export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=5" />
        <meta name="theme-color" content="#3B82F6" />
      </head>
      <body>{children}</body>
    </html>
  )
}
```

### iOS Safe Areas

```css
/* globals.css */
@supports (padding: max(0px)) {
  .safe-area-inset-bottom {
    padding-bottom: max(1rem, env(safe-area-inset-bottom));
  }
  
  .safe-area-inset-top {
    padding-top: max(1rem, env(safe-area-inset-top));
  }
}
```

---

## Testing Checklist

### Responsive Testing
- [ ] Test on iPhone SE (375px)
- [ ] Test on iPhone 14 (390px)
- [ ] Test on iPad (768px)
- [ ] Test on iPad Pro (1024px)
- [ ] Test on desktop (1280px+)
- [ ] Test on large desktop (1920px+)
- [ ] Test in landscape orientation
- [ ] Test with browser zoom (100%, 150%, 200%)

### SEO Testing
- [ ] Google PageSpeed Insights score >90
- [ ] All pages have unique titles
- [ ] All pages have unique descriptions
- [ ] Images have alt text
- [ ] Heading hierarchy (H1 → H2 → H3)
- [ ] Internal links use descriptive anchor text
- [ ] Sitemap.xml accessible
- [ ] Robots.txt configured correctly
- [ ] Schema markup validates
- [ ] Open Graph tags present
- [ ] Twitter Card tags present

### Accessibility Testing
- [ ] Keyboard navigation works
- [ ] Screen reader friendly
- [ ] Color contrast meets WCAG AA
- [ ] Focus indicators visible
- [ ] ARIA labels where needed
- [ ] Form labels associated
- [ ] Skip links present

### Performance Testing
- [ ] First Contentful Paint <1.8s
- [ ] Largest Contentful Paint <2.5s
- [ ] Cumulative Layout Shift <0.1
- [ ] Time to Interactive <3.8s
- [ ] Images lazy-loaded
- [ ] Fonts preloaded
- [ ] Bundle size optimized

---

## Tools & Resources

### Testing Tools
- **Chrome DevTools** - Responsive design mode
- **Lighthouse** - Performance and SEO audits
- **PageSpeed Insights** - Google's performance tool
- **Mobile-Friendly Test** - Google mobile compatibility
- **Rich Results Test** - Schema markup validator
- **WAVE** - Accessibility checker
- **axe DevTools** - Accessibility testing

### Browser Testing
- **BrowserStack** - Real device testing
- **Responsive Design Mode** - Chrome DevTools
- **Safari Responsive Design Mode** - Safari DevTools

### Monitoring
- **Google Search Console** - SEO monitoring
- **Google Analytics 4** - Traffic analysis
- **Vercel Analytics** - Performance monitoring (if using Vercel)

---

## Implementation Checklist

### Phase 1: Foundation
- [ ] Set up Tailwind CSS with mobile-first approach
- [ ] Create responsive layout components
- [ ] Implement Next.js Image optimization
- [ ] Add font optimization
- [ ] Configure metadata API

### Phase 2: SEO
- [ ] Add page-specific metadata
- [ ] Implement structured data
- [ ] Create sitemap.xml
- [ ] Configure robots.txt
- [ ] Add Open Graph images
- [ ] Set up canonical URLs

### Phase 3: Testing
- [ ] Test all breakpoints
- [ ] Run Lighthouse audits
- [ ] Test keyboard navigation
- [ ] Validate schema markup
- [ ] Check mobile usability
- [ ] Test page load speeds

### Phase 4: Optimization
- [ ] Optimize images
- [ ] Reduce bundle size
- [ ] Implement lazy loading
- [ ] Add loading skeletons
- [ ] Configure caching headers
- [ ] Enable compression

---

## Best Practices Summary

**Responsive Design:**
✅ Mobile-first approach  
✅ Use Tailwind breakpoints  
✅ Test on real devices  
✅ Optimize touch targets  
✅ Handle orientation changes  

**SEO:**
✅ Unique titles and descriptions  
✅ Structured data markup  
✅ Semantic HTML  
✅ Fast page loads  
✅ Mobile-friendly  

**Performance:**
✅ Optimize images  
✅ Code splitting  
✅ Lazy loading  
✅ Font optimization  
✅ Minimal JavaScript  

**Accessibility:**
✅ Semantic HTML  
✅ ARIA labels  
✅ Keyboard navigation  
✅ Color contrast  
✅ Screen reader friendly  

All pages should achieve:
- **PageSpeed Score**: 90+ (mobile and desktop)
- **Accessibility Score**: 100
- **SEO Score**: 100
- **Best Practices Score**: 100

