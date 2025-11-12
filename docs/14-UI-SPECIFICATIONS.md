# UI Specifications

Complete UI/UX specifications for all user-facing interfaces.

---

## Design System

- **Framework**: Next.js 14 + Tailwind CSS
- **Components**: shadcn/ui
- **Colors**: Blue primary (#3B82F6), Gray neutral
- **Fonts**: Inter
- **Responsive**: Mobile-first (see [27-RESPONSIVE-SEO.md](./27-RESPONSIVE-SEO.md))

---

## Key Screens

### 1. Inbox (Draft Review)

**Purpose**: Review pending drafts

**Layout**: 
- Table view (desktop)
- Card view (mobile)
- Filters: status, risk, keyword, subreddit
- Sort: created_at, risk
- Pagination: 20 per page

**Actions**:
- Click row → navigate to draft detail
- Filter/sort → update URL params

See complete implementation in [M3-REVIEW-UI.md](./M3-REVIEW-UI.md), Task 3.2.

---

### 2. Draft Detail

**Purpose**: Review draft with full context before approving

**Layout** (2 columns on desktop, stacked on mobile):
- Left: Thread context (original post, top comments, rules)
- Right: Draft editor + approval controls

**Components**:
- Thread context (read-only)
- Draft editor (editable textarea)
- Risk badge (LOW/MEDIUM/HIGH)
- Approval controls (Approve/Reject buttons)

**Actions**:
- Edit → Update draft
- Approve → Enqueue posting
- Reject → Mark rejected with reason

See [M3-REVIEW-UI.md](./M3-REVIEW-UI.md), Task 3.3.

---

### 3. Settings Pages

**Company Settings**:
- Company name
- Goal/description
- Save button

**Reddit Accounts**:
- List connected accounts
- "Connect New Account" button → OAuth flow
- Disconnect button

**RAG Data**:
- File uploader
- Document list
- Delete documents

**Prompts**:
- Prompt editor
- Variable documentation
- Save/test buttons

See [25-FRONTEND-PAGES.md](./25-FRONTEND-PAGES.md) for complete page structure.

---

## Component Library

```tsx
// components/ui/RiskBadge.tsx
export function RiskBadge({ risk }: { risk: 'low' | 'medium' | 'high' }) {
  const colors = {
    low: 'bg-green-100 text-green-800',
    medium: 'bg-yellow-100 text-yellow-800',
    high: 'bg-red-100 text-red-800'
  }
  
  return (
    <span className={`px-2 py-1 rounded text-xs font-medium ${colors[risk]}`}>
      {risk.toUpperCase()}
    </span>
  )
}

// components/ui/StatusBadge.tsx
export function StatusBadge({ status }) {
  const colors = {
    pending: 'bg-gray-100 text-gray-800',
    approved: 'bg-blue-100 text-blue-800',
    posted: 'bg-green-100 text-green-800',
    rejected: 'bg-red-100 text-red-800'
  }
  
  return (
    <span className={`px-2 py-1 rounded text-xs font-medium ${colors[status]}`}>
      {status}
    </span>
  )
}
```

---

## Verification

- [ ] All screens responsive
- [ ] Touch targets ≥44px on mobile
- [ ] Color contrast meets WCAG AA
- [ ] Loading states for all actions
- [ ] Error messages user-friendly

**Reference**: [25-FRONTEND-PAGES.md](./25-FRONTEND-PAGES.md), [27-RESPONSIVE-SEO.md](./27-RESPONSIVE-SEO.md)



