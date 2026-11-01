# AutoDetailCraft — Product, Strategy & Monetization Master Notes

This document preserves the strategic roadmap, monetization architecture, feature designs, and operational policies agreed upon for AutoDetailCraft.

---

## 1. Core Platform Architecture & Philosophy

- **Open Door, No Artificial Gatekeeping:**
  - Anyone can sign up as a detailer, set their own prices, and offer any service tier immediately (from basic washes to high-ticket multi-stage paint correction and ceramic coatings).
  - Experienced pros are never slowed down by artificial "rookie probation" wash counts.
- **Hands-off Legal Shield (Zero Suing / Complete Indemnity):**
  - AutoDetailCraft operates strictly as a software toolkit, booking engine, and directory platform—not an employer, contractor, or insurer.
  - Detailers shoulder their own business liability and garage keepers / general liability insurance.
  - Mandatory in-app digital waiver, binding arbitration, and class-action waiver signed by both clients and detailers during customer check-in and pre-inspection.
- **Privacy First (No Raw Job Counts):**
  - Clients **never see raw completed job numbers** (e.g. they never see "Done 3 jobs").
  - Clients **only see earned verified badges and overall star ratings** (e.g. `⭐⭐⭐⭐⭐ 4.9 • [Paint Correction Pro] • [Ceramic Master]`).
- **Location-First Discovery Algorithm:**
  - Car owners search by **Location / Zip Code proximity** first (10–25 mile radius).
  - Within that radius, ranking is ordered by:
    1. Overall Star Rating (4.8+).
    2. Earned Trust Badges.
    3. Active platform subscription (Priority Boost for Studio Pro).
  - "New to Platform" 14-day tag for new signups in a territory so they aren't buried beneath established shops.

---

## 2. Solving the "Chicken-or-Egg" Marketplace Problem

Detailers will not pay subscriptions if there are no clients, and clients won't browse if there are no detailers. 

**The Solution:** Turn AutoDetailCraft into their **Instant Mobile Web Storefront & "Link-in-Bio" Website**.
- Detailers get a vanity URL: `autodetailcraft.com/@business_handle`.
- Replaces generic Linktree or expensive (\$2k+) custom websites with a dedicated automotive showroom:
  - Hero banner & shop branding.
  - Interactive **Before / After Split-Slider Gallery** (visual proof of their craft).
  - Service packages with transparent pricing & bulleted deliverables.
  - Earned verified trust badges.
  - Direct appointment booking & deposit processing (on paid tiers).
- **1-Click Social Share & Story Generator:**
  - Generates a branded 9:16 Instagram/TikTok Story card with a QR code and "Book Now" link so detailers promote AutoDetailCraft to their own social media followings.

---

## 3. Elaborated Subscription Tiers & Feature Breakdown

### Tier 1: The "Storefront" Tier (**$0 / Free Forever**)
* **Target:** Any detailer who wants a free, professional link for their Instagram, TikTok, or Google Business profile.
* **Included Features:**
  - Custom public URL (`autodetailcraft.com/@business_handle`).
  - Mobile-first dark-mode automotive showroom profile.
  - Service menu display with prices and bulleted deliverables (clients click to Call/DM).
  - Up to 3 interactive Before/After split-slider galleries.
  - Display of earned badges (e.g., *Verified Detailer*, *Interior Specialist*).
  - 1-Click Instagram Story & QR code graphic generator.
  - View public community feed and upvote public recipes.
* **Gated / Excluded:**
  - ❌ No automated calendar booking or card deposits.
  - ❌ No recurring "Car Care Club" auto-billing.
  - ❌ No "What If" emergency manual or dilution tools.
  - ❌ Not listed in public local directory search.

### Tier 2: The "Solo Starter" Tier (**$9.99 / mo** or **$79 / yr**)
* **Target:** Solo mobile operators, apprentices, and independent detailers actively taking customer jobs.
* **Included Features (Everything in Free, PLUS):**
  - **Online Calendar Booking & Card Deposits:** Clients select open slots and pay non-refundable card deposits via Stripe to eliminate no-shows.
  - **"Car Care Club" Recurring Client Engine:** Bi-weekly/weekly wash subscriptions with automated monthly card billing and rollover rain checks.
  - **"What If" Emergency Troubleshooting Runbooks:** Instant searchable solutions for live on-the-job problems (dusting polish, sticky paint, window haze, pet hair).
  - **On-the-Job Interactive Utilities:** Real-time chemical dilution calculator, paint depth gauge 3D panel logger.
  - **Digital Pre-Inspection Sheet (Legal Shield):** Pre-wash scratch/chip mapping signed digitally by the customer with liability waiver and arbitration clause.
  - **Dedicated Client Directory & Vehicle History Log:** Centralized customer contact list and car service history.
  - **Local Directory Search Listing:** Profile appears in customer proximity searches.
  - **Customer Review & Automated Badging Engine:** Post-job SMS/push review collection that automatically unlocks badges.
* **Gated / Excluded:**
  - ❌ 1 user account only (no staff accounts).
  - ❌ No multi-tech job dispatching or team shift calendars.
  - ❌ No Private Shop SOPs.

### Tier 3: The "Studio Pro / Team" Tier (**$29 – $39 / mo** or **$299 / yr**)
* **Target:** Established multi-van mobile operations, detailing shop owners, and pros who hire apprentices or helpers.
* **Included Features (Everything in Solo Starter, PLUS):**
  - **Multi-Seat Team Accounts:** Add up to 5–10 staff accounts (apprentices, helpers, wash techs) with role-based permissions (techs cannot see shop financials or bank payouts).
  - **Job Dispatch & Route Assignment:** Assign booked jobs and recurring maintenance routes directly to specific techs.
  - **Team Shift & Bay Schedule Calendar:** Manage technician working hours, days off, and bay allocations.
  - **Private Internal Shop SOPs (Standard Operating Procedures):** Proprietary recipes and step-by-step checklists locked strictly inside the shop’s private workspace.
  - **Automated Client SMS/Email Reminders & Re-engagement:** Appointment alerts and annual maintenance recalls.
  - **Priority Search Boost:** "Featured Studio" badge and top placement in local customer searches.
  - **Multi-Vehicle Fleet Invoicing:** Bulk invoicing and commercial account management.

---

## 4. Deep-Dive: What Are "Private Internal Shop SOPs"?

**SOP** stands for **Standard Operating Procedure** (the step-by-step recipe and instruction manual for how a specific shop does things).

In detailing, shop owners struggle with two major headaches:
1. **Consistency Across Bays:** Every employee washes or polishes differently unless given a strict checklist. One helper might use a 4:1 dilution while another uses 10:1, wasting expensive chemicals or staining trim.
2. **Trade Secret Leakage & Fear of Employees Quitting:** Shop owners hate sharing their custom chemical dilution ratios, pad/compound combinations, and prep checklists on public forums or paper sheets that an employee can copy and take to a rival shop across town.

### How Private Internal Shop SOPs Work in AutoDetailCraft:
- **Private Shop Playbooks:** The shop owner creates custom recipes and checklists in the app (e.g., *"Austin Studio Stage 2 Polish Formula"*, *"Shop Acid Wheel Wash SOP"*).
- **Locked to Team Workspace:** These SOPs are **only visible to verified employees logged into that shop's account**. They are completely invisible to the public and other detailers on AutoDetailCraft.
- **Onboarding & Training Utility:** When a new apprentice starts, the owner tells them: *"Download AutoDetailCraft and log in with your team seat. Follow the exact shop checklist on every car."*
- **One-Click Revocation:** If an employee quits or gets fired, the owner revokes their seat with one click. The employee instantly loses access to all shop recipes, client logs, and internal checklists.

---

## 5. The Critical CRM Feature Enhancements (Product Roadmap)

AutoDetailCraft is currently a hybrid between an operational detailing workbench and an early-stage CRM. To make the CRM indispensable for paying subscribers, the following 5 core pillars are planned:

1. **Dedicated Client Directory & Contact Manager:**
   - Centralized searchable list of all past clients (names, phone numbers, emails, addresses, gate codes).
   - Lifetime spend tracker per client and internal customer notes (e.g., *"Customer is very particular about wheel barrels"*).
2. **Automated SMS & Email Appointment Notifications:**
   - Instant booking confirmation to client.
   - 24-hour and 2-hour pre-appointment reminders.
   - 1-tap "On My Way" ETA text message.
   - Dramatically cuts down customer no-shows and forgotten mobile appointments.
3. **Automated Re-Engagement & "Recall" Marketing:**
   - Automated check-ins triggered by service type:
     - 4 weeks after a wash $\rightarrow$ *"Time for your monthly refresh."*
     - 6 months after a ceramic coating $\rightarrow$ *"Time for your ceramic warranty maintenance inspection."*
   - Generates predictable repeat revenue for the detailer with zero manual texting.
4. **Deposit & Payment Invoicing (Stripe Integration):**
   - Collect upfront non-refundable card deposits during online booking.
   - Full card balance settlement at job completion.
   - Automated digital PDF receipts & invoices sent to customer email.
5. **The Digital Vehicle Service History Log ("Vehicle Passport"):**
   - A timeline of all work completed on a specific VIN or license plate.
   - Logs dates, paint depth measurements, service packages, and warranty IDs.
   - Builds trust and gives car owners a reason to keep booking through the platform to maintain their vehicle's service history.

---

## 6. The Recurring Client Engine ("The Car Care Club")

A built-in membership system that lets detailers turn one-off customers into predictable monthly recurring income.

### Package Structures
1. **Bi-Weekly Maintenance Plan (2x / month):** e.g., \$150–\$200/mo — Foam contact wash, wheels/tires, interior vacuum and wipe down, spray sealant booster.
2. **Weekly Concierge Wash (4x / month):** e.g., \$260–\$350/mo — High-end weekly wash for luxury daily drivers.
3. **Multi-Car Family / Fleet Pass:** Discounted bundle for 2+ vehicles under one household.

### Why Car Owners Love It
- **Guaranteed Locked Slot:** e.g., *"Every other Tuesday at 9:00 AM is your reserved time."*
- **Rollover Flexibility ("Rain Check Credit"):** If it rains or the client is traveling, they get 1 rollover wash credit (valid 60 days).
- **Ceramic Coating Warranty Protection:** Fulfills the regular maintenance wash requirements to keep ceramic coating warranties valid.
- **Autopilot Billing:** Automatic card charges once a month.

### Why Detailers Love It
- 10 recurring clients @ \$180/mo = **\$1,800 guaranteed base revenue** every month.
- **Zero churn for AutoDetailCraft:** Detailers will never cancel their AutoDetailCraft subscription because doing so cancels their automated client billing.

---

## 7. In-App Knowledge Base: The "What If" Emergency Manual

No long video production or manual grading required. Built as high-contrast, instant visual guides and an on-the-job troubleshooting search:

- **Pad Priming Guide:** High-contrast graphic showing 4 pea-sized drops on a fresh foam pad (2 drops on reload).
- **50% Cross-Hatch Overlap Guide:** Step-by-step panel pass movement diagram.
- **"What If" Panic Search:**
  - *If polish is dusting $\rightarrow$ Mist pad with water, brush out old compound, reduce speed by 1.*
  - *If clear coat is soft/sticky $\rightarrow$ Switch to ultra-soft finishing pad, zero downward pressure.*
  - *If window cleaner streaks in heat $\rightarrow$ Two-towel method (one damp, one bone-dry waffle weave).*
  - *If pet hair is woven into carpet $\rightarrow$ Rubber squeegee / pumice stone at 45° angle before vacuuming.*

---

## 8. The Earned Badging System

Badges are awarded automatically by the app as detailers log and complete high-rated jobs:
- 🛡️ **Verified Detailer:** Granted upon profile completion, waiver sign-off, and setup.
- 🧼 **Interior Specialist:** Earned through consistently high-rated interior details.
- ⚡ **Paint Correction Pro:** Earned through high-rated machine polishing & paint enhancement jobs.
- 💎 **Ceramic Coating Master:** Earned through high-rated ceramic coating applications.
- 🌟 **Top Rated Pro:** Earned for maintaining a 4.9+ star rating across all jobs.
